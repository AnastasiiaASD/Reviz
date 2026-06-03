<!-- Sources read:
  nimad_vue3/src/revamp/pages/Reviews.vue
  nimad_vue3/src/revamp/pages/reviews/ReviewsFilters.vue
  nimad_vue3/src/revamp/pages/reviews/ExportReviewsDialog.vue
  nimad_vue3/src/revamp/pages/reviews/UpgradeAlertDialog.vue
  nimad_vue3/src/revamp/pages/property/ReviewsTab.vue
  nimad_vue3/src/revamp/api/reviews.js
  nimad_vue3/src/revamp/helpers/constants.js (SENTIMENTS, TOPICS, SOURCE_LABELS)
  api/client/reviews/reviews.routes.js
  api/client/reviews/reviews.validation.js
  api/client/reviews/reviews.service.js
-->

# Reviews Management

## Overview

Reviews Management gives users a unified view of all reviews collected across properties and booking channels. Reviews can be filtered by property, group, source, star rating, date range, reply status, sentiment, topic, and tag. The global Reviews page (`/reviews`) covers the entire account; the Reviews tab inside a property detail page scopes the same list to a single property. Both surfaces share the same API endpoint and filter set.

---

## User Flow

### View Reviews (global)

1. User navigates to `/reviews`.
2. A **"Filters"** button appears in the top-right. Clicking it opens the filters panel.
3. Reviews load immediately with default parameters (page 1, limit 20, sorted newest first).
4. The count line reads: **"N Review[s] found"**.
5. Each review is rendered as a `ReviewCard` showing review text, star rating, source channel, date, and the associated property name (with a link to the property).
6. Empty state: **"No reviews found."**
7. Pagination is shown below the list.

### View Reviews (per-property tab)

1. User opens `/properties/:id/reviews`.
2. Identical filter and list UI, but scoped to the single property.
3. Empty state: **"No reviews found for this property."** + an **"Add Booking Channels"** button that navigates to the Channels tab.

### Filters

The **"Filters"** button toggles the filter panel. Active filters appear as dismissible chips below the panel. A **"Clear all"** button (`data-testid="clear-all-reviews-filters"`) removes every active filter at once.

#### BASIC section

| Filter | UI control | Behaviour |
|---|---|---|
| **Properties** | Searchable multi-select (typeahead via `searchHoldings`) | Disabled when Groups filter has selections. `data-testid="clear-properties-filter-{id}"` on each chip. |
| **Groups** | Searchable multi-select (from `getHoldingGroups`) | Disabled when Properties filter has selections. The label **"OR"** between Properties and Groups makes the mutual exclusion explicit. `data-testid="clear-groups-filter-{value}"` per chip. |
| **Sources** | Checkboxes | Values: `airbnb`, `booking`, `google`, `expedia`, `tripadvisor`, `trustpilot`, `vrbo`, `direct`, `imported`. Labels: `Airbnb`, `Booking.com`, `Google`, `Expedia`, `Tripadvisor`, `Trustpilot`, `Vrbo`, `Direct Reviews`, `Imported Reviews`. Source list is fetched live from `GET /api/reviews/sources`. `data-testid="clear-source-filter-{value}"` per chip. |
| **Rating** | Checkboxes (star display) | Values: 5, 4, 3, 2, 1. `data-testid="clear-rating-filter-{value}"` per chip. |
| **Date range** | Date range picker (`from` / `to`) | `dateFrom` and `dateTo` sent as ISO date strings. `data-testid="clear-dates-filter"` on the chip. |
| **Reply status** | 3-way toggle (All / No Reply / Replied) | `all` = no filter sent; `no_reply` = `answered=false`; `replied` = `answered=true`. Reply status is included in "Clear all". |

A **"Clear"** button next to the Properties/Groups pair clears both simultaneously (`data-testid="clear-properties-and-groups-reviews-filters"`).

#### ANALYTICS section

Visible only when the user's plan is `businessAi`.

