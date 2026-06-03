<!-- Sources read:
  nimad_vue3/src/revamp/api/holdings.js
  nimad_vue3/src/revamp/pages/Properties.vue
  nimad_vue3/src/revamp/pages/CreateProperty.vue
  nimad_vue3/src/revamp/pages/Property.vue
  nimad_vue3/src/revamp/pages/properties/DeleteDialog.vue
  nimad_vue3/src/revamp/pages/properties/ExportDialog.vue
  nimad_vue3/src/revamp/pages/properties/PropertiesFilters.vue
  nimad_vue3/src/revamp/pages/properties/PropertiesGroups.vue
  nimad_vue3/src/revamp/pages/properties/PropertyGroupAssignPopover.vue
  nimad_vue3/src/revamp/router/index.js
  nimad_vue3/src/revamp/helpers/validation.js
  nimad_vue3/src/revamp/helpers/constants.js
  plugins_api/HoldingsApiPlugin.js
  plugins_api/HoldingsgroupsApiPlugin.js
  plugins_api/HoldingsbulkdeleteApiPlugin.js
  plugins_api/RestoreApiPlugin.js
  controllers/HoldingController.js
  controllers/ApiController.js
-->

# Properties / Holdings Management

## Overview

Properties (called "holdings" in the backend) are the core entity in Revyoos. Each property aggregates reviews from one or more booking channels (Airbnb, Booking.com, Vrbo, Expedia, Tripadvisor, Google, Trustpilot). Users can organise properties into named groups, export the full list, bulk-delete, and recover deleted properties from a Recycle Bin (soft-delete model). The Recycle Bin restore page is currently routed but renders `MockupPage` — the restore API backend is fully implemented.

---

## User Flow

### Create a Property

1. User navigates to `/properties/new` ("New Property" page, `CreateProperty.vue`).
2. The page header reads **"New Property"** with subtitle **"Add your property details and connect your booking channels to get started."**
3. User fills in **Property Name** (required field, labelled `Property Name *`).
4. Optionally, user pastes listing URLs into any of the booking channel inputs: **Airbnb**, **Booking**, **Vrbo**, **Expedia**, **Tripadvisor**, **Google**, **Trustpilot**.
5. User clicks **"Create Property"** button.
   - If property name is empty, the button is disabled.
   - On click, client validates the name and each non-empty URL using Zod schemas. If validation fails, inline error messages appear per field.
   - If valid, the client calls `checkPropertyLimit()`. If the current holding count exceeds the plan limit, a dialog **"Property Limit Reached"** opens showing current count and plan limit with buttons **"Cancel"** / **"Continue & Upgrade"**.
   - On "Continue & Upgrade" (or when no limit is exceeded), `POST /lapi/holdings` is called.
   - On success: `toast.success('Property created successfully')` and redirect to `/properties`.
   - On error: `toast.error(getApiError(err, 'Failed to create property.'))`.

### List Properties

1. User navigates to `/properties`.
2. If the user has no properties (`n_total_holdings === 0`), the page shows:
   - **"No properties found"**
   - **"Your properties will appear here once they are added."**
   - A `QuickStartWizard` component below.
3. If properties exist, the page shows a list/grid of property cards with:
   - Property name, assigned groups, aggregate rating and review count, per-channel rating pills.
   - Sentiment donut and top sentiment tags (shown when sentiment data is available and the sentiment toggle is active).
4. Controls available:
   - **Search** — `PropertiesSearch` component; searches by name, filters list on select.
   - **Sorting** — dropdown (`data-testid="property-sorting"`) with options: `Name (A to Z)`, `Rating: High to Low`, `Rating: Low to High`, `Reviews Count: High to Low`, `Reviews Count: Low to High`.
   - **Filters** button — toggles `PropertiesFilters` panel. Active filters show as chips; each chip has an `×` to remove it. A **"Clear all"** button (`data-testid="clear-all-properties-filters"`) removes all active filters.
   - **Select all** checkbox — selects all properties on the current page. If selected, a prompt appears: _"All N properties on this page have been selected."_ with a **"Select all properties in your account."** link.
   - **Clear all** button (`data-testid="reset-properties-selections"`) — deselects everything.
   - **Delete Selected** / **Delete All Properties In Your Account** (red, from `DeleteDialog`).
   - **Assign Groups** (disabled when nothing selected) — opens `PropertyGroupAssignPopover`.
   - **Export All** — opens `ExportDialog`.
