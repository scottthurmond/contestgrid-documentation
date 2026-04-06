# ContestGrid - Proc API: Billing

**Business workflows for**: Payment processing, Payroll calculation, 1099-NEC generation

Part of the multi-tier architecture: **Frontend → BFF → Proc APIs → System APIs**

## Architecture

This is a **Proc API** (orchestration layer) that:
- Orchestrates billing workflows
- Calculates official payouts based on contest rates
- Generates 1099-NEC forms
- Integrates with payment processors (Stripe, etc.)
- Does NOT own database tables (calls System API: Billing)

## Workflows

### Payment Processing
1. Fetch contest and official data
2. Calculate amounts based on rates
3. Process payment via Stripe/processor
4. Record payment in System API: Billing
5. Send payment confirmation

### Payroll Calculation
1. Fetch contests for period
2. Calculate official earnings
3. Apply tax withholdings
4. Generate payout records
5. Trigger payment processing

### 1099-NEC Generation
1. Aggregate official earnings for tax year
2. Generate 1099-NEC form data
3. Store in System API: Billing
4. Send to officials (email/portal)

## API Endpoints

### Payments
- `POST /workflows/payments/process` - Process contest payment
- `POST /workflows/payments/batch` - Batch payment processing
- `GET /workflows/payments/:id/status` - Check payment status

### Payroll
- `POST /workflows/payroll/calculate` - Calculate period payroll
- `POST /workflows/payroll/disburse` - Disburse payments to officials
- `GET /workflows/payroll/:period` - Get payroll summary

### 1099s
- `POST /workflows/1099s/generate/:year` - Generate 1099s for year
- `GET /workflows/1099s/:official/:year` - Get official's 1099
- `POST /workflows/1099s/send` - Send 1099s to officials

Port: **3005**

## Dependencies

Calls:
- `contestgrid-system-core` (port 3001)
- `contestgrid-system-officials` (port 3002)
- `contestgrid-system-billing` (port 3003)
- Stripe API (external)
