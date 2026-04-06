# Officials Association Onboarding - Production Integration Requirements

## Contact Verification System

### Email Verification
**Endpoint:** `POST /api/onboarding/send-verification-email`
- **Input:** `{ email: string, firstName: string }`
- **Action:** 
  - Generate 6-digit verification code
  - Store code with expiration (15 minutes)
  - Send email with code to provided address
  - Return success/failure status
- **Email Template:** Include code, user's first name, expiration time

**Endpoint:** `POST /api/onboarding/verify-email`
- **Input:** `{ email: string, code: string }`
- **Action:** Validate code against stored value, check expiration
- **Return:** `{ verified: boolean, message?: string }`

### SMS Verification
**Endpoint:** `POST /api/onboarding/send-verification-sms`
- **Input:** `{ phone: string, firstName: string }`
- **Action:**
  - Generate 6-digit verification code
  - Store code with expiration (15 minutes)
  - Send SMS with code to provided phone number
  - Return success/failure status
- **SMS Template:** "Your Contest Schedule verification code is: [CODE]. Expires in 15 minutes."

**Endpoint:** `POST /api/onboarding/verify-sms`
- **Input:** `{ phone: string, code: string }`
- **Action:** Validate code against stored value, check expiration
- **Return:** `{ verified: boolean, message?: string }`

### Resend Logic
- Implement rate limiting: max 3 resends per hour per contact point
- Invalidate previous codes when new code is sent
- Track resend attempts in database

## Onboarding Submission API

**Endpoint:** `POST /api/onboarding/submit`
- **Input:** Complete onboarding form data including:
  ```typescript
  {
    account: { firstName, lastName, email, phone, password },
    verification: { emailVerified, smsVerified },
    association: { name, abbreviation, type, region, sports, description, referralSource },
    address: { street, city, state, zip },
    agreements: { acceptTerms, acceptPrivacy, acceptData }
  }
  ```
- **Validation:**
  - Verify both email and SMS are marked as verified
  - Check that verification was completed within reasonable timeframe (e.g., 24 hours)
  - Validate all required fields are present
- **Action:**
  - Create onboarding application record with status "pending"
  - Set currentStage to 1 (submitted)
  - Generate unique submission ID
  - Hash and store password securely
  - Send confirmation email to applicant
- **Return:** `{ submissionId: string, status: 'pending' }`

## Admin Review API

**Endpoint:** `GET /api/admin/onboarding-applications`
- **Query Params:** `status?: 'pending' | 'approved' | 'rejected' | 'all'`
- **Return:** Array of application summaries:
  ```typescript
  {
    id: string,
    associationName: string,
    adminName: string,
    email: string,
    phone: string,
    region: string,
    sports: string,
    referralSource: string,
    status: 'pending' | 'approved' | 'rejected',
    emailVerified: boolean,
    smsVerified: boolean,
    submittedAt: string
  }
  ```

**Endpoint:** `GET /api/admin/onboarding-applications/:id`
- **Return:** Full application details including all form data

**Endpoint:** `PUT /api/admin/onboarding-applications/:id/status`
- **Input:** `{ status: 'approved' | 'rejected', reason?: string, notes?: string }`
- **Action:**
  - Update application status
  - If approved: create tenant/association account, set up initial configuration
  - If rejected: store rejection reason, send notification email
  - Update currentStage appropriately
- **Return:** Updated application record

**Endpoint:** `PUT /api/admin/onboarding-applications/:id/stage`
- **Input:** `{ stage: 1 | 2 | 3 | 4, notes?: string }`
- **Action:** Update currentStage for timeline display, optionally add notes
- **Return:** Updated application record

## Status Page API

**Endpoint:** `GET /api/onboarding/status/:submissionId`
- **Return:**
  ```typescript
  {
    status: 'pending' | 'approved' | 'rejected',
    currentStage: 1 | 2 | 3 | 4,  // 1=submitted, 2=review, 3=technical, 4=complete
    notes?: string,  // Owner notes visible to applicant
    submittedAt: string,
    lastUpdatedAt: string
  }
  ```

## Security Considerations

1. **Verification Codes:**
   - Store hashed codes in database
   - Implement rate limiting on send and verify endpoints
   - Log all verification attempts for audit trail

2. **Password Storage:**
   - Use bcrypt or Argon2 for password hashing
   - Minimum password requirements: 8 characters, mix of upper/lower/numbers

3. **Authentication:**
   - Admin review endpoints require platform_admin role
   - Status page endpoint requires either submissionId in query or authenticated session

4. **Authorization & Entitlements (see ADR-0034):**
   - **Local/MVP:** Fine-grained RBAC entitlements (68 entitlements: 17 resources × 4 CRUD operations) stored in `app.entitlement` + `app.role_entitlement` tables, resolved at login and embedded in JWT. BFF `requireEntitlement()` middleware enforces per-endpoint. Tenant admins can customize role-entitlement mappings via admin UI.
   - **Production:** Migrate to **AWS Verified Permissions** (Cedar policy engine). Cognito handles identity; Cedar handles authorization per-request with built-in audit logging. The DB entitlement tables remain the source of truth, synced to Cedar policies via CI/CD. See ADR-0034 § "Production Migration" for the 5-phase rollout plan.
   - Onboarding-specific entitlement gates:
     - `GET /admin/onboarding-applications` — requires `platform_admin` role (no DB entitlement; platform-level operation)
     - `PUT /admin/onboarding-applications/:id/status` — requires `platform_admin` role
     - `GET /onboarding/status/:submissionId` — public (no auth) or authenticated with submissionId ownership check
   - Platform admin override: `platform_admin` is a BFF-level concept (Cognito group) and cannot be self-assigned by tenant admins

5. **Data Validation:**
   - Sanitize all input fields to prevent injection attacks
   - Validate email and phone formats
   - Check for duplicate email/phone during submission

## Notification Requirements

1. **Email Notifications:**
   - Verification code email (immediate)
   - Application submitted confirmation (immediate)
   - Status change notifications (approved/rejected)
   - Stage progression updates (optional, configurable)

2. **SMS Notifications:**
   - Verification code SMS (immediate)
   - Critical status changes (approved/rejected) - optional

## Database Schema Requirements

### onboarding_applications table
- id (UUID, primary key)
- status (enum: pending, approved, rejected)
- current_stage (integer: 1-4)
- admin_first_name, admin_last_name, admin_email, admin_phone
- password_hash
- email_verified (boolean), sms_verified (boolean)
- association_name, association_abbreviation, association_type
- region, sports, description, referral_source
- street_address, city, state, zip_code
- terms_accepted, privacy_accepted, data_accepted
- notes (text, admin notes)
- rejection_reason (text, if rejected)
- submitted_at, updated_at timestamps

### verification_codes table
- id (UUID, primary key)
- email_or_phone (string, indexed)
- code_hash (string)
- type (enum: email, sms)
- expires_at (timestamp)
- used (boolean)
- created_at timestamp

## Implementation Priority

1. **Phase 1 (MVP):**
   - Email/SMS verification endpoints
   - Onboarding submission endpoint
   - Admin review GET/PUT endpoints
   - Status page GET endpoint

2. **Phase 2:**
   - Automated email notifications
   - SMS notifications
   - Audit logging
   - Rate limiting

3. **Phase 3:**
   - Advanced admin features (bulk actions, search, filters)
   - Detailed analytics on onboarding funnel
   - Automated tenant provisioning on approval
