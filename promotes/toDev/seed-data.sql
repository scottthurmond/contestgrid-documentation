-- ============================================================
-- ContestGrid Dev Environment — Seed Data
-- Run AFTER Flyway migrations, BEFORE application use
--
-- Usage:
--   psql -h <host> -U <user> -d <db> -f seed-data.sql
--
-- NOTE: This script uses explicit IDs matching the lab environment.
-- Adjust sequences after insert if needed:
--   SELECT setval('app.<table>_<pk>_seq', (SELECT MAX(<pk>) FROM app.<table>));
-- ============================================================

BEGIN;

-- ────────────────────────────────────────────────────────────
-- 1. Global lookup tables (no tenant_id)
-- ────────────────────────────────────────────────────────────

-- phone_type
INSERT INTO app.phone_type (phone_type_id, phone_type_name, aliases, display_order)
VALUES
  (1, 'Mobile', 'cell', 1),
  (2, 'Home', NULL, 2),
  (3, 'Work', 'office,business', 3)
ON CONFLICT (phone_type_id) DO NOTHING;

-- platform_role_type
INSERT INTO app.platform_role_type (platform_role_type_id, role_name, description)
VALUES
  (1, 'platform_admin', 'Full superuser — bypasses all entitlement checks, manages tenants and platform config'),
  (2, 'officials_admin', 'Manages officials data and configurations across the platform'),
  (3, 'contest_assigner', 'Can create and manage contest assignments'),
  (4, 'league_director', 'League-level administrative access'),
  (5, 'billing_admin', 'Billing, subscription, and invoice management')
ON CONFLICT (platform_role_type_id) DO NOTHING;

-- ────────────────────────────────────────────────────────────
-- 2. Tenant type & tenant
--    Adjust tenant_id and names for your environment.
-- ────────────────────────────────────────────────────────────

INSERT INTO app.tenant_type (tenant_type_id, tenant_type_name)
VALUES
  (6, 'Officials Association'),
  (10, 'Sports League')
ON CONFLICT (tenant_type_id) DO NOTHING;

-- Example tenant — change name/id as needed
-- INSERT INTO app.tenant (tenant_id, tenant_name, ...) VALUES (...);
-- (Tenant creation is typically done via the platform admin flow)

-- ────────────────────────────────────────────────────────────
-- 3. Per-tenant lookup data
--    Replace {TENANT_ID} with the actual tenant_id before running,
--    or run the parameterized version below.
-- ────────────────────────────────────────────────────────────

-- To use: replace all occurrences of {TENANT_ID} with your tenant's ID
-- e.g. in psql:  \set tid 1010
--                and change {TENANT_ID} to :tid

-- person_type
INSERT INTO app.person_type (person_type_description, tenant_id) VALUES
  ('Payer',    {TENANT_ID}),
  ('Contact',  {TENANT_ID}),
  ('Official', {TENANT_ID});

-- assignment_status
INSERT INTO app.assignment_status (assignment_status_name, tenant_id) VALUES
  ('Pending',   {TENANT_ID}),
  ('Confirmed', {TENANT_ID}),
  ('Declined',  {TENANT_ID}),
  ('Cancelled', {TENANT_ID}),
  ('Completed', {TENANT_ID});

-- contest_status
INSERT INTO app.contest_status (contest_status_name, tenant_id) VALUES
  ('Normal',    {TENANT_ID}),
  ('Cancelled', {TENANT_ID}),
  ('Rainout',   {TENANT_ID}),
  ('Forfeit',   {TENANT_ID}),
  ('Suspended', {TENANT_ID});

-- contest_type
INSERT INTO app.contest_type (contest_type_name, tenant_id) VALUES
  ('Regular Season', {TENANT_ID}),
  ('Playoff',        {TENANT_ID}),
  ('Tournament',     {TENANT_ID}),
  ('Pre-Season',     {TENANT_ID}),
  ('Scrimmage',      {TENANT_ID});

-- membership_status
INSERT INTO app.membership_status (membership_status_name, created_at, tenant_id, updated_at) VALUES
  ('Active',   NOW(), {TENANT_ID}, NOW()),
  ('Inactive', NOW(), {TENANT_ID}, NOW()),
  ('Suspended', NOW(), {TENANT_ID}, NOW());

-- roles
INSERT INTO app.roles (role_description, tenant_id, is_admin_role) VALUES
  ('Primary Assigner Admin',   {TENANT_ID}, false),
  ('Secondary Assigner Admin', {TENANT_ID}, false),
  ('League Director',          {TENANT_ID}, false),
  ('Coach',                    {TENANT_ID}, false),
  ('Official',                 {TENANT_ID}, false),
  ('Tenant Admin',             {TENANT_ID}, true);

-- pay_classification
INSERT INTO app.pay_classification (pay_classification_name, rate_multiplier, tenant_id) VALUES
  ('Standard', 1.0000, {TENANT_ID});

-- invoice_status (not tenant-scoped based on lab data, but check your schema)
INSERT INTO app.invoice_status (invoice_status_name) VALUES
  ('Draft'),
  ('Sent'),
  ('Paid'),
  ('Past Due'),
  ('Void'),
  ('Partially Paid'),
  ('Refunded'),
  ('Partially Refunded')
ON CONFLICT DO NOTHING;

-- invoice_payment_type
INSERT INTO app.invoice_payment_type (invoice_payment_type_name, tenant_id) VALUES
  ('Charge',         {TENANT_ID}),
  ('Full Refund',    {TENANT_ID}),
  ('Partial Refund', {TENANT_ID});

-- notification_status (not tenant-scoped)
INSERT INTO app.notification_status (notification_status_name) VALUES
  ('Queued'),
  ('Sent'),
  ('Failed'),
  ('Bounced')
ON CONFLICT DO NOTHING;

-- notification_type (not tenant-scoped)
INSERT INTO app.notification_type (notification_type_name) VALUES
  ('Payment Due Reminder'),
  ('Payment Past Due'),
  ('Payment Received'),
  ('Subscription Renewed'),
  ('Subscription Cancelled')
ON CONFLICT DO NOTHING;

-- payment_status (not tenant-scoped)
INSERT INTO app.payment_status (payment_status_name) VALUES
  ('Pending'),
  ('Processing'),
  ('Completed'),
  ('Failed'),
  ('Refunded'),
  ('Cancelled')
ON CONFLICT DO NOTHING;

-- payment_type
INSERT INTO app.payment_type (payment_type_name, tenant_id) VALUES
  ('Contest Bill',    {TENANT_ID}),
  ('Official Payout', {TENANT_ID});

-- sport
INSERT INTO app.sport (sport_name, tenant_id) VALUES
  ('Baseball',   {TENANT_ID}),
  ('Softball',   {TENANT_ID}),
  ('Basketball', {TENANT_ID});

COMMIT;

-- ────────────────────────────────────────────────────────────
-- After inserts, reset sequences to avoid PK conflicts:
-- ────────────────────────────────────────────────────────────
-- SELECT setval(pg_get_serial_sequence('app.person_type', 'person_type_id'),
--              (SELECT COALESCE(MAX(person_type_id), 0) FROM app.person_type));
-- (Repeat for each table with a serial/identity PK)
