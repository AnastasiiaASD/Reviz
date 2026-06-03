<!-- Sources read:
  nimad_vue3/src/revamp/router/index.js (owner-reviews routes use MockupPage — not yet migrated to revamp)
  res/src/components/Owners.vue (legacy shell)
  res/src/components/owners/OwnersList/OwnersList.vue
  res/src/components/owners/OwnersReviewsList/OwnersReviewsList.vue
  res/leaveOwnerReviews/leaveOwnerReviews.vue (public guest/owner form)
  res/ownerWidget/components/OwnerWidgetConfig.vue
  plugins/OwnerCommentPlugin.js (public submit endpoint)
  plugins_api/OwnersApiPlugin.js (GET /lapi/owners)
  plugins_api/OwnersimportApiPlugin.js (GET /lapi/ownersimport — export)
  plugins_api/OwnersreviewsApiPlugin.js (GET/PUT/DELETE /lapi/ownersreviews)
  plugins_api/PropertymanagerratingApiPlugin.js (GET /lapi/propertymanagerrating)
  plugins_api/OwnerWidgetApiPlugin.js (GET/PUT /lapi/ownerWidget)
  models/OwnersReviewsM.js
  res/src/helpers/constants.js (OWNER_REVIEW_RATING_CATEGORIES, UPGRADE_BUSINESS_ROUTES_MAP)
  res/src/store/modules/owners.js
  res/src/api_functions.js
-->

# Owner Reviews

## Overview

Owner Reviews is a feature for property managers who work with property owners. It allows sending a unique per-property survey link to a property owner so they can rate the property manager's performance across five criteria. Received feedback is listed in the **Owner Feedbacks** dashboard; an aggregate score is shown in a summary card. A separate embeddable **Owner Widget** can be installed on external websites to display this aggregate score publicly. The feature is gated to the `business` and `businessAi` plans.

> **Note:** All four Owner Reviews routes (`/owner-reviews`, `/owner-reviews/feedbacks`, `/owner-reviews/request`, `/owner-reviews/widget`) use `MockupPage` in the revamp router — this feature has **not yet been migrated** to the revamp frontend. The documentation below describes the legacy implementation (`res/` directory).

---

## User Flow

### Request Forms (`/owners/list`)

1. User navigates to the **Request Forms** page.
2. Page title: **"Request Forms"**.
3. Description: _"To request an owner's review, search for one of their properties and copy the auto-generated link. This link is unique for each property. Send it to the owner so they can rate your performance. When you receive the rating, the name the owner will be associated with their property. You can change the owner's name at any time."_
4. A **"Search property"** text input with a search button filters the list. Triggers `GET /lapi/owners?holdingSearch=...`.
5. Two export buttons: **"Export CSV"** and **"Export XLS"** — call `GET /lapi/ownersimport?type=csv` or `type=excel`. Files are downloaded as `all_owners_review_<YYYY_MM_DD_HH_mm>.xlsx` or `.csv`.
6. An **OwnersListTable** displays properties with their auto-generated owner review links.
7. List loads on mount and on route query changes; infinite-scroll pagination (loads next page when scrolling to bottom).

---

### Owner Feedbacks (`/owners/reviews`)

1. User navigates to the **Owner Feedbacks** page.
2. Page title: **"Owner Feedbacks"**.
3. A **PropertyManagerRating** summary card at the top shows the aggregate score from all received owner reviews. Data from `GET /lapi/propertymanagerrating`.
4. A **ReviewsListTable** lists all received reviews. Delete is available (`isDeletingAvailable`). Soft-delete: `DELETE /lapi/ownersreviews?id=:reviewId`.
5. Each review item can have an owner's reply added via `PUT /lapi/ownersreviews?id=:reviewId` with `{ answer: string }`.
6. List loads on mount; infinite-scroll pagination (page incremented on scroll bottom).

---

### Owner Review Form (public, served at the hash URL)

The guest-facing survey form. No authentication required. Language is auto-detected from `navigator.language`; flags for available languages are shown in the header so the owner can switch manually.

Supported languages: `uk` (English), `fr`, `es`, `de`, `nl`, `it`, `pt`. Default: `uk`.

On load: calls backend to load property manager info using a `hash` param (currently the `holdingId` — the `validateHoldingHash` function contains a TODO noting hash functionality is not yet implemented). If not found: error message shown.

Header shows: manager name, manager website link.

Form sections:

**Performance criteria** (five range sliders, each 0–10):
- **Communication**
- **Transparency**
- **Revenues**
- **Management Cost**
- **Maintenance/Cleanliness**

**Overall rating** (one additional range slider, 0–10):
- Label (localized). Scale labeled `"Very Unlikely"` → `"Very Likely"` (i.e., likelihood-to-recommend / NPS style).

**Comments** — textarea (optional).

**Private Feedback** — textarea with red background (optional). Labeled with lock icon and locale-specific note. _"Not shown publicly."_

**Owner Name** — text input (required).

**Terms checkbox** — required. Links to `https://www.revyoos.com/terms-of-use`.