5. Pagination at the bottom; default 10 items per page.
6. Empty filtered state shows **"No properties found"** (no sub-text).

### View a Single Property

1. User clicks a property name — navigates to `/properties/:id` (defaults to **General** tab).
2. Four tabs are available: **General**, **Reviews**, **Booking Channels**, **Summaries**.
3. A three-dot (⋮) menu in the top-right corner has two items:
   - **"Edit Name"** — opens dialog **"Edit Property Name"** with description **"Enter a new name for this property."** Buttons: **"Cancel"** / **"Save"**.
   - **"Delete Property"** — opens dialog **"Delete Property"** with description: _"Are you sure you want to delete **[name]**? This action cannot be undone."_ Buttons: **"Cancel"** / **"Delete"** (destructive).
4. Groups appear as tags below the title. A `+` button opens `PropertyGroupAssignPopover` to add more groups.
5. If property is not found: **"Property not found"** / **"This property may have been deleted or doesn't exist."**

### Edit Property Name (inline on Property page)

1. User opens ⋮ → **"Edit Name"** on the Property detail page.
2. Dialog **"Edit Property Name"** opens with an input pre-filled with the current name.
3. User edits and clicks **"Save"** (or presses Enter).
4. On success: `toast.success` (message text [NOT FOUND IN CODE] — success toast is called but text not visible in the read portion).
5. On error: `toast.error(getApiError(err, 'Failed to update property name.'))` [NOT FOUND IN CODE — exact fallback message not confirmed].

### Delete a Single Property (from Property detail page)

1. User opens ⋮ → **"Delete Property"**.
2. Dialog confirms with the property name. User clicks **"Delete"**.
3. `DELETE /lapi/holdings/:id` is called. Property moves to the Recycle Bin.
4. On success: user is redirected to `/properties`.

### Bulk Delete Properties

1. User selects one or more properties on the Properties list (checkboxes).
2. **"Delete Selected (N)"** button becomes active.
3. Modal title: **"Delete N propert[y/ies]?"**
4. Modal description: **"This action will move the selected properties to the Restore Properties list. You can recover them from there if needed."**
5. Buttons: **"Cancel"** / **"Delete"** (destructive).
6. On confirm: `POST /lapi/holdings/delete-bulk` with selected IDs.
7. On success: `toast.success('N propert[y/ies] deleted.')` and page reloads to page 1.
8. On error: `toast.error(getApiError(error, 'Failed to delete properties.'))`.

### Delete All Properties in Account

1. User selects all properties and then clicks **"Select all properties in your account."**
2. Button label becomes **"Delete All Properties In Your Account"**.
3. Modal title: **"Delete all properties in your account?"**
4. Modal description: **"This action will move all properties in your account to the Restore Properties list. You can recover them from there if needed."**
5. On confirm: `DELETE /lapi/holdings` (deletes all for user).
6. On success: `toast.success('All properties have been deleted.')`.

### Export Properties

1. User clicks **"Export All"** (`data-testid="export-dialog-open-btn"`).
2. Modal **"Export Properties"** opens with description: **"This export includes all properties in your account, regardless of current filters."**
3. User selects format:
   - **Microsoft Excel (.xlsx)** — "Full report with all details."
   - **CSV Document (.csv)** — "Raw data format for external tools."
4. User clicks **"Download File"**.
5. Browser is directed to `GET /lapi/holdings/export?format=xlsx|csv&token=<jwt>` — a direct file download (streamed by server, not via Axios).

### Groups — Assign to Properties

1. User selects one or more properties, clicks **"Assign Groups"**.
2. A popover (`PropertyGroupAssignPopover`) opens with a search/create input (`placeholder="Search or create a group..."`).
3. If no groups exist and query is empty: _"No groups found. Type to create your first group."_
4. If query returns no matches: **"No groups found."** + **"Create group "[query]""** button (`data-testid="add-group-btn"`).
5. Existing and newly typed groups appear as checkboxes. User selects one or more.
6. User clicks apply button:
   - Single property: **"Apply to property"**
   - Multiple: **"Apply to N propert[y/ies]"**
   - All account properties selected: **"Apply to all properties"**
