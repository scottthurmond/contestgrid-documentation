# ContestGrid — User Guide

> Last updated: 2026-03-08

This guide covers all screens and workflows in the ContestGrid frontend application.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Logging In](#logging-in)
3. [Dashboard](#dashboard)
4. [Navigation & Roles](#navigation--roles)
5. [Contests](#contests)
6. [Officials](#officials)
7. [Reference Data (Admin)](#reference-data-admin)
   - [Tenants](#tenants)
   - [Levels](#levels)
   - [Seasons](#seasons)
   - [Leagues](#leagues)
   - [Teams](#teams)
   - [Venues](#venues)
8. [Users & Roles (Platform Admin)](#users--roles-platform-admin)
9. [Roles Reference](#roles-reference)

---

## Getting Started

ContestGrid is a multi-tenant platform for managing sports contest officiating — scheduling contests, assigning officials, and tracking billing. The frontend is built with **Vue 3**, **Vuetify 4**, and communicates with a Backend-for-Frontend (BFF) service.

### Prerequisites

- A valid user account with at least one assigned role.
- The BFF and downstream services must be running (either local K8s cluster or hosted environment).
- For local development: `npm run dev` starts the Vite dev server with an API proxy to the BFF at `https://api.contestgrid.local:8443`.

---

## Logging In

**Route:** `/login`

1. Enter your **Email** address.
2. Enter your **Password**.
3. *(Optional)* Enter a **Tenant ID** to scope your session to a specific tenant. If omitted, the system uses your default tenant from the role store.
4. Click **Sign In**.

On successful login a JWT token is stored in `localStorage` and you are redirected to the Dashboard (or the page you originally requested).

### Default Development Credentials

| Email                        | Password   | Tenant | Pre-assigned Roles                                        |
| ---------------------------- | ---------- | ------ | --------------------------------------------------------- |
| `admin@contestgrid.local`   | `admin123` | 1      | `platform_admin`, `officials_admin`, `contest_assigner`   |

> **Tip:** Any email/password combination is accepted by the mock auth system. New emails are auto-registered in the role store with a default `officials_admin` role on first login.

---

## Dashboard

**Route:** `/`  
**Requires:** Any authenticated user

The Dashboard displays an overview of your tenant's data in six stat cards:

| Card               | Data Source               | Description                                  |
| ------------------ | ------------------------- | -------------------------------------------- |
| Total Contests     | `contests.total`          | Number of contests in the system             |
| Total Officials    | `officials.total`         | Number of registered officials               |
| Upcoming           | `contests.upcoming`       | Contests scheduled in the future             |
| Needing Officials  | `contests.needingOfficials` | Contests that still need officials assigned |
| Outstanding ($)    | `billing.outstanding`     | Unpaid billing balance                       |
| Active Officials   | `officials.active`        | Officials currently active and available      |

A personalized welcome message is shown with the logged-in user's name.

---

## Navigation & Roles

The left navigation drawer adapts to your assigned roles. Roles are **additive** — if you hold multiple roles, you see the combined set of features from all of them. There is no "role switching."

The drawer is organized into three sections:

### Main

Always visible to any authenticated user:
- **Dashboard** — Overview stats

Conditionally visible:
- **Contests** — visible if you have `officials_admin`, `contest_assigner`, or `platform_admin`
- **Officials** — visible if you have `officials_admin` or `platform_admin`

### Reference Data

Visible if you have `officials_admin`, `contest_assigner`, or `platform_admin`:
- Tenants, Levels, Seasons, Leagues, Teams, Venues

### Platform

Visible only to `platform_admin`:
- **Users & Roles** — Manage user accounts and role assignments

### Platform Admin Badge

If you hold the `platform_admin` role, a red **Platform Admin** chip badge appears in the top app bar next to your name.

---

## Contests

**Route:** `/contests`  
**Requires:** `officials_admin`, `contest_assigner`, or `platform_admin`

Displays a searchable, sortable data table of all contests for your tenant.

| Column          | Description                     |
| --------------- | ------------------------------- |
| Contest Name    | Name of the contest             |
| Sport           | Sport type (e.g., Basketball)   |
| Date            | Scheduled date                  |
| Venue           | Location name                   |
| Home Team       | Home team name                  |
| Away Team       | Away team name                  |
| Official Count  | Number of assigned officials    |

Use the search box at the top to filter contests by any visible field.

---

## Officials

**Route:** `/officials`  
**Requires:** `officials_admin` or `platform_admin`

Displays a searchable, sortable data table of all officials.

| Column           | Description                          |
| ---------------- | ------------------------------------ |
| First Name       | Official's first name                |
| Last Name        | Official's last name                 |
| Email            | Contact email                        |
| Uniform Number   | Assigned uniform number              |
| Assignment Count | Number of active contest assignments |

---

## Reference Data (Admin)

These six views allow management of shared lookup/reference tables. They are all accessible from the **Reference Data** section of the navigation drawer.

All reference data views (except Tenants) use a shared **CrudTable** component that provides:
- **Search** — Filter rows by typing in the search box
- **Add** — Click the **+ New** button to open a create dialog
- **Edit** — Click the pencil icon on a row to open the edit dialog
- **Delete** — Click the trash icon to delete (with confirmation)

### Tenants

**Route:** `/admin/tenants`

Managed through a dedicated view with role-aware controls.

| Column       | Description                                        |
| ------------ | -------------------------------------------------- |
| ID           | Auto-generated tenant ID                           |
| Name         | Full tenant name                                   |
| Abbreviation | Short code (max 10 characters)                     |
| Type         | Tenant type displayed as a color-coded chip         |
| Created      | Creation timestamp                                 |

**Tenant Types:**

| ID | Type                   | Chip Color |
| -- | ---------------------- | ---------- |
| 1  | Officials Association  | Blue       |
| 2  | Sports League          | Green      |

**Role restrictions:**
- All admin roles can **view** tenants.
- Only `platform_admin` can **create**, **edit**, or **delete** tenants.
- When editing, only `tenant_name` and `tenant_abbreviation` can be changed.
- When creating, you also specify `tenant_type_id` and `tenant_sub_domain`.

### Levels

**Route:** `/admin/levels`

Contest difficulty/age levels (e.g., Varsity, JV, Middle School).

| Column      | Description                 |
| ----------- | --------------------------- |
| ID          | `contest_level_id`          |
| Level Name  | `contest_level_name`        |
| Description | `contest_level_description` |

### Seasons

**Route:** `/admin/seasons`

Defines scheduling periods (e.g., "Fall 2026").

| Column      | Description              |
| ----------- | ------------------------ |
| ID          | `season_id`              |
| Season Name | `season_name`            |
| Start Date  | `season_start_date`      |
| End Date    | `season_end_date`        |

### Leagues

**Route:** `/admin/leagues`

Organizes teams into groups for scheduling.

| Column      | Description              |
| ----------- | ------------------------ |
| ID          | `league_id`              |
| League Name | `league_name`            |
| Sport Name  | `sport_name`             |

### Teams

**Route:** `/admin/teams`

Teams that participate in contests.

| Column    | Description            |
| --------- | ---------------------- |
| ID        | `team_id`              |
| Team Name | `team_name`            |
| League    | `league_name`          |

### Venues

**Route:** `/admin/venues`

Physical locations where contests take place.

| Column     | Description            |
| ---------- | ---------------------- |
| ID         | `venue_id`             |
| Venue Name | `venue_name`           |
| Address    | `venue_address`        |
| City       | `venue_city`           |

---

## Users & Roles (Platform Admin)

**Route:** `/admin/users`  
**Requires:** `platform_admin`

This view allows platform administrators to manage user accounts and their role assignments.

### User List

A data table shows all users with assigned roles:

| Column    | Description                                        |
| --------- | -------------------------------------------------- |
| Email     | User's email address (serves as the unique key)    |
| Name      | Display name                                       |
| Tenant ID | The tenant the user belongs to                     |
| Roles     | Color-coded chips showing assigned roles           |
| Actions   | Edit and Delete buttons                            |

### Role Chip Colors

| Role               | Color   |
| ------------------ | ------- |
| `platform_admin`   | Red     |
| `officials_admin`  | Blue    |
| `contest_assigner` | Green   |
| `league_director`  | Amber   |
| `billing_admin`    | Info    |

### Adding a User

1. Click **+ New User**.
2. Fill in the **Email**, **Name**, and **Tenant ID** fields.
3. Select one or more **Roles** from the multi-select dropdown.
4. Click **Save**.

### Editing a User

1. Click the **pencil icon** on the user's row.
2. Modify **Name**, **Tenant ID**, or **Roles** as needed. The email field is read-only when editing.
3. Click **Save**.

### Deleting a User

1. Click the **trash icon** on the user's row.
2. Confirm the deletion in the dialog. This removes the user and **all** their role assignments.

> **Note:** Roles are additive. A user can hold any combination of the five app roles simultaneously. They do not need to "switch" between roles — the UI automatically shows the superset of features from all assigned roles.

---

## Roles Reference

ContestGrid has five application-level roles. These are distinct from database-level roles (e.g., "Primary Assigner Admin") stored in the `person_roles` table.

| Role               | Description                                                                                   |
| ------------------ | --------------------------------------------------------------------------------------------- |
| `platform_admin`   | Full access. Can manage tenants, users/roles, and view all features. The highest-level role.   |
| `officials_admin`  | Manages officials and contests. Can view reference data and assignments.                       |
| `contest_assigner` | Focuses on contest scheduling and assignment. Can view contests and reference data.             |
| `league_director`  | League-focused role. *(Guards not yet implemented — reserved for future use.)*                  |
| `billing_admin`    | Billing-focused role. *(Guards not yet implemented — reserved for future use.)*                 |

### Role → Feature Visibility Matrix

| Feature            | `platform_admin` | `officials_admin` | `contest_assigner` | `league_director` | `billing_admin` |
| ------------------ | :--------------: | :----------------: | :-----------------: | :----------------: | :-------------: |
| Dashboard          | ✓                | ✓                  | ✓                   | ✓                  | ✓               |
| Contests           | ✓                | ✓                  | ✓                   | —                  | —               |
| Officials          | ✓                | ✓                  | —                   | —                  | —               |
| Reference Data     | ✓                | ✓                  | ✓                   | —                  | —               |
| Tenant CRUD        | ✓ (full)         | view only          | view only           | view only          | view only       |
| Users & Roles      | ✓                | —                  | —                   | —                  | —               |

### How Roles Work Internally

- **JWT claims:** On login, the BFF issues a JWT with assigned roles in the `cognito:groups` claim array.
- **Frontend auth store:** `useAuthStore().hasRole(role)` checks the user's role list from the decoded token.
- **Route guard:** Routes with `meta.roles` array are protected — user must hold at least one of the listed roles.
- **Navigation:** The sidebar dynamically computes visible items based on the union of all held roles.
- **Backend enforcement:** The BFF uses `requireRole('platform_admin')` middleware on tenant write operations and all `/admin/*` endpoints.

---

## Session Management

- **Token persistence:** The JWT is stored in `localStorage` and survives page reloads.
- **Session restore:** On navigation, if a token exists but no user object is loaded, the app calls `/auth/me` to restore the session.
- **Logout:** Click the logout icon in the top-right corner of the app bar. This clears the token and redirects to the login page.
- **Token refresh:** The auth store supports `refresh()` to obtain a new token before expiry.

---

## Keyboard & UI Tips

- **Toggle sidebar:** Click the hamburger menu icon (☰) in the top-left corner of the app bar.
- **Search tables:** All data tables include a search field that filters across all visible columns.
- **Sort columns:** Click any column header in a data table to sort ascending/descending.