On submit:
1. Validates client-side (all sliders default to a value; `name` is `required` HTML attribute; terms checkbox is `required`).
2. Calls backend submit action.
3. On success: locale-specific success message shown inline:
   - `uk`: **"Thank you! Your feedback has been sent"**
   - `fr`: **"Merci ! Votre commentaire a été envoyé."**
   - `es`: **"¡Gracias! Se ha enviado tu comentario"**
   - `de`: **"Danke! Ihr Feedback wurde gesendet."**
   - `nl`: **"Bedankt! Uw feedback is verzonden."**
   - `it`: **"Grazie! Il tuo feedback è stato inviato."**
   - `pt`: **"Obrigado! Seu feedback foi enviado."**
4. On error: error message from `response.data.message` shown in red.

Footer: **"Quality Survey powered by Revyoos"** link to `https://www.revyoos.com`.

---

### Owner Reviews Widget Setup (`/owners/widget`)

1. User navigates to **"Owner Reviews Widget Setup"**.
2. Page title: **"Owner Reviews Widget Setup"**.
3. Description: _"Here you can configure the alignment of the widget. When finished, save your changes and select the generated code to implement it on your website."_
4. `OwnersReviewSetting` component — configure widget template and position. Settings loaded from `GET /lapi/ownerWidget?settings=1`.
5. `OwnersReviewsCode` component — displays the generated embed code.
6. Saving settings calls `PUT /lapi/ownerWidget` with `{ settings: {...} }`. On success: `swal` notification with `response.data.message`.
7. The widget embed token is a base64-encoded JSON: `{ userId: "<userId>" }`.

---

## Access Control

| Action | Requirement |
|---|---|
| View Request Forms (`/owners/list`) | Authenticated + plan `business` or `businessAi`. Non-qualifying plans see an upgrade page (`/owners/list/upgrade`). |
| View Owner Feedbacks (`/owners/reviews`) | Authenticated + plan `business` or `businessAi`. Non-qualifying plans see upgrade page (`/owners/reviews/upgrade`). |
| View Owner Widget Setup (`/owners/widget`) | Authenticated + plan `business` or `businessAi`. Non-qualifying plans see upgrade page (`/owners/widget/upgrade`). |
| Export owner review links | Authenticated (legacy token). |
| Submit owner review form (public) | **No authentication.** Public endpoint. |
| Get property manager info for form (public) | **No authentication.** Public endpoint. |
| Serve Owner Widget embed data | **No authentication.** Public endpoint. |

---

## API Endpoints

All authenticated endpoints use the legacy `/lapi/` prefix with a `token` query parameter.

---

### `GET /lapi/owners`

Get a paginated list of properties with their owner review links.

**Auth:** Legacy token (authenticated).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `token` | string | Yes | User JWT token. |
| `holdingSearch` | string | No | Case-insensitive substring search on `name_holding`. |
| `page` | integer | No | Page number. Default: `1`. |
| `limit` | integer | No | Items per page. Default: `20`. |

**Response:**

```json
{
  "success": true,
  "message": "Done!",
  "code": 200,
  "payload": [ /* array of holding objects with owner review link data */ ]
}
```

---

### `GET /lapi/ownersimport`

Export all property owner review links as a downloadable file.

**Auth:** Legacy token (authenticated).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `token` | string | Yes | User JWT token. |
| `type` | string | No | `csv` or `excel`. |

**Response:** Binary file content (base64 string in `payload`). Saved as `all_owners_review_<timestamp>.xlsx` or `.csv`.

---

### `GET /lapi/ownersreviews`

Get a paginated list of received owner reviews for the authenticated user.

**Auth:** Legacy token (authenticated). Supports `revyoosPropertyManagerWidget` token for public widget access.

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `token` | string | Yes | User JWT token. |
| `page` | integer | No | Page number. Default: `1`. |
| `limit` | integer | No | Items per page. Default: `10`. |
| `sortBy` | string | No | Field to sort by. Default: `createdAt`. |
| `sortOrder` | integer | No | Sort direction: `-1` (desc) or `1` (asc). Default: `-1`. |
| `revyoosPropertyManagerWidget` | string | No | Base64-encoded JSON `{ userId }` for public widget access (bypasses token auth). |

**Response:**

```json
{
  "success": true,
  "message": "Done!",
  "code": 200,
  "payload": [
    {
      "_id": "rev123",
      "userId": "...",
      "holdingId": "...",
      "holdingName": "Beach Villa",
      "name": "John Owner",
      "comments": "Great management team.",
      "communication": 9,
      "transparency": 8,
      "revenues": 7,
      "managementCost": 8,
      "maintenanceOrCleanliness": 9,
      "rating": 10,
      "answer": "",
      "status": 0,
      "createdAt": "2026-04-01T10:00:00.000Z"
    }
  ]
}
```

---

### `PUT /lapi/ownersreviews`

Save the property manager's reply to an owner review.

**Auth:** Legacy token (authenticated).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `token` | string | Yes | User JWT token. |
| `id` | string | Yes | The owner review's `_id`. |

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `answer` | string | Yes | Reply text from the property manager. |

**Response:**

