<!-- Sources read:
  nimad_vue3/src/comment/CommentApp.vue
  nimad_vue3/src/comment/pages/DirectReviewForm.vue
  nimad_vue3/src/comment/api/index.js
  nimad_vue3/src/comment/helpers/validation.js
  nimad_vue3/src/comment/helpers/constants.js
  nimad_vue3/src/comment/router/index.js
  nimad_vue3/src/comment/locales/directReviewFormLangs.json (English strings)
  api/client/reviews/request/reviewsRequest.routes.js
  api/client/reviews/request/reviewsRequest.validation.js
  api/client/reviews/request/reviewsRequest.service.js
-->

# Direct Review Form

## Overview

The Direct Review Form is a standalone public Vue application (the `comment` app) served at `/comment/:holdingId`. It allows guests to submit a review directly for a specific property without creating an account. The form is fully public (no authentication), supports seven languages auto-detected from the browser, and stores submitted reviews as `type_source_reviews: 'revyoos'` records. If the property ID is not found, the user is redirected to `https://www.revyoos.com/`.

---

## User Flow

### Direct Review Form (`/comment/:holdingId`)

1. User opens the direct review link for a specific property.
2. On load: calls `GET /api/reviews/request/:holdingId` to retrieve the property name.
   - If HTTP 404: redirects to `https://www.revyoos.com/`.
   - If other error: `toast.error('Failed to load property.')`.
3. Page header: **"Review your stay in [Property Name]"**. Description: _"We would love to hear your opinion about your stay. It will help other people decide on renting this property."_
4. Language is auto-detected from `navigator.language`. Available language toggles: **EN**, **FR**, **ES**, **DE**, **NL**, **IT**, **PT**. Default: `en`.
5. Footer: **"Powered by"** + Revyoos logo linking to `https://www.revyoos.com/`.

---

### Form sections

**Section 1 — About you:**

| Field | Label | Type | Required | Validation |
|---|---|---|---|---|
| `name_user` | **Your name** * | Text input | Yes | Min 2 characters. |
| `email_user_review` | **Email Address** * | Text input | Yes | Valid email. |
| `date_stay` | **Date of stay** | Date picker (calendar popover) | No | Must not be in the future. Format: `YYYY-MM-DD`. |

Email hint: _"Your email won't be published. The property manager may use it to respond to your review privately."_

**Section 2 — Rate your experience:**

Six star-rating selectors (1–5 stars each). All six are required — if any is 0, validation fails with **"All ratings are required"**.

| Field key | Label |
|---|---|
| `accuracy` | Accuracy |
| `communication` | Communication |
| `cleanliness` | Cleanliness |
| `location` | Location |
| `checkIn` | Check-in |
| `valueForMoney` | Value for money |

An average score card below the rating grid shows the calculated average (sum ÷ 6, rounded to 2 decimal places), rendered as filled/half/empty stars plus the numeric value. The average is also submitted as `score`.

**Section 3 — Share Your Thoughts:**

| Field | Label | Type | Required | Validation |
|---|---|---|---|---|
| `title_review` | **Title** * | Text input | Yes | Min 3 characters, max 100. Character counter: `N/100`. |
| `content_review` | **Comment** * | Textarea | Yes | Min 20 characters, max 1,000. Counter turns green ≥20, amber >900, red >1000. Below 20: _"At least 20 characters."_ Above 1000: _"Limit reached."_ |
| `privateFeedback` | **Private feedback** | Textarea | No | Optional. Shown in a red-bordered card with a lock icon. Note: _"This comment will only be visible to the host and will not be published."_ |

**Terms checkbox:**

Text: _"I have read and I agree with the "_ **"Terms & Conditions"** _" of Revyoos.com"_. Link to `https://www.revyoos.com/w/terms-of-use/`. Required — must be checked to submit.

**Submit button:** **"Submit Review"** / **"Submitting..."** while in progress.

---

### Submission

On submit:

1. Client validates all fields using Zod schema (`createDirectReviewSchema`) and checks that all 6 star ratings are ≥ 1.
2. If validation fails: inline error messages displayed per field + `toast.error('Please review the highlighted fields.')`.
3. On valid: calls `POST /api/reviews/request/:holdingId`.
4. On success: success modal shown.
   - Modal content: checkmark icon, heading **"Thank you"**, text: _"Your review for **[Property Name]** has been received successfully."_
   - Form is reset to initial empty state.
5. On error: `toast.error('Failed to submit comment.')`.

---

## Access Control

| Action | Requirement |
|---|---|
| Load the direct review form | **No authentication.** Public. |
| Get property name (`GET /api/reviews/request/:holdingId`) | **No authentication.** Public. |
| Submit review (`POST /api/reviews/request/:holdingId`) | **No authentication.** Public. |

---

## API Endpoints

---

### `GET /api/reviews/request/:holdingId`

Get the property name for the given holding ID.

**Auth:** None.

**Path parameters:**

| Parameter | Description |
|---|---|
| `holdingId` | MongoDB `_id` of the property. Min 1 character. |

**Server behaviour:** Looks up the holding by `_id` where `status_holding != -1` (not deleted). Returns 404 if not found.

**Response (success):**

