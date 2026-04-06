# ContestGrid - Proc API: Scheduling

**Business workflows for**: Contest creation, Official assignments, Notifications, Availability

Part of the multi-tier architecture: **Frontend → BFF → Proc APIs → System APIs**

## Architecture

This is a **Proc API** (orchestration layer) that:
- Orchestrates workflows across System APIs (Core, Officials, Billing)
- Implements business logic for contest scheduling
- Handles official assignment algorithms
- Manages notifications and availability
- Does NOT own database tables directly (calls System APIs)

## Workflows

### Contest Creation Workflow
1. Validate contest data (call System API: Core)
2. Check venue availability
3. Create contest record
4. Trigger assignment workflow
5. Send notifications

### Official Assignment Workflow
1. Fetch available officials (System API: Officials)
2. Check certifications and availability
3. Apply assignment rules (sport, level, location proximity)
4. Create assignments
5. Send notifications to officials

### Availability Management
- Officials set availability windows
- System blocks/allows assignments based on availability
- Handles time-off requests

## API Endpoints

### Contests
- `POST /workflows/contests/create` - Create contest + assign officials
- `POST /workflows/contests/:id/reassign` - Reassign officials
- `POST /workflows/contests/:id/cancel` - Cancel contest + notify

### Assignments
- `POST /workflows/assignments/auto-assign` - Auto-assign officials to contests
- `GET /workflows/assignments/:id/suggestions` - Get assignment suggestions
- `POST /workflows/assignments/:id/accept` - Official accepts assignment
- `POST /workflows/assignments/:id/decline` - Official declines

### Availability
- `GET /officials/:id/availability` - Get availability windows
- `POST /officials/:id/availability` - Set availability

Port: **3004**

## Dependencies

Calls:
- `contestgrid-system-core` (port 3001)
- `contestgrid-system-officials` (port 3002)