7. `POST /lapi/holdings/groups/bulk-assign` is called with `propertyIds` (array or `"ALL_PROPERTIES"`) and `groupsToAdd`.
8. On success: `toast.success('Group assigned.')`. Popover closes.
9. On error: `toast.error(getApiError(error, 'Failed to assign groups'))`.

### Groups — Remove from a Property

1. On any property card or property detail page, group tags appear. Hovering reveals an `×` button (`aria-label="Delete group button"`, `data-testid="delete-group-[name]-btn"`).
2. User clicks `×`.
3. `DELETE /lapi/holdings/:holdingId/groups/:groupName` is called.
4. On error: `toast.error(getApiError(error, 'Failed to delete group'))`.

### Groups — Filter Properties

1. User clicks **"Filters"** on the Properties list.
2. **Groups** filter: searchable multi-select. Multiple groups selected apply AND logic (property must belong to all selected groups).
3. **Rating** filter: checkboxes for 5, 4, 3, 2, 1 stars.
4. Active filter chips appear below controls. Each chip has an `×` (`data-testid="clear-groups-filter-[value]"` / `data-testid="clear-rating-filter-[value]"`).

### Recycle Bin — Restore Properties

1. Route `/properties/restore` exists (`name: 'PropertiesRestore'`) but currently renders `MockupPage` (UI not yet built).
2. The backend (`RestoreApiPlugin`) is fully implemented:
   - `GET /lapi/restore` — returns paginated list of soft-deleted properties.
   - `POST /lapi/restore` — restores selected properties (holdings, their sources, and their reviews are all reinstated).

---

## Access Control

| Action | Requirement |
|---|---|
| Create property | Authenticated (JWT token). Trial active or active subscription. Exceeding plan property limit shows **"Property Limit Reached"** dialog and auto-upgrades Stripe subscription on confirmation. |
| List / view properties | Authenticated. Properties are scoped to `fk_id_user_holding` — users see only their own properties. |
| Edit property name | Authenticated, owner of the property. Returns 404 if property not found or belongs to another user. |
| Delete property (single) | Authenticated, owner. Soft-delete — moved to recycle collection. |
| Bulk delete / delete all | Authenticated, owner. |
| Export properties | Authenticated. JWT passed as query param `token` because anchor download cannot set Authorization header. |
| Assign / remove groups | Authenticated, owner. Group name max 50 characters enforced server-side. |
| Restore from Recycle Bin | Authenticated. Requires trial active (`date_end_trial` in the future) OR active subscription with a plan (`b_active_subscription && o_plan`). If neither: response `{ b_valid: false, message: 'You need to be on a trial or have an active subscription to restore properties.' }`. |
| Restore — name conflict | Restore is blocked if any restoring property's name matches an existing active property. Error: `"You already have holdings with the following names: <b>[names]</b>. Please rename or delete them before restoring."` |

---

## API Endpoints

### `GET /lapi/holdings`

**Auth:** Bearer JWT required.

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `page` | integer | No | Page number. Default: `1`. |
| `limit` | integer | No | Items per page. Default: `100`. |
| `search` | string | No | Filters by `name_holding` (case-insensitive regex). If `useInternalName` is set on user, also searches `internalName`. |
| `sortBy` | string | No | Field to sort by. Frontend sends: `name` (maps to `name_holding`), `bestReviews`, `worstReviews`, `highestReviewsCount`, `lowestReviewsCount`. Default: `name_holding`. |
| `groups` | string | No | Comma-separated group names. AND logic — property must belong to all specified groups. |
| `rating` | array | No | [NOT FOUND IN CODE — passed by frontend but filtering logic not confirmed in plugin]. |

**Response:**

```json
{
  "b_valid": true,
  "a_holdings": [ { "...holding object..." } ],
  "totalCount": 42,
  "code": 200
}
```