| Filter | UI control | Values |
|---|---|---|
| **Sentiments** | Checkboxes | `Positive`, `Neutral`, `Negative`. |
| **Topics** | Checkboxes | `Accuracy`, `Amenities`, `Check-in`, `Cleanliness`, `Communication`, `Location`, `Value for money`. |
| **Tags** | Searchable multi-select (from `getStatsTags`) | Dynamic list from analytics tags. |

Sentiment/topic/tag filtering joins against `AnalyticsModel` by `content_hash`, so only reviews with processed analytics data are returned when these filters are active.

### Sorting

Default sort: `date: -1` (newest first). No sort UI control is exposed on this page — the sort order is fixed.

### Pagination

Default 20 items per page. Maximum 100. Page number and items-per-page are both controlled by `DataPagination`. On page change, the page scrolls to the top.

### Export Reviews

1. User clicks **"Export All"** (`data-testid="export-dialog-open-btn"`).
2. **Export gate**: the user must have plan `business` or `businessAi` AND either a `yearly` billing period or be a partner account. If the gate fails, the modal **"This is a functionality for annual subscriptions"** opens with the description: _"The Review Export feature is only available for Business and Business AI annual subscriptions."_ and content: _"If you have a Basic plan or a monthly subscription, please consider upgrading to unlock this functionality and other advanced features. Upgrade now to export reviews efficiently!"_ A **"Upgrade to Business AI"** button links to `/account/subscription`.
3. If the gate passes, the **"Export Reviews"** modal opens with description: **"This export includes all reviews in the list, regardless of current filters."**
4. User selects format:
   - **Microsoft Excel (.xlsx)** — "Full report with all details."
   - **CSV Document (.csv)** — "Raw data format for external tools."
5. User clicks **"Download File"**.
6. Browser is directed to `GET /api/reviews/export?format=xlsx|csv&token=<jwt>` — a direct file download. Filters are not applied to the export; it exports the full dataset.

---

## Access Control

| Action | Requirement |
|---|---|
| View reviews list | Authenticated. Reviews are scoped to the user's own properties (`fk_id_user_reviews`). |
| Filter by sentiment / topic / tag | Authenticated + plan `businessAi`. Analytics section is hidden in the UI for other plans; the API accepts these params regardless. |
| Export reviews | Authenticated + plan `business` or `businessAi` + yearly billing period OR partner account. |
| Generate AI response | Authenticated + plan `business` or `businessAi` (`subscribed('business', 'businessAi')` middleware). |
| Save response | Authenticated + plan `business` or `businessAi`. |
| Translate review | Authenticated + plan `business` or `businessAi`. |

---

## API Endpoints

### `GET /api/reviews`

Returns a paginated, filtered list of reviews for the authenticated user.

**Auth:** Bearer JWT (authenticated).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `holdingIds` | array of strings | No | Filter by specific property IDs. Mutually exclusive with `groups` in practice (server applies whichever is provided). |
| `groups` | array of strings | No | Filter to properties that belong to all specified groups (AND logic). Ignored when `holdingIds` is set. |
| `source` | array of strings | No | Filter by channel type. Allowed values: `airbnb`, `booking`, `google`, `expedia`, `tripadvisor`, `trustpilot`, `vrbo`, `direct`, `imported`. `direct` matches `type_source_reviews === 'revyoos'` with no file attachment; `imported` matches reviews with a `fk_id_file_reviews`. |
| `rating` | array of integers (1–5) | No | Filter by star rating. Each value matches reviews where `score_reviews >= N` and `< N+1`. Multiple values are OR-combined. |
| `dateFrom` | string (ISO date) | No | Lower bound on `date` field (inclusive). |
| `dateTo` | string (ISO date) | No | Upper bound on `date` field (inclusive). |
| `answered` | `true` / `false` | No | `true` = reviews with a non-empty `owner_response_reviews` or `copiedAnswer.answer`; `false` = reviews with both empty. Omit for all. |
| `sentiment` | array of strings | No | Allowed values: `Positive`, `Neutral`, `Negative`. Filters via `AnalyticsModel.general_impressions`. |
| `topic` | array of strings | No | Allowed values: `Accuracy`, `Amenities`, `Check-in`, `Cleanliness`, `Communication`, `Location`, `Value for money`. Filters via `AnalyticsModel.tags.category`. |
| `tag` | array of strings | No | Filters via `AnalyticsModel.tags.subCategory`. |
| `page` | integer | No | Default: `1`. |
| `limit` | integer | No | Default: `20`. Max: `100`. |

