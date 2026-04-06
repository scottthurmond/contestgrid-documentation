# Venue Selection & Subvenue Override — Requirements

**Status:** Draft  
**Date:** 2026-03-19  
**Author:** Auto-generated from user requirements session

---

## 1. Overview

Redesign the Venues tab on the Customer Profile page so that customers **curate their own venue list** rather than seeing every venue in the system. Introduce a shared venue catalog, internet-based venue lookup, and per-customer subvenue name overrides.

---

## 2. Current Behavior

- The Venues tab displays **all venues** belonging to the customer's tenant via `GET /proxy/venues`.
- Venues are created manually (name + address) and are **tenant-scoped** (`venue.tenant_id`).
- Subvenues exist in the schema (`venue_sub`) but are **not exposed** in the customer profile UI.
- There is **no search** — venues are fetched in bulk and filtered client-side.
- There is **no shared venue catalog** — each tenant owns its own venue records.

---

## 3. Requirements

### 3.1 — Do Not Display All Venues by Default

- The Venues tab must **not** auto-populate with every venue in the system.
- Only venues the customer has **explicitly selected** (associated with) should appear in their list.
- A new **customer ↔ venue association** (many-to-many) determines the displayed list.

### 3.2 — Search Existing System Venues

- When adding a venue, the user should first be presented with a **search/autocomplete** that queries all venues already known to ContestGrid (the global catalog), regardless of which tenant originally created them.
- Search should match on **venue name** and optionally **city/state**.
- If a match is found, the user selects it and the venue is **associated** with their customer — no duplicate record is created.

### 3.3 — Internet Search for Unknown Venues

- If the venue is **not found** in the system catalog, the user can continue typing and the system will **search the internet** (e.g., Google Places API / geocoding service) for matching venues.
- Internet results should display the venue name and full address.
- Selecting an internet result **pre-populates** the venue details (name, address line 1, city, state, postal code, country) and creates the venue in the ContestGrid catalog.
- The newly created venue is simultaneously associated with the customer.

### 3.4 — Manual Entry Fallback

- If the venue is not found via internet search, the user can **manually enter** all venue details:
  - Venue name (required)
  - Address line 1, line 2, city, state, postal code, country
- The manually entered venue is saved to the global catalog and associated with the customer.

### 3.5 — Subvenues with Global Defaults & Customer Overrides

- Once a venue is in the customer's list, the customer can **view and manage subvenues** (e.g., "Field 1", "Court A", "Diamond 3").
- Subvenues created for a venue are saved as the **global defaults** for that venue (in `venue_sub`).
- When a **different customer** later adds the same venue to their list:
  - The global default subvenue names are **pre-populated** automatically.
  - The customer can **customize** (rename) any subvenue for their own use.
  - Customizations are stored separately and do **not** alter the global default names.
  - Other customers continue to see the original default names (or their own customizations).
- Customers can also **add new subvenues** beyond the defaults if needed.

---

## 4. Data Model Changes

### 4.1 — Shared Venue Catalog

The `venue` table transitions from tenant-scoped to a **shared global catalog**:

- Remove (or deprecate) the `tenant_id` foreign key on `venue`, OR keep it to track which tenant originally created the venue but **do not use it for access control**.
- Adjust RLS policies so that all authenticated users can **read** venues (for search), but only authorized roles can **create/update** venue records.

### 4.2 — Customer ↔ Venue Association Table (new)

```
customer_venue (
  customer_venue_id  BIGSERIAL PRIMARY KEY,
  tenant_id          BIGINT NOT NULL REFERENCES tenant(tenant_id),
  venue_id           BIGINT NOT NULL REFERENCES venue(venue_id),
  created_at         TIMESTAMPTZ DEFAULT now(),
  UNIQUE (tenant_id, venue_id)
)
```

- RLS: scoped to `tenant_id = current_setting('app.tenant_id')`.
- This table controls which venues appear on a customer's Venues tab.

### 4.3 — Customer Subvenue Override Table (new)

```
customer_venue_sub (
  customer_venue_sub_id  BIGSERIAL PRIMARY KEY,
  tenant_id              BIGINT NOT NULL REFERENCES tenant(tenant_id),
  sub_venue_id           BIGINT NOT NULL REFERENCES venue_sub(sub_venue_id),
  custom_sub_venue_name  VARCHAR(45) NOT NULL,
  created_at             TIMESTAMPTZ DEFAULT now(),
  updated_at             TIMESTAMPTZ DEFAULT now(),
  UNIQUE (tenant_id, sub_venue_id)
)
```

- If a row exists for `(tenant_id, sub_venue_id)`, the customer sees `custom_sub_venue_name`.
- If no row exists, the customer sees the default `venue_sub.sub_venue_name`.
- RLS: scoped to `tenant_id`.

### 4.4 — Venue Search Index

