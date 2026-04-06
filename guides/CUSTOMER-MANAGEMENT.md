# Customer Management System

## Overview

Complete customer/payer management system for officials association owners to set up and manage customers (schools, leagues, clubs, etc.) with their billing, contact, and configuration information.

## Architecture

### Store: Pinia (`/src/stores/customers.ts`)

**Types:**
- `OrganizationType`: 'School' | 'League' | 'Club' | 'Association' | 'Other'
- `PaymentTerms`: 'Net 15' | 'Net 30' | 'Net 60'
- `FeeStructureType`: 'Flat fee' | 'Per-game' | 'Percentage-based'
- `PaymentMethod`: 'Bank transfer' | 'Check' | 'Credit card'
- `AccountType`: 'Checking' | 'Savings'
- `CustomerStatus`: 'Active' | 'Inactive' | 'Suspended'

**Interfaces:**
- `Contact`: id, name, role, email, phone, isPrimary
- `BankAccount`: accountHolderName, routingNumber, accountNumber, accountType
- `Customer`: Complete customer entity with all required fields
- `OnboardingFormData`: Form data model (extends Customer minus id/timestamps)

**State:**
- `customers`: Customer[] - List of all customers
- `currentStep`: number (1-6) - Current onboarding wizard step
- `onboardingForm`: Partial<OnboardingFormData> - Form data during onboarding

**Methods:**
- `loadMockData()`: Loads 2 sample customers for testing
- `getCustomerById(id)`: Retrieve single customer by ID
- `resetOnboardingForm()`: Reset form to defaults and go to step 1
- `goToStep(step)`: Jump to specific step
- `nextStep()`: Advance to next step
- `previousStep()`: Go back to previous step
- `updateOnboardingForm(data)`: Update form data reactively
- `createCustomer(data)`: Create new customer
- `updateCustomer(id, data)`: Update existing customer
- `deleteCustomer(id)`: Delete customer

### Views

#### CustomersView (`/src/views/officials/CustomersView.vue`)
**Purpose:** List all customers with CRUD actions

**Features:**
- Stats bar showing total and active customers
- Table with columns: Organization name, Type, City/State, Status badge, Primary contact, Actions
- Action buttons for edit and delete
- "New Customer" button routes to onboarding
- Search/filter support via table design

#### CustomerOnboardingView (`/src/views/officials/CustomerOnboardingView.vue`)
**Purpose:** Multi-step wizard for creating new customers

**Features:**
- 6-step wizard with progress bar (visual fill + text "Step X of 6")
- Progress indicator at top
- Step panels conditionally shown based on currentStep
- Previous/Next navigation buttons
- "Create Customer" button on final step
- Validates form on completion
- Redirects to customers list after success

#### CustomerEditView (`/src/views/officials/CustomerEditView.vue`)
**Purpose:** Edit existing customer information

**Features:**
- Tabbed interface (Details, Contacts, Configurations)
- Details tab: Edit all customer fields
- Contacts tab: View/manage customer contacts
- Configurations tab: Links to manage Types, Levels, Leagues, Venues
- Save Changes button to persist updates
- Pre-populated with customer data from store

### Components: Onboarding Steps

#### Step 1: Organization Details (`OnboardingStep1.vue`)
- Organization name (text)
- Organization type (select)
- Description (textarea)
- Status (select: Active/Inactive/Suspended)

#### Step 2: Address & Location (`OnboardingStep2.vue`)
- Street address (text)
- City (text)
- State (select with 20 US states)
- ZIP code (text)
- Service areas (comma-separated text)

#### Step 3: Billing Information (`OnboardingStep3.vue`)
- Tax ID (text)
- Fee structure type (Flat fee/Per-game/Percentage-based)
- Fee amount (dynamic label based on type)
- Payment terms (Net 15/30/60)
- Payment method (Bank transfer/Check/Credit card)
- Billing address (conditional - hidden if using mailing as billing)

#### Step 4: Bank Account & Contract (`OnboardingStep4.vue`)
- Account holder name (text)
- Routing number (text)
- Account number (password field - masked)
- Account type (Checking/Savings)
- Contract start date (date picker)
- Contract end date (date picker)
- Contract duration display (calculated days and years)

