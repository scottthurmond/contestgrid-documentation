# Update Summary: Payer & Billing Entity Model Implementation

**Date**: December 27, 2025
**ADR**: 0029 - Payer and Billing Entity Model
**Status**: Documentation, Requirements, and Schema Updated

---

## Overview

Updated all project documentation, requirements, and database schemas to support a flexible **billing entity model** that supports multiple types of payers:

- Tenants (primary organizations)
- Sub-organizations (divisions, leagues, branches)
- Cost centers (departments, events, budget lines)
- Third-party organizations (non-tenant customers)
- Individuals (eligible for 1099 reporting)
- Informal groups (parent committees, booster clubs)

---

## Files Updated

### 1. **Database Schemas**

#### PostgreSQL (`contestgrid-postgresql.sql`)
- ✅ Added `billing_entity` table (UUID PKs, JSONB-ready)
  - Supports 7 entity types with appropriate validation
  - Hierarchical parent-child relationships
  - Tax ID field for 1099 reporting
  - Billing preferences (cycle, terms, email)
  - Status tracking (active, inactive, suspended, archived)
  
- ✅ Added `contest_billing_split` table
  - Multi-payer support via percentage or fixed-amount splits
  - Status tracking (pending, confirmed, invoiced, paid, disputed)
  
- ✅ Updated `contest_schedule` table
  - Replaced `PAYER_ID` with `billing_entity_id` FK
  - Points to flexible billing_entity model
  
- ✅ Updated `contest_rates` table
  - Added optional `billing_entity_id` for entity-specific rates
  - NULL = default rates for tenant

#### MySQL (`contestgrid.sql`)
- ✅ Added `billing_entity` table (INT PKs, MySQL compatible)
  - Full feature parity with PostgreSQL version
  - Check constraints for entity_type and status
  
- ✅ Added `contest_billing_split` table
  - Percentage and fixed-amount allocation support
  - Check constraints for validation
  
- ✅ Updated `contest_schedule` table
  - Replaced `PAYER_ID` with `billing_entity_id` FK
  
- ✅ Updated `contest_rates` table
  - Added `rate_id` as auto-increment PK (improved from composite key)
  - Added optional `billing_entity_id` for entity-specific rates

### 2. **Architecture Decision Records (ADRs)**

#### New: `0029-payer-and-billing-entity-model.md`
- **Status**: Proposed
- **Scope**: Complete design for flexible payer model
- **Includes**:
  - 7 billing entity types with examples
  - Data models and schema changes
  - Invoicing workflows
  - Split billing support
  - Access control & RLS policies
  - Migration path (4 phases)
  - Consequences (pros/cons)
  - Deferred decisions (verification workflows, tiered access)

#### Updated: `0003-billing-and-payroll.md`
- **Status**: Accepted (Updated)
- **Changes**:
  - Added reference to ADR-0029 (flexible payer model)
  - Updated data models section with billing_entity schema
  - Added split billing workflows
  - Updated invoicing workflow to reference billing entities
  - Enhanced 1099 reporting guidance
  - Updated templates to handle different entity types
  - Added third-party verification requirements
  - Updated compliance section with tax handling

### 3. **Requirements & Roadmap**

#### `roadmap.md`
- ✅ Added flexible payer model to Core Platform requirements
- ✅ References ADR-0029 with brief summary
- ✅ Notes on hierarchies, split billing, 1099 support

#### `MVP-SCOPE.md`
- ✅ Enhanced Officials Association section:
  - Mentions flexible payer support
  - Lists 1099 generation capability
  - References ADR-0029

#### `PROJECT-OVERVIEW.md`
- ✅ Added new "Flexible Payer Model" section
- ✅ Shows 7 entity types with brief descriptions
- ✅ Notes hierarchical support, split billing, 1099 generation

#### `INDEX.md`
- ✅ Updated ADR-0029 entry (new, Proposed status)
- ✅ Updated ADR-0003 entry to note it was updated with payer model

---

## Schema Changes Summary

### New Tables

#### `billing_entity`
```sql
- billing_entity_id (PK)
- entity_type (7 types: tenant, sub_organization, cost_center, event, third_party, individual, group)
- billing_entity_name, abbreviation, description
- tenant_id (FK, NULL for external entities)
- parent_billing_entity_id (FK, for hierarchies)
- contact_name, email, phone, website
- address_id (FK)
- payment_method, payment_reference, tax_id
- bill_to_email, billing_cycle, payment_terms_days
- is_primary, is_verified, is_taxpayer (flags)
- status (active|inactive|suspended|archived)
- Indexes: tenant, type, email, parent
```

#### `contest_billing_split`
```sql
- split_id (PK)
- contest_schedule_id (FK)
- billing_entity_id (FK)
- percentage_responsible OR fixed_amount (choose one)
- status (pending|confirmed|invoiced|paid|disputed)
- notes, timestamps
- Indexes: contest, entity, status
```

### Modified Tables

#### `contest_schedule`
- **Removed**: `PAYER_ID` + FK to `officials_tenant_map`
- **Added**: `billing_entity_id` FK to `billing_entity`
- **Impact**: Can now track any payer type, not just tenants
- **Backward Compatible**: Via `billing_entity.entity_type = 'tenant'` mapping

