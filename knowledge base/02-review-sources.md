<!-- Sources read:
  nimad_vue3/src/revamp/api/sources.js
  nimad_vue3/src/revamp/pages/property/BookingChannelsTab.vue
  nimad_vue3/src/revamp/helpers/validation.js (channel URL schemas)
  nimad_vue3/src/revamp/helpers/constants.js (BOOKING_CHANNELS)
  api/client/sources/sources.routes.js
  api/client/sources/sources.controller.js
  api/client/sources/sources.service.js
  api/client/sources/sources.validation.js
  api/client/holdings/holdings.routes.js
  models/SourcesM.js
-->

# Review Sources

## Overview

A review source is a booking channel URL (e.g. an Airbnb or Booking.com listing page) linked to a specific property. Revyoos scrapes reviews from each added source URL. One source per channel type is allowed per property. Sources are managed from the **Booking Channels** tab on the property detail page (`/properties/:id/channels`).

---

## User Flow

### View Booking Channels

1. User opens a property detail page (`/properties/:id`) and clicks the **"Booking Channels"** tab.
2. The tab heading reads: **"Booking Channels"** with the sub-text: **"Public URLs where your property is listed. Use the public URL — don't be logged into the source website."**
3. Each of the seven supported channels is shown as a row: **Airbnb**, **Booking**, **Vrbo**, **Expedia**, **Tripadvisor**, **Google**, **Trustpilot**.
4. For channels with no source added: an empty URL input (`placeholder="https://"`) and an **"Add"** button (disabled until the input has text) are shown.
5. For channels that already have a source: the URL is displayed as read-only text with an external-link icon, a status area (review count, **"Processing"**, **"Collect"**, or **"Error"**), and a trash icon to delete.

### Add a Source

1. User types or pastes a listing URL into the input for a channel row.
2. User clicks **"Add"** or presses Enter.
3. Client validates the URL against a channel-specific regex pattern. If invalid, an inline error appears: **"The provided link does not match the requested booking channel."** (Expedia shortened URLs show: **"This shortened URL cannot be processed. Please provide the full, unshortened URL."**)
4. If valid, `POST /api/holdings/:holdingId/sources` is called.
5. On success:
   - `toast.success('Source added successfully.')`
   - The row switches to the read-only display mode with `status_source: 0` (Processing).
   - The component begins polling every **5 seconds** for status changes.
6. On duplicate (same channel already added): server returns HTTP 409. `toast.error` is shown.
7. On error: `toast.error(getApiError(err, 'Failed to add source.'))`.

### Source Statuses

After a source is added, the status area to the right of the URL shows one of:

| UI Display | Condition | Meaning |
|---|---|---|
| Spinning "Processing" badge | `status_source === 0` or `status_source === 2` | Reviews are being collected (PENDING or PROCESSING). |
| **"Collect"** button | `status_source === 1` or `status_source === -3` | Ready to re-collect (ACTIVE or ERROR_DOWNLOADED). |
| Review count (clickable) | `m_reviews_summary.n_total_reviews >= 0` and not processing | Shows total reviews. Clicking navigates to `/properties/:holdingId/reviews?source=<channelKey>`. |
| **"Error"** text + tooltip | `status_source === -3` | Collection failed. Tooltip: **"Page not found — check that the URL is correct and publicly accessible."** |

The component stops polling as soon as no sources in state `0` or `2` remain.

### Trigger Manual Collection ("Collect" button)

1. When a source is in ACTIVE (`1`) or ERROR_DOWNLOADED (`-3`) state, a **"Collect"** button appears.
2. User clicks **"Collect"**.
3. `PUT /api/holdings/:holdingId/sources/:sourceId` is called with body `{ "status": 0 }`, which sets `status_source` to PENDING (`0`).
4. On success: `toast.success('Collection started.')`. Source returns to Processing state and polling restarts.
5. On error: `toast.error('Failed to start collection.')`.

### Delete a Source

1. User clicks the trash icon (🗑) on a channel row.
2. Confirmation dialog **"Remove Source"** opens with description: **"Are you sure you want to remove this source? All collected reviews from this channel will be lost."**
3. Buttons: **"Cancel"** / **"Remove"** (destructive).
4. On confirm: `DELETE /api/holdings/:holdingId/sources/:sourceId` is called.
5. The server permanently deletes the source record **and all associated reviews** (`ReviewsModel.deleteMany({ fk_id_source_reviews: sourceId })`). User data totals are recalculated.
6. On success: `toast.success('Source removed.')`. The property summary is refreshed.
7. On error: `toast.error(getApiError(err, 'Failed to remove source.'))`.

---

## Access Control

| Action | Requirement |
|---|---|
| View sources | Authenticated. Sources are scoped to the authenticated user (`fk_id_user_source`). |
| Add a source | Authenticated + active subscription (`subscribed()` middleware). |
| Collect (re-trigger scrape) | Authenticated + active subscription (`subscribed()` middleware). |
| Delete a source | Authenticated only (no subscription check). Deletes the source and all its reviews permanently. |
| Duplicate source | Blocked server-side: HTTP 409 if a source of the same `type_source` already exists for the holding. |

---

## Source Status Values

Defined in `models/SourcesM.js`:

| Value | Constant | Meaning |
|---|---|---|
| `0` | `PENDING` | Queued for collection. Shown as "Processing" in UI. |
| `1` | `ACTIVE` | Collection completed. "Collect" button shown. |
| `2` | `PROCESSING` | Currently being scraped. Shown as "Processing" in UI. |
| `3` | `DOWNLOADED` | Data downloaded (intermediate internal state). |
| `-1` | `DELETED` | Deleted (internal; not expected to appear in UI). |
| `-2` | `ERRORED` | General scrape error (internal). |
| `-3` | `ERROR_DOWNLOADED` | Page not found or inaccessible. "Error" shown in UI with tooltip; "Collect" button also shown. |
| `-4` | `DISABLED` | Source disabled (internal). |

---

## API Endpoints

All four endpoints are mounted at `/api/holdings/:holdingId/sources` and protected by the `authenticate` middleware. The `holdingId` is validated via `validateHolding` middleware before sources routes are reached.

---

### `GET /api/holdings/:holdingId/sources`

Returns all sources linked to a specific holding.

**Auth:** Bearer JWT (authenticated).

**Path parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `holdingId` | string | Yes | The holding's `_id`. |

**Response:**

```json
{
  "success": true,
  "data": {
    "sources": [
      {
        "_id": "abc123",
        "fk_id_user_source": "user456",
        "fk_id_holding_source": "holding789",
        "type_source": "airbnb",
        "url_source": "https://www.airbnb.com/rooms/12345",
        "status_source": 1,
        "status_sumtask_sources": 0,
        "m_reviews_summary": {
          "n_total_reviews": 42,
          "n_total_rating": 4.8
        }
      }
    ]
  }
}
```

---

### `POST /api/holdings/:holdingId/sources`

Add a new review source to a holding.

**Auth:** Bearer JWT + active subscription (`subscribed()` middleware).

**Path parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `holdingId` | string | Yes | The holding's `_id`. |

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `source` | string | Yes | Channel type. Allowed values: `booking`, `airbnb`, `tripadvisor`, `vrbo`, `expedia`, `google`, `trustpilot`. |
| `url` | string | Yes | Full public listing URL. Must be a valid URL (`z.url()`). Additional channel-specific regex validation is applied client-side before submission. |

**Client-side URL validation rules (Zod regex per channel):**

| Channel | Pattern requirement |
|---|---|
| `airbnb` | Must match `airbnb.[tld]` with a path segment. |
| `booking` | Must match `booking.[tld]/...`. |
| `vrbo` | Must match `vrbo`, `homeaway`, `stayz`, `abritel`, `fewo-direkt`, or `bookabach` domains. |
| `expedia` | Must match `expedia.[tld]/...`. Shortened URLs (`/hNNNN.Hotel-Information`) are rejected. |
| `tripadvisor` | Must match `tripadvisor.[tld]/...`. |
| `google` | Must match `google.[tld]/...`. |
| `trustpilot` | Must match `trustpilot.[tld]/...`. |

**Error (invalid channel type):** HTTP 400 (Zod enum validation).

**Error (duplicate source):** HTTP 409.

```json
{
  "success": false,
  "errors": [{ "message": "A source of this type already exists for this holding" }]
}
```

**Response (success):** HTTP 201.

```json
{
  "success": true,
  "data": {
    "source": {
      "_id": "newSourceId",
      "type_source": "airbnb",
      "url_source": "https://www.airbnb.com/rooms/99999",
      "status_source": 0
    }
  }
}
```

New source is created with `status_source: 0` (PENDING) and `status_sumtask_sources: 0`.

---

### `PUT /api/holdings/:holdingId/sources/:sourceId`

Update a source's status. Used by the **"Collect"** button to re-trigger scraping.

**Auth:** Bearer JWT + active subscription (`subscribed()` middleware).

**Path parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `holdingId` | string | Yes | The holding's `_id`. |
| `sourceId` | string | Yes | The source's `_id`. |

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `status` | integer | Yes (at least one of `status` or `url`) | New `status_source` value. Frontend sends `0` to re-queue collection. |

**Response (success):**

```json
{
  "success": true,
  "data": {
    "source": { "...updated source object..." }
  }
}
```

**Response (not found):**

```json
{
  "success": false,
  "errors": [{ "message": "Source not found" }]
}
```

---

### `DELETE /api/holdings/:holdingId/sources/:sourceId`

Delete a source and permanently remove all its associated reviews.

**Auth:** Bearer JWT (authenticated; no subscription check).

**Path parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `holdingId` | string | Yes | The holding's `_id`. |
| `sourceId` | string | Yes | The source's `_id`. |

**Side effects:**
- All reviews with `fk_id_source_reviews === sourceId` are permanently deleted.
- User data totals (`m_holdings_summary`) are recalculated.

**Response (success):**

```json
{
  "success": true,
  "message": "Source deleted successfully"
}
```

---

## Components

| File | Route | Purpose |
|---|---|---|
| `nimad_vue3/src/revamp/pages/property/BookingChannelsTab.vue` | `/properties/:id/channels` | Full Booking Channels UI: lists all 7 channels, shows source status, add/collect/delete actions, delete confirmation dialog, 5-second polling for processing sources. |
