<!-- Sources read:
  nimad_vue3/src/revamp/pages/DirectReviewsFormBuilder.vue
  nimad_vue3/src/comment/pages/DirectReviewForm.vue
  nimad_vue3/src/comment/api/index.js
  nimad_vue3/src/comment/router/index.js
  nimad_vue3/src/revamp/api/reviews.js (exportReviewLinks, getDirectReviewsSummary)
  api/client/reviews/request/reviewsRequest.routes.js
  api/client/reviews/request/reviewsRequest.controller.js
  api/client/reviews/request/reviewsRequest.service.js
  api/client/reviews/request/reviewsRequest.validation.js
  api/client/holdings/holdings.routes.js
  api/client/holdings/holdings.service.js (getDirectReviewsSummary, exportReviewLinks)
  api/client/holdings/holdings.constants.js
  api/client/holdings/holdings.validation.js (exportReviewLinksSchema, getDirectReviewsSummarySchema)
-->

# Direct Review Request Form

## Overview

Direct Reviews gives property managers a unique, shareable URL per property (`https://www.revyoos.com/comment/:holdingId`) that guests can use to submit a review without being logged in. The dashboard page (`/reviews/request`) lists all properties with their review links, direct review counts, and copy/export actions. Submitted reviews are saved as `type_source_reviews: 'revyoos'` (direct reviews).

---

## User Flow

### Dashboard — Direct Review Links (`/reviews/request`)

1. User navigates to `/reviews/request`.
2. Page title: **"Direct Reviews"**. Subtitle: **"Manage unique review collection links for each of your properties. Share these forms directly with your guests to collect feedback."**
3. A yellow warning banner always displays: **"These links are unique and should not be published publicly. They are exclusively for sharing directly with your guests."**
4. A search field (`placeholder="Search properties..."`) filters the list by property name (debounced, 300ms).
5. An **"Export Links"** button (`data-testid="export-dialog-open-btn"`) is shown. If the user has no active plan (`hasPlan()` returns false), clicking it opens a modal **"Your trial has expired"** with content: _"To continue enjoying our application, you need to subscribe to one of our plans."_ and a **"Upgrade now"** button linking to `/account/subscription`. Otherwise, the Export Links modal opens.
6. The **"Direct Review Links"** table shows columns: **Properties**, **Request Review Form**, **Reviews**, **Actions**.
7. Each row shows:
   - Property name.
   - The full form URL as a clickable link: `https://www.revyoos.com/comment/:holdingId`.
   - Direct review count (clicking it navigates to `/properties/:holdingId/reviews?source=direct`).
   - A copy button (`data-testid="copy-url-button-{id}"`) that writes the URL to the clipboard. On success: `toast.success('Link copied to clipboard')`. On failure: `toast.error('Failed to copy link')`.
8. Empty state: **"No properties found."**
9. Paginated at 10 items per page.

### Export Review Links

1. User clicks **"Export Links"** (requires an active plan).
2. The **"Export Review Links"** modal opens with description: **"Select your preferred format to export the review links for all your properties."**
3. Format options:
   - **Microsoft Excel (.xlsx)** — "Best for viewing and printing."
   - **CSV Document (.csv)** — "Best for importing into other apps."
4. The file begins generating immediately when the modal opens (pre-fetched). A **"Download File"** button is shown; disabled until the file is ready. On click: file is saved as `reviews_links.<ext>`.
5. Export columns: **Property**, **Review Link**.

### Guest Review Form (`/comment/:holdingId`)

The guest-facing form is a separate Vue app (at `nimad_vue3/src/comment/`) served at the `/comment/` path. It does not require authentication.

1. Guest navigates to `https://www.revyoos.com/comment/:holdingId`.
2. The app calls `GET /api/reviews/request/:holdingId` to load the property name. If the property is not found (HTTP 404), the guest is redirected to the main site.
3. Page heading: **"Review your stay in [Property Name]"**.
4. Language selector shows: `EN`, `FR`, `ES`, `DE`, `NL`, `IT`, `PT`. The browser's language is auto-detected on load; defaults to `en` if not in the supported list.
5. The form has three sections:

   **About** section:
   - **Name \*** — text input. Required.
   - **Email address \*** — text input (validated as email). Required.
   - **Date of stay** — date picker (calendar popover). Defaults to today. Required. Sent as `YYYY-MM-DD`.

   **Rating experience** section:
   - Six star-rating sub-scores (1–5 stars each), all required:
     - **Accuracy**, **Communication**, **Cleanliness**, **Location**, **Check-In**, **Value for money**.
   - An overall average score is computed and displayed in real time from the six sub-scores. The computed average is sent as `score`.
   - Validation: all six ratings must be ≥ 1. Error: `"All ratings are required"`.

   **Your thoughts** section:
   - **Title \*** — text input. Required. Character counter shown (max 100). Turns red above 100 characters.
   - **Comment \*** — textarea. Required. Character counter shown (max 1000). Status: `"OK!"` when ≥ 20 chars; warning at 900+; error above 1000.
   - **Private Feedback** — textarea (optional). Labeled with a lock icon. Note text from dictionary. Not shown publicly.

   **Terms checkbox** — must be checked. Links to Revyoos terms page. Error: `"You must accept the terms"`.