#### `contest_rates`
- **Changed** (PostgreSQL): Added `billing_entity_id` (optional) to support entity-specific rates
- **Changed** (MySQL): 
  - Restructured from composite PK to `rate_id` auto-increment PK
  - Added `billing_entity_id` (optional)
  - Added date fields for effective dating
  - Changed decimal sizes to match invoicing (10,2)

---

## Key Features Enabled

### 1. Sub-Organization Billing
Schools within a school district can now be separate billing entities, each with their own invoice address and payment terms.

### 2. Third-Party Payers
Non-tenant organizations (sponsors, parent groups, external customers) can pay for contests without becoming system tenants.

### 3. Split Billing
When multiple entities pay for one contest (e.g., home team 60%, sponsor 40%), the system tracks allocation and generates separate invoices.

### 4. Hierarchical Structures
Billing entities can nest (district → schools → divisions), with parent-child relationships for organizational hierarchy.

### 5. Individual Contractors
Individuals can be marked as `is_taxpayer = true` for automatic 1099-NEC generation at year-end.

### 6. Cost Center Allocation
Events, tournaments, or departments can be cost centers with separate billing and revenue attribution.

### 7. Tax Reporting
Tax IDs captured per entity enable proper 1099 reporting for individuals and EIN-based invoicing for organizations.

---

## Migration Considerations

### For Existing Deployments

1. **Backward Compatibility**: All existing `PAYER_ID` references that point to `tenant` records should be migrated to `billing_entity` records with `entity_type = 'tenant'`.

2. **Data Migration Script** (Pseudo-code):
   ```sql
   INSERT INTO billing_entity (entity_type, tenant_id, billing_entity_name, status, created_at)
   SELECT 'tenant', tenant_id, tenant_name, 'active', NOW()
   FROM tenant
   WHERE NOT EXISTS (
     SELECT 1 FROM billing_entity WHERE tenant_id = tenant.tenant_id AND entity_type = 'tenant'
   );
   
   UPDATE contest_schedule
   SET billing_entity_id = (
     SELECT billing_entity_id FROM billing_entity 
     WHERE entity_type = 'tenant' AND tenant_id IN (
       SELECT tenant_id FROM officials_tenant_map
       WHERE officials_association_id = contest_schedule.officials_association_id
         AND tenant_id = contest_schedule.payer_id
     )
   );
   ```

3. **Phase**: Recommend as part of Phase 3 (Data Migration) in ADR-0029's rollout plan.

---

## API Changes Required

### Contest Creation
```typescript
// OLD
const contest = {
  payer_id: tenant_id,
  ...
};

// NEW
const contest = {
  billing_entity_id: uuid, // points to billing_entity
  ...
};
```

### Invoice Generation
```typescript
// OLD: Assume payer is always a tenant
const invoice = await generateInvoice(contest.payer_id);

// NEW: Handle any entity type
const payer = await getBillingEntity(contest.billing_entity_id);
const invoice = await generateInvoice({
  billing_entity_id: payer.billing_entity_id,
  bill_to: payer.bill_to_email,
  should_issue_1099: payer.entity_type === 'individual' && payer.is_taxpayer
});
```

### Split Billing
```typescript
// NEW: Support for multi-payer contests
const splits = await getContestBillingSplits(contest_id);
for (const split of splits) {
  const amount = calculateAmount(contest, split);
  const invoice = await generateInvoice({
    billing_entity_id: split.billing_entity_id,
    amount: amount,
    ...
  });
}
```

---

## Testing Implications

### New Test Cases
- [ ] Create contest with tenant as payer
- [ ] Create contest with sub-organization as payer
- [ ] Create contest with third-party payer
- [ ] Create contest with individual payer (1099 eligible)
- [ ] Create split-billing contest (2+ entities)
- [ ] Generate invoices for different entity types
- [ ] Generate 1099-NEC for individuals
- [ ] Verify parent-child billing entity hierarchy
- [ ] Test 1099 with tax_id masking
- [ ] Verify RLS policies for multi-payer scenarios

### Migration Tests
- [ ] Existing contests migrated correctly to billing_entity
- [ ] No data loss in payer relationship mapping
- [ ] Invoices still generate for migrated contests
- [ ] Reporting unaffected

---

## Documentation Next Steps

- [ ] API documentation (OpenAPI/Swagger) for billing_entity CRUD
- [ ] User guide: creating sub-organizations as billing entities
- [ ] Admin guide: configuring third-party payers and verification
- [ ] Invoicing guide: split billing workflows
- [ ] Tax guide: 1099 reporting configuration
- [ ] Migration guide: tenant → billing_entity mapping

---

## References

- **ADR-0029**: Payer and Billing Entity Model (detailed specification)
- **ADR-0003**: Billing & Payroll (updated with new payer model)
- **ADR-0004**: Auth & RBAC (access control for billing entities)
- **ADR-0021**: Data Storage Architecture (RLS policies)
- **ADR-0028**: Cross-Tenant Data Access (related multi-tenant patterns)

---

## Status: READY FOR IMPLEMENTATION

All documentation, requirements, and schema have been updated. The project is now ready for:

1. Backend API development (CRUD for billing entities, split billing workflows)
2. Invoicing service updates (multi-entity support, 1099 generation)
3. Frontend UI development (billing entity management, split billing configuration)
4. Data migration planning and testing