#### Step 5: Primary Contact (`OnboardingStep5.vue`)
- Contact name (text)
- Contact role/title (text)
- Email (email)
- Phone (tel)
- Is primary (checkbox - disabled/always checked)
- Info: "Add additional contacts after creating customer"

#### Step 6: Review & Confirm (`OnboardingStep6.vue`)
- Display all form data organized by section
- Masked bank account numbers (shows "••••••••")
- Ready to proceed message
- "Create Customer" button triggers store action

## Routing

Routes added to `/src/router/index.ts` under the `/officials` section:

```
/officials/customers           → CustomersView
/officials/customers/onboarding → CustomerOnboardingView
/officials/customers/:id/edit   → CustomerEditView
```

Named routes:
- `Customers` - Customer list view
- `CustomerOnboarding` - Onboarding wizard
- `CustomerEdit` - Edit customer (with `id` parameter)

## Navigation

- **CustomersView** → "New Customer" button → CustomerOnboardingView (resets form)
- **CustomersView** → Table edit link → CustomerEditView (with customer id)
- **CustomerOnboardingView** → Step 6 "Create Customer" → CustomersView
- **CustomerEditView** → "Back to Customers" → CustomersView
- **OfficialsLayout** sidebar includes new "Customers" nav item

## UI Design

### Color Scheme
- Primary: #3b82f6 (Blue)
- Success: #10b981 (Green)
- Warning: #f59e0b (Amber)
- Danger: #ef4444 (Red)
- Backgrounds: #f7fafc (light), #e2e8f0 (border)

### Component Patterns
- **Form groups**: Consistent padding, labels, helper text
- **Status badges**: Color-coded (Active=green, Inactive=yellow, Suspended=red)
- **Progress bar**: Animated fill based on step percentage
- **Cards**: White background with subtle border and padding
- **Buttons**: Primary (blue), Secondary (gray), Outline (bordered)

### Responsive Design
- Tables stack on mobile (single column)
- Form grids collapse to single column below 768px
- Sidebar remains sticky on larger screens

## Mock Data

Two sample customers included in loadMockData():

1. **Archer Athletic Association**
   - Type: Association
   - Location: Archer, GA 30004
   - Status: Active
   - Billing: Flat $5,000 annual fee
   - Terms: Net 30
   - Primary contact: John Smith (Director)

2. **Brookwood High School**
   - Type: School
   - Location: Snellville, GA 30078
   - Status: Active
   - Billing: $50 per game
   - Terms: Net 30
   - Primary contact: Sarah Johnson (Athletic Director)

## Type Safety

All customer data is fully typed with TypeScript:
- Form bindings use computed properties for reactive updates
- Bank account nested object properly typed
- Contact array with unique ID tracking
- Payment and billing options restricted to literal types

## Future Enhancements

1. **Configuration Managers**
   - Types manager: Create/manage contest types per customer
   - Levels manager: Create/manage competition levels
   - Leagues manager: Create/manage leagues
   - Venues manager: Create/manage venues with mandatory sub-venues

2. **Form Validation**
   - Per-step validation before advancing
   - Required field indicators
   - Format validation (emails, phone numbers, dates)

3. **API Integration**
   - Replace mock data with backend API calls
   - Save/update customers to database
   - Persist form state during wizard

4. **Bulk Operations**
   - Export customers to CSV
   - Import customers from file
   - Bulk status updates

5. **Customer Relationships**
   - Link officials to customers
   - Link contests to customers
   - View customer-specific contests/assignments

## Administration Fee (Per-Customer Billing Add-On)

Officials associations can optionally charge customers (schools, leagues, clubs, etc.) an **administration fee** on top of the standard contest officiating charges. This is configured per customer and applied during invoice generation.

### Customer-Level Configuration (at customer creation or edit)

When an officials association creates or edits a customer, the following admin-fee settings are available:

| Field | Type | Description |
|-------|------|-------------|
| `charge_admin_fee` | Boolean | Whether this customer is billed an administration fee |
| `admin_fee_type` | Enum: `percentage`, `fixed`, `percentage_plus_fixed` | How the fee is calculated |
| `admin_fee_percent` | Decimal (0–100) | Percentage rate (when type includes percentage) |
| `admin_fee_amount` | Currency | Fixed dollar amount (when type includes fixed) |

- If `charge_admin_fee` is **false**, no admin fee fields are shown or applied.
- If `admin_fee_type` is `percentage`, only the percentage field is required.
- If `admin_fee_type` is `fixed`, only the dollar amount field is required.
- If `admin_fee_type` is `percentage_plus_fixed`, both fields are required — the fee is the percentage of the subtotal **plus** the fixed amount on top.

### Invoice-Level Behavior

When an invoice is generated for a customer that has `charge_admin_fee = true`:

1. **Default values pre-populated**: The invoice admin fee line item is auto-populated from the customer's stored defaults (`admin_fee_type`, `admin_fee_percent`, `admin_fee_amount`).
2. **Override at invoice time**: The officials association can:
   - **Keep the default** — no changes needed, fee applies as configured.
   - **Change the percentage** — if the fee type is `percentage` or `percentage_plus_fixed`, the user can adjust the rate for this specific invoice.
   - **Enter a different dollar amount** — override the fixed portion or switch to a one-time flat amount.
   - **Apply percentage AND a fixed amount** — select `percentage_plus_fixed` to charge a percentage of the subtotal plus an additional dollar amount on top of the calculated percentage total.
   - **Waive the fee** — set to $0 or toggle off for this invoice only (does not change the customer default).
3. **Calculation**: The admin fee is computed against the invoice subtotal (sum of all contest line items before the admin fee). For `percentage_plus_fixed`, the formula is:
   $$\text{Admin Fee} = (\text{Subtotal} \times \frac{\text{percent}}{100}) + \text{fixed amount}$$
4. **Line item**: The admin fee appears as a distinct line item on the invoice (type: `admin_fee`) so it is transparent to the customer.
5. **Audit**: Any override of the default at invoice time is recorded in the audit trail with the original default values and the override values.

### Examples

| Scenario | Customer Default | Invoice Subtotal | Admin Fee |
|----------|-----------------|------------------|-----------|
| Percentage only | 5% | $2,000 | $100.00 |
| Fixed only | $50 flat | $2,000 | $50.00 |
| Percentage + fixed | 3% + $25 | $2,000 | $85.00 |
| Override at invoice | Default 5%, changed to 3% | $2,000 | $60.00 |
| Waived | Default 5%, waived | $2,000 | $0.00 |

### Data Model (planned)

Customer table additions:
- `charge_admin_fee` — `BOOLEAN DEFAULT false`
- `admin_fee_type` — `VARCHAR(30)` enum (`percentage`, `fixed`, `percentage_plus_fixed`)
- `admin_fee_percent` — `NUMERIC(5,2)` nullable
- `admin_fee_amount` — `NUMERIC(10,2)` nullable

Invoice line item:
- `reference_type = 'admin_fee'`
- `fee_type`, `fee_percent`, `fee_amount` — store the values used for this specific invoice (may differ from customer default)
- `override_from_default` — `BOOLEAN` — indicates if the association changed the fee from the customer's stored default

## Files

**Store:**
- `/src/stores/customers.ts` - Pinia store with types and CRUD

**Views:**
- `/src/views/officials/CustomersView.vue` - Customer list
- `/src/views/officials/CustomerOnboardingView.vue` - Onboarding wizard
- `/src/views/officials/CustomerEditView.vue` - Edit customer

**Components:**
- `/src/components/officials/onboarding/OnboardingStep1.vue`
- `/src/components/officials/onboarding/OnboardingStep2.vue`
- `/src/components/officials/onboarding/OnboardingStep3.vue`
- `/src/components/officials/onboarding/OnboardingStep4.vue`
- `/src/components/officials/onboarding/OnboardingStep5.vue`
- `/src/components/officials/onboarding/OnboardingStep6.vue`

**Router:**
- `/src/router/index.ts` - Route definitions

**Layout:**
- `/src/components/officials/OfficialsLayout.vue` - Updated with Customers nav link