The `a_holdings` array items include: `_id`, `name_holding`, `holdingName`, `groups`, `reviewsSummary` (`n_total_rating`, `n_total_reviews`), `sourceSummary` (per-channel `n_rating`, `n_reviews`), `sentiments`.

---

### `GET /lapi/holdings/:id`

**Auth:** Bearer JWT required.

**Response:**

```json
{
  "b_valid": true,
  "a_holdings": [ { "...single holding object..." } ],
  "totalCount": 1,
  "code": 200
}
```

Frontend reads `resp.data?.holding || resp.data`.

---

### `GET /lapi/holdings/search`

**Auth:** Bearer JWT required.

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `name` | string | No | Name fragment to search. |

**Response:** [NOT FOUND IN CODE — response shape not confirmed in plugin; used by `PropertiesSearch` component for typeahead.]

---

### `POST /lapi/holdings`

Create a new property.

**Auth:** Bearer JWT required.

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | Property name. Min 2, max 200 characters. Cannot be a website URL. |
| `sources` | array | No | Array of `{ url, source }` objects. `source` is one of: `airbnb`, `booking`, `vrbo`, `expedia`, `tripadvisor`, `google`, `trustpilot`. Each URL validated by channel-specific regex on the client before submission. |

**Response:**

```json
{
  "b_valid": true,
  "...holding insert result..."
}
```

If trial expired:

```json
{
  "b_valid": false,
  "s_msg": "..."
}
```

---

### `PUT /lapi/holdings/:id`

Update property name.

**Auth:** Bearer JWT required.

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | New property name. |

**Response:**

```json
{ "b_valid": true, "code": 200, "s_msg": "OK" }
```

Error (not found / wrong user):

```json
{ "b_valid": false, "code": 404, "s_msg": "Error updating the holding" }
```

---

### `DELETE /lapi/holdings/:id`

Soft-delete a single property (moves to Recycle Bin). Triggers `recalculate_user_data_and_save_it`.

**Auth:** Bearer JWT required.

**Response:**

```json
{ "b_valid": true }
```

---

### `DELETE /lapi/holdings`

Soft-delete **all** properties for the authenticated user.

**Auth:** Bearer JWT required.

**Response:**

```json
{ "b_valid": true }
```

---

### `POST /lapi/holdings/delete-bulk`

Soft-delete a selected list of properties.

**Auth:** Bearer JWT required.

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `ids` | array | Yes | Array of holding `_id` strings to delete. |

**Response:**

```json
{ "b_valid": true }
```

---

### `GET /lapi/holdings/export`

Download all properties as a file. Streamed directly — not via the standard JSON response.

**Auth:** JWT passed as query param `token` (not Authorization header).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `format` | string | Yes | `xlsx` or `csv`. |
| `token` | string | Yes | JWT token from `localStorage.getItem('s_token')`. |

**Response:** Binary file stream (`Content-Disposition: attachment; filename="..."`).

---

### `GET /lapi/holdings/groups`

Return all unique group names for the authenticated user with usage count, sorted alphabetically.

**Auth:** Bearer JWT required.

**Response:**

```json
{
  "b_valid": true,
  "groups": [
    { "name": "Beach Houses", "usageCount": 3 },
    { "name": "City Apartments", "usageCount": 7 }
  ],
  "code": 200
}
```

---

### `POST /lapi/holdings/groups/bulk-assign`

Assign one or more groups to one or more properties (or all properties).

**Auth:** Bearer JWT required.

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `propertyIds` | array or `"ALL_PROPERTIES"` | Yes | Array of holding `_id` strings, or the string `"ALL_PROPERTIES"` to target every property of the user. |
| `groupsToAdd` | array of strings | Yes | Group names to assign. Each name max 50 characters. |

Server uses `$addToSet` — duplicate groups on a property are skipped.

**Response:**

```json
{
  "b_valid": true,
  "s_msg": "Groups updated for 5 properties.",
  "updatedCount": 5,
  "totalProcessed": 10,
  "code": 200
}
```

---

### `DELETE /lapi/holdings/:holdingId/groups/:groupName`

Remove a named group from a specific property.

**Auth:** Bearer JWT required.

**Response:**

```json
{
  "b_valid": true,
  "s_msg": "Group removed from property successfully.",
  "removed": true,
  "groupStillUsed": false,
  "code": 200
}
```