6. Submit button shows **"Submit Review"** / **"Submitting review..."** while saving.
7. Client-side validation runs on submit via `createDirectReviewSchema` (Zod). If invalid: `toast.error('Please review the highlighted fields.')` and per-field errors shown inline.
8. On success: a success modal opens showing a checkmark icon and the property name. Form is reset.
9. On API error (including duplicate): `toast.error(getApiError(error, 'Failed to submit comment.'))`.

---

## Access Control

| Action | Requirement |
|---|---|
| View Direct Review Links dashboard | Authenticated. |
| Export review links | Authenticated + active plan (`subscribed()` middleware). |
| View guest review form (`/comment/:holdingId`) | No authentication. Public endpoint. |
| Submit a review via form | No authentication. Duplicate check via checksum. |

---

## API Endpoints

---

### `GET /api/reviews/request/:holdingId`

Load property information for the guest form. Public — no authentication required.

**Path parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `holdingId` | string | Yes | The holding's `_id`. |

**Response (success):**

```json
{
  "success": true,
  "data": {
    "holdingId": "hold123",
    "name": "Beach Villa"
  }
}
```

**Response (not found):** HTTP 404 — `"Property not found"`. (Soft-deleted holdings with `status_holding: -1` are treated as not found.)

---

### `POST /api/reviews/request/:holdingId`

Submit a guest review. Public — no authentication required. Body is sanitized via `sanitizeBody()` middleware before validation.

**Path parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `holdingId` | string | Yes | The holding's `_id`. |

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `name_user` | string | Yes | Reviewer's name. Min 1 character. |
| `email_user_review` | string | Yes | Reviewer's email address. Must be a valid email. |
| `title_review` | string | Yes | Review title. Min 1 character. |
| `content_review` | string | Yes | Review body text. Min 1 character. |
| `score` | number | Yes | Overall star rating. Range: 1–5. |
| `score_detailed` | object | No | Per-category ratings (each 0–5): `accuracy`, `communication`, `cleanliness`, `location`, `checkIn`, `valueForMoney`. |
| `privateFeedback` | string | No | Private note for property owner only. Defaults to `""`. |
| `date_stay` | string | Yes | Date of stay. Format: `YYYY-MM-DD`. |
| `b_terms` | boolean | Yes | Must be `true` (terms accepted). |
| `lang` | string | No | Detected language code (e.g. `"en"`, `"fr"`). Stored on the review. |

**Server processing:**
1. Looks up the holding (404 if not found or soft-deleted).
2. Gets or auto-creates a `revyoos` source for the holding (`SourcesModel.findOneAndUpdate` with upsert).
3. Builds the review document with `type_source_reviews: 'revyoos'`, `url_reviews: 'www.revyoos.com'`, `status_reviews: 1`.
4. Computes a checksum. If a review with that checksum already exists: HTTP 409 — `"This review has already been submitted"`.
5. Inserts the review into `ReviewsModel`.
6. Recalculates user data totals.

**Response (success):** HTTP 201.

```json
{
  "success": true,
  "data": { "reviewId": "rev789" }
}
```

**Response (duplicate):** HTTP 409.

```json
{
  "success": false,
  "errors": [{ "message": "This review has already been submitted" }]
}
```

---

### `GET /api/holdings/direct-reviews`

Get a paginated list of all user properties with their direct review counts and form URLs.

**Auth:** Bearer JWT (authenticated).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `page` | integer | No | Default: `1`. |
| `limit` | integer | No | Default: `20`. Max: `100`. |
| `search` | string | No | Case-insensitive substring search on `name_holding`. |

**Response:**

```json
{
  "success": true,
  "data": {
    "holdings": [
      {
        "holdingId": "hold123",
        "holdingName": "Beach Villa",
        "directReviewsCount": 14
      }
    ],
    "pagination": {
      "currentPage": 1,
      "totalPages": 5,
      "totalItems": 50,
      "itemsPerPage": 20,
      "hasNext": true,
      "hasPrev": false
    }
  }
}
```

Soft-deleted holdings (`status_holding: -1`) are excluded.

---

### `GET /api/holdings/review-links/export`

Export the review request links for all user properties as a downloadable file.

**Auth:** Bearer JWT + active subscription (`subscribed()` middleware).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `format` | string | No | `csv` or `xlsx`. Default: `csv`. |

**Response:** Binary file stream.

```
Content-Disposition: attachment; filename="review-links.<ext>"
Content-Type: text/csv  (or application/vnd.openxmlformats-officedocument.spreadsheetml.sheet)
```

Export columns: **Property**, **Review Link**.

---

## Components

| File | Route | Purpose |
|---|---|---|
| `nimad_vue3/src/revamp/pages/DirectReviewsFormBuilder.vue` | `/reviews/request` | Dashboard — property list with review links, copy-to-clipboard, direct review count, search, export modal, trial-expired alert modal. |
| `nimad_vue3/src/comment/pages/DirectReviewForm.vue` | `/comment/:id` | Public guest-facing review form — multi-language, six-category star ratings, private feedback field, terms checkbox, success modal. Separate Vue app entry point. |