```json
{
  "success": true,
  "message": "Owner Review Answer Successfully Updated!",
  "code": 200,
  "payload": { /* MongoDB updateOne result */ }
}
```

---

### `DELETE /lapi/ownersreviews`

Soft-delete an owner review (sets `status: -1`).

**Auth:** Legacy token (authenticated).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `token` | string | Yes | User JWT token. |
| `id` | string | Yes | The owner review's `_id`. |

**Response:**

```json
{
  "success": true,
  "message": "Owner Review Successfully Deleted!",
  "code": 200,
  "payload": { /* MongoDB updateOne result */ }
}
```

---

### `GET /lapi/propertymanagerrating`

Get the aggregate owner rating totals for the authenticated user.

**Auth:** Legacy token (authenticated). Also supports `revyoosPropertyManagerWidget` for public widget access.

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `token` | string | Yes | User JWT token. |
| `revyoosPropertyManagerWidget` | string | No | Base64 `{ userId }` for widget access. |

**Response:**

```json
{
  "success": true,
  "message": "Done!",
  "code": 200,
  "payload": {
    "rating": 45,
    "communication": 38,
    "transparency": 32,
    "revenues": 28,
    "managementCost": 30,
    "maintenanceOrCleanliness": 35,
    "count": 5
  }
}
```

All fields are raw sums. Frontend divides each by `count` to compute the average per criterion.

---

### `GET /lapi/ownerWidget`

Get the Owner Widget settings.

**Auth:** Legacy token (authenticated).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `token` | string | Yes | User JWT token. |
| `settings` | integer | No | Pass `1` to retrieve current settings. |
| `revyoosPropertyManagerWidget` | string | No | Base64 `{ userId }` to retrieve public widget data. |

**Response:**

```json
{
  "success": true,
  "message": "Done",
  "code": 200,
  "payload": {
    "settings": {
      "widgetType": "first",
      "position": "bottom-left",
      "name": "Company Name",
      "email": "user@example.com"
    },
    "isBusinessPlan": true,
    "notActive": false
  }
}
```

Widget defaults: `widgetType: "first"`, `position: "bottom-left"`, `name: "Your Company/Property Name"`.

---

### `PUT /lapi/ownerWidget`

Save Owner Widget settings.

**Auth:** Legacy token (authenticated).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `token` | string | Yes | User JWT token. |

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `settings` | object | Yes | Widget settings object. `revyoosHost` is stripped before saving. |

---

### Public endpoints (via `OwnerCommentPlugin`)

**Get property manager info** (called from the public form on load):
- Accepts `hash` (currently the holding `_id`).
- Returns: `{ name, email, website, holdingName }` from the user and holding records.
- On invalid hash or holding not found: error `"Invalid link address"`.

**Submit owner review** (called from the public form on submit):
- Accepts `hash` + `review` object: `{ name, comments, privateFeedback, communication, transparency, revenues, managementCost, maintenanceOrCleanliness, rating, answer: '' }`.
- Inserts into `ownersReviews` collection.
- On success: `"Thank you! Your feedback has been sent."`.

---

## Data Model — `OwnersReviewsM` (collection: `ownersReviews`)

| Field | Type | Required | Constraints | Description |
|---|---|---|---|---|
| `userId` | ObjectId | Yes | ref: UsersM | Property manager's user ID. |
| `holdingId` | ObjectId | Yes | ref: HoldingsM | Property this review is about. |
| `name` | string | Yes | Trimmed | Owner's name. |
| `comments` | string | No | Trimmed | Public comment. |
| `privateFeedback` | string | No | Trimmed | Private feedback (not shown publicly). |
| `communication` | number | Yes | 0–10 | Criteria score. |
| `transparency` | number | Yes | 0–10 | Criteria score. |
| `revenues` | number | Yes | 0–10 | Criteria score. |
| `managementCost` | number | Yes | 0–10 | Criteria score. |
| `maintenanceOrCleanliness` | number | Yes | 0–10 | Criteria score. |
| `rating` | number | Yes | 0–10 | Overall recommendation score. |
| `status` | number | Yes | `0` (active), `-1` (deleted) | Soft-delete status. |
| `answer` | string | No | Trimmed | Property manager's reply. |

---

## Components

| File | Route | Purpose |
|---|---|---|
| `res/src/components/owners/OwnersList/OwnersList.vue` | `/owners/list` | Request Forms page — property list with owner review links, search, export CSV/XLS, infinite scroll. |
| `res/src/components/owners/OwnersReviewsList/OwnersReviewsList.vue` | `/owners/reviews` | Owner Feedbacks page — received reviews table with delete, aggregate rating card, reply capability. |
| `res/leaveOwnerReviews/leaveOwnerReviews.vue` | (public hash URL) | Public multi-language owner review submission form — 5 criteria sliders, overall rating, comments, private feedback, terms. |
| `res/ownerWidget/components/OwnerWidgetConfig.vue` | `/owners/widget` | Owner Widget Setup page — widget position/template configurator, embed code display, save via PUT /lapi/ownerWidget. |
| `res/ownerWidget/components/OwnerWidget.vue` | (embed) | Public-facing Owner Widget rendered on external websites, displaying aggregate owner rating. |