- Add a GIN/trigram index on `venue.venue_name` for fast `ILIKE` / similarity search.
- Optionally add indexed `city`/`state` fields to the `address` table join for compound search.

---

## 5. API Changes

### 5.1 — Core-sys

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/v1/venues/search?q=...` | Search the global venue catalog (name, city, state). Returns venues with addresses. No tenant filter. |
| GET | `/v1/venues/internet-search?q=...` | Proxy to external places API. Returns candidate venues with pre-populated addresses. |
| POST | `/v1/customer-venues` | Associate an existing venue with the current tenant. Body: `{ venue_id }` |
| DELETE | `/v1/customer-venues/:venue_id` | Remove a venue from the current tenant's list (does not delete the venue itself). |
| GET | `/v1/customer-venues` | List venues associated with the current tenant (with address + subvenues). |
| GET | `/v1/customer-venues/:venue_id/sub-venues` | List subvenues for a venue in the customer's context (applying name overrides). |
| POST | `/v1/customer-venues/:venue_id/sub-venues` | Create a new subvenue (adds to global defaults). |
| PATCH | `/v1/customer-venues/:venue_id/sub-venues/:id/override` | Set a custom subvenue name for this tenant. |
| DELETE | `/v1/customer-venues/:venue_id/sub-venues/:id/override` | Revert to the global default name. |

### 5.2 — BFF Proxy

Add corresponding proxy routes in the BFF to forward the above endpoints from the frontend.

---

## 6. Frontend Changes

### 6.1 — Venues Tab Redesign

Replace the current `CrudTable` on the Venues tab with a custom component:

1. **Venue List** — Displays only the customer's associated venues (from `GET /customer-venues`). Each venue is expandable to show subvenues.
2. **"Add Venue" Button** — Opens a search dialog (not a blank form).

### 6.2 — Add Venue Dialog / Flow

1. **Search input** (autocomplete) — As the user types:
   - First, query `GET /venues/search?q=...` for existing system venues.
   - Results appear in a dropdown with venue name, city, state.
2. **If no system match** — The UI transitions to internet search:
   - Query `GET /venues/internet-search?q=...`.
   - Results show venue name + full address from the external API.
   - Selecting a result pre-populates a confirmation form.
3. **If no internet match** — A "Enter Manually" option appears:
   - Opens a blank venue form (name, address fields).
4. **On confirm** — The venue is created (if new) and associated with the customer.

### 6.3 — Subvenue Management

- Each venue row is **expandable** to reveal its subvenues.
- Subvenues show the **effective name** (custom override if set, otherwise global default).
- An **edit icon** next to each subvenue name allows the customer to set a custom name.
- A **reset icon** appears when overridden, allowing revert to the global default.
- An **"Add Subvenue"** button at the bottom of the subvenue list allows creating new subvenues.

---

## 7. External Integration

### 7.1 — Places API

- Integrate with a places/geocoding API (e.g., Google Places API, Mapbox Geocoding, or OpenStreetMap Nominatim) for the internet venue search.
- The integration lives in **core-sys** as a service, not in the frontend (to protect API keys and control costs).
- Rate limiting and caching should be applied to minimize external API calls.

---

## 8. Migration Path

Since existing venues are tenant-scoped, a migration is needed:

1. Create `customer_venue` and `customer_venue_sub` tables.
2. For each existing `venue` record, insert a corresponding `customer_venue` row linking it to its current `tenant_id` — preserving existing associations.
3. Update RLS on `venue` and `venue_sub` to allow cross-tenant reads for search.
4. Deprecate direct `tenant_id` scoping on `venue` for access control (keep column for provenance tracking).

---

## 9. UX Flow Summary

```
Customer opens Venues tab
  └─► Sees only their associated venues (may be empty)
       └─► Clicks "Add Venue"
            └─► Types venue name in search box
                 ├─► System results appear → Selects one → Associated with customer
                 ├─► No system results → Internet results appear → Selects one → Pre-populated & saved
                 └─► No results → Clicks "Enter Manually" → Fills form → Saved to catalog & associated
       └─► Expands a venue row
            └─► Sees subvenues (default names or their custom names)
                 ├─► Edits a subvenue name → Custom override saved (default unchanged)
                 ├─► Resets a subvenue name → Override removed, default restored
                 └─► Adds new subvenue → Saved as global default + available to all customers
```

---

## 10. Open Questions

1. **Which external places API** to integrate with? (Google Places, Mapbox, Nominatim, etc.)
2. Should the `officials_association_id` FK on `venue` be retained, made optional, or removed since venues are now shared?
3. When a customer creates a new subvenue, should it immediately become a global default visible to all other customers who share that venue, or should there be an approval/moderation step?
4. Should customers be able to **remove** a venue from their list if it's referenced by existing contest schedules? (Soft-delete / archive vs. hard restriction.)
5. Should there be an **admin-only** view for managing the global venue catalog directly?