```json
{
  "success": true,
  "data": {
    "holdingId": "64a1b2c3d4e5f6a7b8c9d0e1",
    "name": "Beach Villa"
  }
}
```

**Response (not found):** HTTP 404 — `"Property not found"`.

---

### `POST /api/reviews/request/:holdingId`

Submit a guest review for a property.

**Auth:** None.

**Path parameters:**

| Parameter | Description |
|---|---|
| `holdingId` | MongoDB `_id` of the property. |

**Request body:**

| Field | Type | Required | Validation |
|---|---|---|---|
| `name_user` | string | Yes | Min 1 character. |
| `email_user_review` | string | Yes | Valid email format. |
| `title_review` | string | Yes | Min 1 character. |
| `content_review` | string | Yes | Min 1 character. |
| `score` | number | Yes | Min 1, max 5 (server-side; client sends average of the 6 category scores). |
| `score_detailed` | object | No | `{ accuracy, communication, cleanliness, location, checkIn, valueForMoney }` — each number 0–5. |
| `privateFeedback` | string | No | Optional. Defaults to `""`. |
| `date_stay` | string | Yes | Format `YYYY-MM-DD`. |
| `b_terms` | boolean | Yes | Must be `true`. |
| `lang` | string | No | Detected browser language code (`en`, `fr`, etc.). |

The request body is sanitized by `sanitizeBody()` middleware before validation.

**Server behaviour:**
1. Loads the holding by `holdingId` (must not be soft-deleted).
2. Upserts a `revyoos` source record for the property's owner: `{ fk_id_user_source, fk_id_holding_source, type_source: 'revyoos' }`. Creates one if none exists.
3. Computes a checksum from the review data. If a review with the same checksum already exists: HTTP 409 — `"This review has already been submitted"`.
4. Inserts a new review document with `type_source_reviews: 'revyoos'`, `status_reviews: 1`, `fk_id_file_reviews: null`.

**Response (success):**

```json
{
  "success": true,
  "data": {
    "reviewId": "64b1c2d3e4f5a6b7c8d9e0f1",
    "userId": "64a0b1c2d3e4f5a6b7c8d9e0"
  }
}
```

**Response (duplicate):** HTTP 409 — `"This review has already been submitted"`.

**Response (not found):** HTTP 404 — `"Property not found"`.

---

## Client-side validation rules

Defined in `nimad_vue3/src/comment/helpers/validation.js` (`createDirectReviewSchema`):

| Field | Rule |
|---|---|
| `name_user` | Required. Min 2 characters. Error: _"Name is required."_ / _"Name must be at least 2 characters."_ |
| `email_user_review` | Required. Valid email. Error: _"Email is required"_ / _"Please enter a valid email"_ |
| `date_stay` | Optional. Must not be in the future. Error: _"Date cannot be in the future."_ |
| `score` | Number 0–5. |
| `title_review` | Required. Min 3 characters, max 100. Errors: _"Title is required."_ / _"Title must be at least 3 characters."_ / _"Limit reached."_ |
| `content_review` | Required. Min 20 characters, max 1,000. Errors: _"Comment is required."_ / _"Comment must be at least 20 characters."_ |
| `privateFeedback` | Optional. |
| `b_terms` | Must be `true`. Error: _"You must accept the Terms of Service and Privacy Policy."_ |
| Star ratings (all 6) | All must be ≥ 1. Error: **"All ratings are required"** (shown as `errors.ratings`). |

---

## Architecture note

The `comment` app is a separate Vue app from the main `revamp` app — it has its own `main.js`, router, and build entry point. It shares UI components (`@/components/ui/`) and some revamp components (Checkbox, Modal, Button, ThemeToggle, LogoFull) but has its own API client (plain Axios, no JWT interceptors), helpers, locales, and router. Any unmatched route in the comment app redirects to `https://www.revyoos.com/`.

---

## Components

| File | Route | Purpose |
|---|---|---|
| `nimad_vue3/src/comment/CommentApp.vue` | (app shell) | Root component — `<router-view>`, footer "Powered by Revyoos", ThemeToggle, Toaster. |
| `nimad_vue3/src/comment/pages/DirectReviewForm.vue` | `/comment/:id` | Main review form — property name fetch, language switcher, 6-category star ratings, average score display, all form fields, terms checkbox, success modal. |
| `nimad_vue3/src/comment/api/index.js` | — | API client: `getPropertyInfo(holdingId)`, `submitReview(holdingId, data)`. Base URL from `getApiUrl()`. |
| `nimad_vue3/src/comment/helpers/validation.js` | — | `createDirectReviewSchema` (Zod), `getZodErrors` helper. |
| `nimad_vue3/src/comment/helpers/constants.js` | — | `getApiUrl()`, `getRedirectUrl()`, `EXTERNAL_URLS` (terms, privacy, contact). |
| `nimad_vue3/src/comment/locales/directReviewFormLangs.json` | — | Translations for all UI text in 7 languages (en, fr, es, de, nl, it, pt). |
| `api/client/reviews/request/reviewsRequest.routes.js` | `/api/reviews/request/:holdingId` | Public routes — GET (property info) and POST (submit review). |
| `api/client/reviews/request/reviewsRequest.service.js` | — | `getHoldingForRequest` (lookup + 404), `submitReview` (upsert source, checksum dedup, insert review). |