**Response:**

```json
{
  "success": true,
  "data": {
    "reviews": [
      {
        "_id": "rev123",
        "content_reviews": "Great place, very clean!",
        "score_reviews": 5,
        "date": "2026-04-10T00:00:00.000Z",
        "type_source_reviews": "airbnb",
        "owner_response_reviews": "",
        "lang": "en",
        "icon": "...",
        "sourceTypeTitle": "Airbnb",
        "sourceUrl": "https://...",
        "holding": { "_id": "hold456", "name": "Beach Villa" }
      }
    ],
    "pagination": {
      "currentPage": 1,
      "totalPages": 15,
      "totalItems": 300,
      "itemsPerPage": 20,
      "hasNext": true,
      "hasPrev": false
    }
  }
}
```

Soft-deleted reviews (`status_reviews: -1`) and hidden reviews (`hide: true`) are excluded. Each review item is augmented with `lang` (detected language code), `icon`, `sourceTypeTitle`, and `sourceUrl`.

---

### `GET /api/reviews/export`

Export all reviews as a downloadable file. **Filters are not applied** — the export covers all reviews for the user (or a single property if `holdingId` is provided).

**Auth:** JWT passed as query param `token`.

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `format` | string | No | `csv` or `xlsx`. Default: `csv`. |
| `holdingId` | string | No | Scope export to a single property. |
| `token` | string | Yes | JWT from `localStorage.getItem('s_token')`. |

**Response:** Binary file stream.

```
Content-Disposition: attachment; filename="reviews.csv"
Content-Type: text/csv  (or application/vnd.openxmlformats...)
```

---

### `GET /api/reviews/sources`

Returns the list of source channel types that have at least one review, for use in the Sources filter dropdown.

**Auth:** Bearer JWT (authenticated).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `holdingId` | string | No | Scope to a single property. |

**Response:**

```json
{
  "success": true,
  "data": {
    "sources": ["airbnb", "booking", "direct"]
  }
}
```

---

### `POST /api/reviews/:reviewId/response`

Generate an AI response for a review (see BLOCK 7 — Review Response for full details).

**Auth:** Bearer JWT + plan `business` or `businessAi`.

---

### `PUT /api/reviews/:reviewId/response`

Save a response for a review (see BLOCK 7 — Review Response for full details).

**Auth:** Bearer JWT + plan `business` or `businessAi`.

---

### `POST /api/reviews/:reviewId/translate`

Translate a review's text (see BLOCK 7 — Review Response for full details).

**Auth:** Bearer JWT + plan `business` or `businessAi`.

---

## Components

| File | Route | Purpose |
|---|---|---|
| `nimad_vue3/src/revamp/pages/Reviews.vue` | `/reviews` | Global reviews list — filters toggle, review cards, export button, edit-response modal, pagination. |
| `nimad_vue3/src/revamp/pages/reviews/ReviewsFilters.vue` | (panel, used in Reviews.vue) | Full filter panel: Properties, Groups, Sources, Rating, Date range, Reply status, Sentiments (businessAi), Topics (businessAi), Tags (businessAi). Active-filter chips with per-filter clear buttons. |
| `nimad_vue3/src/revamp/pages/reviews/ExportReviewsDialog.vue` | (modal, used in Reviews.vue and ReviewsTab.vue) | Format picker (xlsx / csv) and download trigger for reviews export. |
| `nimad_vue3/src/revamp/pages/reviews/UpgradeAlertDialog.vue` | (modal, used in Reviews.vue and ReviewsTab.vue) | Upgrade prompt shown when export is attempted without the required plan/period. |
| `nimad_vue3/src/revamp/pages/property/ReviewsTab.vue` | `/properties/:id/reviews` | Per-property reviews tab — same filter/list/export UI scoped to one property. |
| `nimad_vue3/src/revamp/pages/property/PropertyReviewFilter.vue` | (panel, used in ReviewsTab.vue) | Property-scoped filter panel variant. |
