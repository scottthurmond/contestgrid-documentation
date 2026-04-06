# ADR 0029: Payer and Billing Entity Model

## Status
Proposed

## Context

The current data model assumes that the **payer for a contest** is always the sports association tenant. However, in practice, the entity paying for officials services can be:

1. **Tenant (Sports Association)** — the primary tenant organization itself
2. **Sub-Organization** — a specific league, division, or branch within a sports association tenant
3. **Cost Center** — a budget allocation unit for departmental or event-based billing
4. **Event/Tournament** — a specific event or tournament paying separately
5. **Third-Party Payer** — a non-tenant organization (sponsor, parent organization, promoter) paying on behalf
6. **Individual/Group** — a coach or parent group paying directly for a specific set of games
7. **Hybrid** — multiple payers splitting costs for a single contest

### Current Problem

The current schema uses:
```sql
CONSTRAINT officials_payer_map_fk 
  FOREIGN KEY (OFFICIALS_ASSOCIATION_ID, PAYER_ID, SPORT_ID) 
  REFERENCES officials_tenant_map (OFFICIALS_ASSOCIATION_ID, tenant_id, SPORT_ID)
```

This forces `PAYER_ID` to be a `tenant_id`, which:
- ❌ Prevents sub-organization billing (unless each is a separate tenant, causing data fragmentation)
- ❌ Prevents third-party payers from being recorded
- ❌ Prevents cost-center or event-based billing models
- ❌ Prevents multi-payer contests (one team pays, other team doesn't; sponsor covers difference)
- ❌ Makes invoicing to non-tenants impossible (e.g., send invoice to parent board, not league)

### Examples

**Example 1: Large School District**
- Tenant: County Schools Athletic Association
- Sub-payers: High School A, High School B, Middle School C (divisions/branches, not tenants)
- Invoice should go to each school separately, not the county level

**Example 2: Non-Tenant Parent Organization**
- Tenant: Little League Chapter #42
- Payer: Regional Little League District (NOT a system tenant)
- Invoice goes to district, not chapter

**Example 3: Tournament with Sponsors**
- Tenant: Local Softball Association
- Contest: Summer Championship Tournament
- Payers: (1) Tournament Organizer (cost center), (2) Nike (sponsor covering 20% of officials)
- Split billing: need to track both payers and their portions

**Example 4: Parent Group**
- Tenant: High School Sports Boosters
- Payer: Select Team Parent Group (informal organization, not a system entity)
- Invoice goes to parent group's PayPal account or check made to "Select Team Parents"

## Decision

Implement a **flexible billing entity model** that supports multiple payer types while maintaining backward compatibility with tenant-based payers.

### Core Concept: "Billing Entity"

Create a generalized `billing_entity` table that can represent any organization or cost center that might pay for a contest:

```sql
CREATE TABLE billing_entity (
  billing_entity_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Entity type: determines what it represents and validation rules
  entity_type VARCHAR(50) NOT NULL, -- 'tenant', 'sub_organization', 'cost_center', 'event', 'third_party', 'individual', 'group'
  
  -- Identifying information
  billing_entity_name VARCHAR(255) NOT NULL,
  abbreviation VARCHAR(50),
  description TEXT,
  
  -- Relationship to tenant (for isolation and context)
  tenant_id UUID, -- NULL if third-party/external payer
  parent_billing_entity_id UUID REFERENCES billing_entity(billing_entity_id), -- for hierarchies
  
  -- Contact information
  contact_name VARCHAR(255),
  email VARCHAR(255),
  phone VARCHAR(20),
  website VARCHAR(255),
  
  -- Address (billing address)
  address_id UUID REFERENCES address(address_id),
  
  -- Payment details
  payment_method VARCHAR(50), -- card, ach, check, cash, paypal, venmo, etc.
  payment_reference VARCHAR(255), -- token, PO number, account ID, etc.
  tax_id VARCHAR(50), -- SSN, EIN, VAT ID (for invoicing/1099)
  
  -- Billing preferences
  bill_email_recipient VARCHAR(255), -- where to send invoices (may differ from contact_email)
  billing_cycle VARCHAR(20), -- monthly, quarterly, annual, per_event
  payment_terms_days INT DEFAULT 30, -- net-30, net-60, etc.
  
  -- Status
  status VARCHAR(20) NOT NULL DEFAULT 'active', -- active, inactive, suspended, archived
  
  -- Classification (for reporting and access control)
  is_primary BOOLEAN DEFAULT FALSE, -- is this the primary payer for the tenant?
  is_verified BOOLEAN DEFAULT FALSE, -- has identity been verified (third-parties)?
  is_taxpayer BOOLEAN DEFAULT FALSE, -- eligible for 1099 reporting (US)?
  
  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  
  CONSTRAINT billing_entity_type_check 
    CHECK (entity_type IN ('tenant', 'sub_organization', 'cost_center', 'event', 'third_party', 'individual', 'group')),
  CONSTRAINT billing_entity_status_check 
    CHECK (status IN ('active', 'inactive', 'suspended', 'archived'))
);

CREATE INDEX idx_billing_entity_tenant ON billing_entity(tenant_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_billing_entity_type ON billing_entity(entity_type);
CREATE INDEX idx_billing_entity_email ON billing_entity(bill_email_recipient);

COMMENT ON TABLE billing_entity IS 'Flexible entity that can pay for contests: tenants, sub-organizations, cost centers, events, third parties, individuals, groups';
COMMENT ON COLUMN billing_entity.entity_type IS 'Type determines validation rules and available fields';
COMMENT ON COLUMN billing_entity.parent_billing_entity_id IS 'For hierarchies (e.g., school district → individual schools)';
COMMENT ON COLUMN billing_entity.tax_id IS 'For 1099-NEC/1099-MISC reporting (individuals) or invoicing (organizations)';
```

### Update Contest Schedule

Replace `PAYER_ID` with `billing_entity_id`:

```sql
ALTER TABLE contest_schedule
  DROP CONSTRAINT officials_payer_map_fk,
  DROP COLUMN PAYER_ID,
  ADD COLUMN billing_entity_id UUID NOT NULL REFERENCES billing_entity(billing_entity_id),
  ADD CONSTRAINT contest_schedule_billing_entity_fk 
    FOREIGN KEY (billing_entity_id) REFERENCES billing_entity(billing_entity_id);

COMMENT ON COLUMN contest_schedule.billing_entity_id IS 'Entity (tenant, sub-org, third party, etc.) paying for officials';
```

### Support Multi-Payer Contests

For contests with multiple payers (split billing):

```sql
CREATE TABLE contest_billing_split (
  split_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  contest_schedule_id UUID NOT NULL REFERENCES contest_schedule(contest_schedule_id) ON DELETE CASCADE,
  billing_entity_id UUID NOT NULL REFERENCES billing_entity(billing_entity_id),
  
  -- Split allocation
  percentage_responsible DECIMAL(5, 2) NOT NULL, -- 0-100
  fixed_amount DECIMAL(10, 2), -- alternative: fixed dollar amount instead of percentage
  
  -- Status
  status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, confirmed, invoiced, paid, disputed
  notes TEXT,
  
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  CONSTRAINT contest_billing_split_percentage_check CHECK (percentage_responsible > 0 AND percentage_responsible <= 100)
);

CREATE INDEX idx_contest_billing_split_contest ON contest_billing_split(contest_schedule_id);
CREATE INDEX idx_contest_billing_split_entity ON contest_billing_split(billing_entity_id);

COMMENT ON TABLE contest_billing_split IS 'Represents split billing when multiple entities pay for a single contest';
```

### Update Contest Rates

Link rates to billing entities instead of just tenants:

```sql
ALTER TABLE contest_rates
  DROP COLUMN payer_id,
  ADD COLUMN billing_entity_id UUID REFERENCES billing_entity(billing_entity_id),
  ADD CONSTRAINT contest_rates_billing_entity_fk 
    FOREIGN KEY (billing_entity_id) REFERENCES billing_entity(billing_entity_id);

COMMENT ON COLUMN contest_rates.billing_entity_id IS 'Billing entity these rates apply to (null = default for tenant)';
```

## Billing Entity Types

### 1. **Tenant** (The Primary Organization)
- `entity_type = 'tenant'`
- `tenant_id` NOT NULL
- Direct tenant reference (backward compatible)
- Example: "City Youth Sports Association"

### 2. **Sub-Organization** (Division, League, Branch)
- `entity_type = 'sub_organization'`
- `tenant_id` NOT NULL
- `parent_billing_entity_id` → Parent tenant
- Allows leagues/divisions to have separate billing
- Example: "Spring Recreational League" (within City Youth Sports)

### 3. **Cost Center** (Department, Budget Line, Event)
- `entity_type = 'cost_center'`
- `tenant_id` NOT NULL (for access control)
- `parent_billing_entity_id` → Owning organization
- Used for event-based billing or departmental splits
- Example: "Summer Championship 2025" or "Umpire Training Fund"

### 4. **Event** (Specific Tournament/Competition)
- `entity_type = 'event'`
- `tenant_id` NOT NULL (created by tenant)
- Standalone billing entity for specific events
- Example: "Memorial Day Tournament"

### 5. **Third-Party** (Non-Tenant Organization)
- `entity_type = 'third_party'`
- `tenant_id` NULL (external entity)
- External organizations paying for officials
- Requires verification before invoicing
- Example: "Regional Little League District #5" or "Nike sponsorship program"

### 6. **Individual** (Person, Coach, Parent)
- `entity_type = 'individual'`
- `tenant_id` NULL (or owning organization if managed)
- For individuals paying directly
- Eligible for 1099-NEC reporting
- Example: "Coach John Smith" or "Parent Group Treasurer"

### 7. **Group** (Informal Organization, Parent Group)
- `entity_type = 'group'`
- `tenant_id` NULL (informal)
- Informal groups (parent committees, booster clubs)
- Limited verification requirements
- Example: "Select Team Parents" or "Booster Club Committee"

## Data Flow Examples

### Example 1: Tenant-Based Payer (Backward Compatible)

```typescript
// Create billing entity for tenant
const billingEntity = {
  billing_entity_id: uuid(),
  entity_type: 'tenant',
  tenant_id: 'tenant-123', // City Youth Sports Association
  billing_entity_name: 'City Youth Sports Association',
  email: 'billing@cityyouthsports.org',
  status: 'active'
};

// Contest uses tenant as payer
const contest = {
  contest_schedule_id: uuid(),
  billing_entity_id: billingEntity.billing_entity_id, // ← points to billing_entity
  // ... other fields
};
```

### Example 2: Sub-Organization Payer

```typescript
// Parent tenant
const tenant = {
  tenant_id: 'tenant-456', // County Schools Athletic Association
};

// Sub-organization: specific school
const subOrgBillingEntity = {
  billing_entity_id: uuid(),
  entity_type: 'sub_organization',
  tenant_id: 'tenant-456', // for access control
  parent_billing_entity_id: uuid(), // if nested further
  billing_entity_name: 'Lincoln High School Athletics',
  bill_email_recipient: 'lds_athletics@lincolnhigh.edu',
  status: 'active'
};

// Contest bills the school, not the county
const contest = {
  contest_schedule_id: uuid(),
  billing_entity_id: subOrgBillingEntity.billing_entity_id,
  // ... other fields
};
```

### Example 3: Third-Party Payer

```typescript
// Third-party org (not in system as tenant)
const thirdPartyBillingEntity = {
  billing_entity_id: uuid(),
  entity_type: 'third_party',
  tenant_id: null, // NOT a system tenant
  billing_entity_name: 'Regional Little League District',
  email: 'billing@rlld.org',
  tax_id: '12-3456789', // EIN for invoicing
  is_verified: true, // identity verified
  status: 'active'
};

// Contest paid by third party
const contest = {
  contest_schedule_id: uuid(),
  billing_entity_id: thirdPartyBillingEntity.billing_entity_id,
  // ... other fields
};
```

### Example 4: Multi-Payer Contest (Split Billing)

```typescript
// Assume contest_schedule_id = contest-xyz

// Home team pays 60%
await insertContestBillingSplit({
  contest_schedule_id: 'contest-xyz',
  billing_entity_id: 'home-team-entity', // billing entity for home team
  percentage_responsible: 60,
  status: 'pending'
});

// Sponsor covers 40%
await insertContestBillingSplit({
  contest_schedule_id: 'contest-xyz',
  billing_entity_id: 'sponsor-entity', // billing entity for Nike
  percentage_responsible: 40,
  status: 'confirmed'
});

// Generate invoices for each payer based on split
```

## Invoicing & Billing Workflow

### Lookup Payer Information

```typescript
// Get billing entity for a contest
async function getContestPayer(contestId) {
  return db.query(`
    SELECT be.* 
    FROM contest_schedule cs
    JOIN billing_entity be ON cs.billing_entity_id = be.billing_entity_id
    WHERE cs.contest_schedule_id = $1
  `, [contestId]);
}

// Get split payers
async function getContestBillingPayers(contestId) {
  return db.query(`
    SELECT be.*, cbs.percentage_responsible, cbs.fixed_amount
    FROM contest_billing_split cbs
    JOIN billing_entity be ON cbs.billing_entity_id = be.billing_entity_id
    WHERE cbs.contest_schedule_id = $1
      AND cbs.status != 'disputed'
  `, [contestId]);
}
```

### Generate Invoice

```typescript
// Invoice templates can adapt based on payer type
async function generateInvoice(contestId, officialAssociationId) {
  const contest = await getContestData(contestId);
  const payers = await getContestBillingPayers(contestId);
  
  for (const payer of payers) {
    const billAmount = calculateBillAmount(contest, payer);
    
    const invoice = {
      invoice_id: uuid(),
      officials_association_id: officialAssociationId,
      billing_entity_id: payer.billing_entity_id,
      
      // Invoice goes to appropriate recipient based on entity type
      bill_to_email: payer.bill_email_recipient || payer.email,
      bill_to_name: payer.billing_entity_name,
      
      // For 1099s: only if individual and is_taxpayer
      should_issue_1099: (payer.entity_type === 'individual' && payer.is_taxpayer),
      tax_id: payer.tax_id,
      
      amount: billAmount,
      due_date: addDays(today(), payer.payment_terms_days || 30)
    };
    
    await createInvoice(invoice);
  }
}
```

## Access Control & Row-Level Security

### Tenant Perspective

Officials associations can see and bill:
- Parent tenant
- All sub-organizations of that tenant
- Third-party payers linked to that tenant (if authorized)

### Sub-Organization Perspective

Only see contests assigned to that sub-organization (if multi-tenancy at sub-org level is enabled).

### Backward Compatibility

All existing payers that are tenants automatically become:
```sql
INSERT INTO billing_entity (entity_type, tenant_id, billing_entity_name, status)
SELECT 'tenant', tenant_id, tenant_name, 'active'
FROM tenant
WHERE NOT EXISTS (SELECT 1 FROM billing_entity WHERE tenant_id = tenant.tenant_id AND entity_type = 'tenant');
```

## Migration Path

### Phase 1: Add New Structure
- Create `billing_entity` table
- Create `contest_billing_split` table
- Populate with existing tenants
- Deploy schema changes

### Phase 2: Update Application
- Update APIs to use `billing_entity_id` instead of `PAYER_ID`
- Update invoicing to query billing entities
- Add billing entity CRUD to admin UI

### Phase 3: Data Migration
- Migrate all contest_schedule.PAYER_ID → billing_entity_id
- Migrate all contest_rates.payer_id → billing_entity_id
- Validate data integrity

### Phase 4: Cleanup
- Drop old PAYER_ID columns
- Drop officials_tenant_map FK references
- Update documentation

## Consequences

**Positive:**
- ✅ Supports all payer types (tenants, sub-orgs, third parties, individuals)
- ✅ Enables split billing for complex scenarios
- ✅ Maintains backward compatibility (tenants still work)
- ✅ Flexible invoicing (send to correct contact for each entity type)
- ✅ Enables 1099 reporting for individuals
- ✅ Allows hierarchical billing structures (divisions, leagues, cost centers)
- ✅ Clear audit trail of who pays for what

**Negative:**
- ❌ More complex schema (additional tables, relationships)
- ❌ API changes required (PAYER_ID → billing_entity_id)
- ❌ Need validation rules for different entity types
- ❌ Testing complexity increases (multi-payer scenarios)
- ❌ Reporting queries become more complex (JOIN billing_entity)

**Mitigations:**
- Defaults to single-payer (most common case)
- Clear entity type validation rules
- Well-documented API changes
- Comprehensive test coverage for split-billing scenarios
- Type-safe TypeScript interfaces for each entity type

## Deferred Decisions

- **Approval workflows for third-party payers**: Should adding a new third-party payer require verification/approval? (Defer to ADR-0029a)
- **Tiered access for sub-organizations**: Should sub-org admins only see their contests? (Defer to ADR-0030)
- **Multi-tenant at sub-org level**: Can sub-organizations be independently managed tenants? (Large feature, defer)

## References
- ADR 0003: Billing and Payroll (invoicing and payment)
- ADR 0004: Auth & RBAC (access control for billing entities)
- ADR 0021: Data Storage Architecture (RLS policies)
- ADR 0028: Cross-Tenant Data Access (billing entity visibility)

---

## Appendix: SQL Schema Changes Summary

```sql
-- New table
CREATE TABLE billing_entity (...)

-- New table for split billing
CREATE TABLE contest_billing_split (...)

-- Modify existing tables
ALTER TABLE contest_schedule
  RENAME COLUMN PAYER_ID TO billing_entity_id,
  ADD CONSTRAINT contest_schedule_billing_entity_fk ...;

ALTER TABLE contest_rates
  ADD COLUMN billing_entity_id UUID REFERENCES billing_entity(...),
  ADD CONSTRAINT contest_rates_billing_entity_fk ...;

-- Drop old constraint
ALTER TABLE contest_rates
  DROP CONSTRAINT payer_fk;
```