Error (not found):

```json
{ "b_valid": false, "s_msg": "Property not found or access denied.", "code": 404 }
```

---

### `GET /lapi/restore`

Get paginated list of soft-deleted properties available for restoration.

**Auth:** Bearer JWT required.

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `page` | integer | No | Default: `1`. |
| `limit` | integer | No | Default: `1`. |

**Response:**

```json
{
  "b_valid": true,
  "s_msg": "OK",
  "data": {
    "total": 5,
    "data": [ { "...recycle entry..." } ]
  }
}
```

---

### `POST /lapi/restore`

Restore one or more properties from the Recycle Bin. Reinstates holdings, sources (with `status_source: 0`), and reviews. Triggers user data recalculation.

**Auth:** Bearer JWT required. Must be on trial or have active subscription.

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `holdings` | array | Yes | Array of holding `_id` strings to restore. |

**Response (success):**

```json
{ "b_valid": true, "message": "" }
```

**Response (subscription gate):**

```json
{
  "b_valid": false,
  "message": "You need to be on a trial or have an active subscription to restore properties."
}
```

**Response (name conflict):**

```json
{
  "b_valid": false,
  "message": "You already have holdings with the following names: <b>Villa Sunset, Beach House</b>. Please rename or delete them before restoring."
}
```

**Response (generic failure):**

```json
{ "b_valid": false, "message": "Unable to restore properties. Try again later." }
```

---

### `GET /lapi/holdings/unlinked-count`

Returns the count of properties with no linked sources. [NOT FOUND IN CODE — response shape not confirmed.]

**Auth:** Bearer JWT required.

---

## Components

| File | Route | Purpose |
|---|---|---|
| `nimad_vue3/src/revamp/pages/Properties.vue` | `/properties` | Properties list — search, sort, filter, select, bulk-delete, assign groups, export. |
| `nimad_vue3/src/revamp/pages/CreateProperty.vue` | `/properties/new` | Create new property form with name field and optional booking channel URLs. |
| `nimad_vue3/src/revamp/pages/Property.vue` | `/properties/:id/:tab?` | Single property detail — tabs: General, Reviews, Booking Channels, Summaries. Edit name and delete dialogs. |
| `nimad_vue3/src/revamp/pages/properties/DeleteDialog.vue` | (modal, used in Properties.vue) | Bulk-delete / delete-all confirmation modal. |
| `nimad_vue3/src/revamp/pages/properties/ExportDialog.vue` | (modal, used in Properties.vue) | Export format selector and download trigger. |
| `nimad_vue3/src/revamp/pages/properties/PropertiesFilters.vue` | (panel, used in Properties.vue) | Groups (searchable multi-select) and Rating (checkboxes 1–5) filter panel with active-filter chips. |
| `nimad_vue3/src/revamp/pages/properties/PropertiesGroups.vue` | (inline, used in Properties.vue and Property.vue) | Renders group tags; hover reveals per-group delete button. |
| `nimad_vue3/src/revamp/pages/properties/PropertyGroupAssignPopover.vue` | (popover, used in Properties.vue and Property.vue) | Search/create groups, multi-select, assign to one or more properties. |
| `nimad_vue3/src/revamp/pages/properties/PropertiesSearch.vue` | (inline, used in Properties.vue) | Typeahead search component for filtering properties by name. |
| `nimad_vue3/src/revamp/pages/property/GeneralTab.vue` | (tab, `/properties/:id`) | General stats tab inside a property. |
| `nimad_vue3/src/revamp/pages/property/ReviewsTab.vue` | (tab, `/properties/:id/reviews`) | Reviews list tab inside a property. |
| `nimad_vue3/src/revamp/pages/property/BookingChannelsTab.vue` | (tab, `/properties/:id/channels`) | Booking channels management tab. |
| `nimad_vue3/src/revamp/pages/property/SummariesTab.vue` | (tab, `/properties/:id/summaries`) | AI summaries tab inside a property. |
| `nimad_vue3/src/revamp/pages/Mockup.vue` | `/properties/restore` | Placeholder — Recycle Bin UI is not yet implemented. |
