<!-- Sources read:
  nimad_vue3/src/revamp/components/ReviewCard.vue
  nimad_vue3/src/revamp/components/EditResponseModal.vue
  nimad_vue3/src/revamp/helpers/constants.js (AI_TONES, AI_NUANCES)
  api/client/reviews/reviews.routes.js
  api/client/reviews/reviews.validation.js (generateResponseSchema, translateReviewSchema, saveResponseSchema)
  api/client/reviews/reviews.service.js (generateResponse, translateReview, saveResponse)
  api/client/reviews/reviews.controller.js
-->

# Review Response

## Overview

Review Response allows users to generate AI-written replies to reviews, translate review text into their own language, and save a draft response (called a "copied answer") against any review. The feature is gated to `business` and `businessAi` plan holders. Responses are generated via OpenAI; up to 5 responses can be generated per review. Saved responses are stored as drafts on the review record — they are not posted back to the source channel automatically.

---

## User Flow

### ReviewCard — inline actions

Each `ReviewCard` displayed on the Reviews list (`/reviews`) and per-property Reviews tab shows these response-related elements:

**Translate button** (shown when the review language differs from the user's language and the review has content):
- Clicking fetches a translation via `POST /api/reviews/:reviewId/translate`.
- While fetching, a spinning icon is shown.
- Once translated, the card body switches to show the user's language version. A **"View Original ([language])"** label replaces the translate icon to toggle back.
- On failure: `toast.error('Failed to translate review')`.

**Generate Response button** (shown only when plan is `business` or `businessAi`, and no draft/published response exists yet):
- Label: **"Generate Response"** (with magic wand icon).
- On click, reads AI settings from `userStore.user.chatSettings`. If `chatSettings` is absent: `toast.error('Please configure your AI response settings in Preferences first.')` and stops.
- While generating, the button area is replaced by a **"Generating response..."** spinner.
- The first generated response is immediately saved as a draft (`applyResponse` is called automatically).
- On failure: `toast.error('Failed to generate response.')`.

**Host Response area** (expandable, shown after a response exists):
- If `owner_response_reviews` is non-empty: collapsible section labeled **"Host Response"** (grey icon).
- If `copiedAnswer` is set but `owner_response_reviews` is empty: collapsible section labeled **"Host Response (draft)"** (yellow icon). Expanded automatically when first set.

**Draft response actions** (within the expanded draft area):
- **"Copy & Go to [channel]"** button: copies the draft text to clipboard and opens the source listing URL in a new tab. On copy success: `toast.success('Response copied to clipboard')`.
- **"Edit"** button: opens the `EditResponseModal`.
- **Copy icon button**: copies the draft text to clipboard.

### EditResponseModal

Opened from the **"Edit"** button on a ReviewCard draft, or via the reviews list edit flow.

1. Modal title: **"Edit Response"**.
2. A collapsible review header shows a 50-character snippet, reviewer name, and star rating. Clicking it toggles the full review text.
3. If the review language differs from the user's language, the modal auto-translates the review on open (via `POST /api/reviews/:reviewId/translate`). During translation: **"Translating..."** with spinner. The translated version is shown with a label indicating the user's language; the original is shown below it with a **"(Guest language)"** label.

**Custom Settings section** — label: **"Custom Settings"**. Subtitle: **"Changes will apply to the next generated response"**.

| Control | Type | Options |
|---|---|---|
| **Tone** | Dropdown | `Formal`, `Informal` |
| **Nuance** | Dropdown | `Neutral`, `Empathetic`, `Apologetic`, `Inviting`, `Solution Oriented`, `Reassuring`, `Enthusiastic` |
| **Guest Name** | Toggle switch | Include reviewer's name in the response |
| **Property Name** | Toggle switch | Mention property name in the response |
| **Signature** | Toggle switch + textarea | When enabled: shows a textarea (`placeholder="Your signature..."`). Text appended to the response. |

Settings default to the user's `chatSettings` preferences when no previous responses exist. When re-opening a modal with existing responses, settings are loaded from the currently active response tab.

4. **"Generate"** button (with `+` icon) — disabled while generating or when the 5-response limit is reached. Counter shows: **"N response[s] left"** (max is 5).
5. On generate: calls `POST /api/reviews/:reviewId/response`. On success: a new response tab appears. Active tab switches to the newest response. On failure: `toast.error('Failed to generate response')`.
6. Generated responses appear as tabs labeled **"Response 1"**, **"Response 2"**, etc.

**When languages differ (translation mode):**
- The user-language text is shown in an editable textarea labeled `"[UserLanguage] (Your language)"` with a **"Copy"** button.
- The guest-language text is shown in a **read-only** textarea labeled `"[GuestLanguage] (Guest language)"` with a **"Copy"** button.
- If the user edits the user-language text, an **"Apply"** button appears. Clicking it translates the edited text into the guest language via `POST /api/utils/translate` and updates the guest-language textarea.

**When languages match:**
- A single editable textarea is shown for the response text.

7. **"Reset to Original"** button (shown when any response text has been edited relative to the generated version).
8. Footer: **"Cancel"** button closes the modal. **"Use Selected (Response N)"** button saves the active tab's response via `PUT /api/reviews/:reviewId/response`. On success: `toast.success('Response saved')` and modal closes. On failure: `toast.error('Failed to save response')`.

### Response States on ReviewCard

| Condition | Display |
|---|---|
| `copiedAnswer` set, `owner_response_reviews` empty | **"Host Response (draft)"** (yellow icon) — collapsed; auto-expands when first set. |
| `owner_response_reviews` non-empty | **"Host Response"** (grey icon) — collapsed. |
| Generating in progress | **"Generating response..."** spinner row. |
| No response, plan `business`/`businessAi` | **"Generate Response"** button. |
| No response, plan below business | No button shown. |

---

## Access Control

| Action | Requirement |
|---|---|
| Generate AI response | Authenticated + plan `business` or `businessAi` (`subscribed('business', 'businessAi')` middleware). |
| Translate a review | Authenticated + plan `business` or `businessAi`. |
| Save a draft response | Authenticated + plan `business` or `businessAi`. |
| View draft / published response | Authenticated (no plan check on read). |

---

## API Endpoints

---

### `POST /api/reviews/:reviewId/response`

Generate an AI-written response for a review using OpenAI.

**Auth:** Bearer JWT + plan `business` or `businessAi`.

**Path parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `reviewId` | string | Yes | The review's `_id`. Validated by `validateReview` middleware (checks ownership). |

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `tone` | string | No | `formal` or `informal`. Default: `formal`. |
| `nuance` | string | No | `neutral`, `empathetic`, `apologetic`, `inviting`, `solutionOriented`, `reassuring`, `enthusiastic`. Default: `neutral`. |
| `language` | string | Yes | User's language name (e.g. `"English (USA)"`). Response is written in `reviewLanguage` and optionally translated into this. |
| `reviewLanguage` | string | Yes | Language of the original review (e.g. `"Italian"`). The AI writes the response in this language. |
| `isUsingGuestName` | boolean | No | Include reviewer's name in the response. Default: `false`. |
| `isUsingPropertyName` | boolean | No | Include property name in the response. Default: `false`. |
| `isNeedToTranslate` | boolean | No | If `true`, the response is also translated into `language` (stored as `translate`). Default: `false`. |
| `signature` | string | No | Text appended to the response. |

**Server behaviour:**
1. If `review.generatedAnswers.length >= 5`: HTTP 429 — `"Generate response functionality is limited to 5"`.
2. Builds an OpenAI prompt from the review content, tone, nuance, guest name, property name, rating, and signature.
3. Generates the `answer` in `reviewLanguage`. If `isNeedToTranslate` is `true`, also generates a `translate` version in `language`.
4. Appends the new response object to `review.generatedAnswers` (array capped at 5).
5. Updates `generatingSettings` on the review.

**Response (success):**

```json
{
  "success": true,
  "data": {
    "review": {
      "_id": "rev123",
      "generatedAnswers": [
        {
          "answer": "Thank you for your stay...",
          "translate": "Grazie per il tuo soggiorno...",
          "tone": "formal",
          "nuance": "neutral",
          "isUsingGuestName": true,
          "isUsingPropertyName": false,
          "isNeedToTranslate": true,
          "signature": "",
          "created": "2026-05-25T10:00:00.000Z"
        }
      ]
    }
  }
}
```

**Response (limit reached):** HTTP 429.

```json
{
  "success": false,
  "errors": [{ "message": "Generate response functionality is limited to 5" }]
}
```

---

### `PUT /api/reviews/:reviewId/response`

Save a selected (and optionally edited) response as the review's draft (`copiedAnswer`).

**Auth:** Bearer JWT + plan `business` or `businessAi`.

**Path parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `reviewId` | string | Yes | The review's `_id`. |

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `answer` | string | Yes | The response text in the guest's language. Min 1 character. |
| `translate` | string | Yes | The response text in the user's language (same as `answer` when languages match). Min 1 character. |

**Server behaviour:** Updates `review.copiedAnswer` with `{ answer, translate }`.

**Response (success):**

```json
{
  "success": true,
  "data": {
    "payload": [{ "...updated review fields..." }]
  }
}
```

---

### `POST /api/reviews/:reviewId/translate`

Translate a review's content (and optionally its title, owner response, and analytics tags) into the user's language.

**Auth:** Bearer JWT + plan `business` or `businessAi`.

**Path parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `reviewId` | string | Yes | The review's `_id`. |

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `language` | string | Yes | Target language name (e.g. `"English (USA)"`). Min 1 character. |

**Server behaviour:**
1. Checks `review.translation[language]` for cached translations. Fetches from OpenAI only for uncached fields.
2. If the review has `AnalyticsModel` tags: translates review text and tags together in one `translateJson` call. Otherwise translates review text alone.
3. Translates `owner_response_reviews` and `title_reviews` if present and uncached.
4. Persists translations to `review.translation[language]` and `analytics.translation[language]`.
5. Returns the updated review object (with analytics attached).

**Response (success):**

```json
{
  "success": true,
  "data": {
    "review": {
      "_id": "rev123",
      "translation": {
        "English (USA)": {
          "review": "Great place, very clean!",
          "title": "Amazing stay",
          "response": "Thank you for your kind words."
        }
      }
    }
  }
}
```

---

## Components

| File | Route | Purpose |
|---|---|---|
| `nimad_vue3/src/revamp/components/ReviewCard.vue` | (used in Reviews.vue and ReviewsTab.vue) | Review card — displays review content, sentiment tags, translate toggle, inline "Generate Response" button, host response/draft section, copy & go to OTA action. |
| `nimad_vue3/src/revamp/components/EditResponseModal.vue` | (modal, used in Reviews.vue and ReviewsTab.vue) | Full response editor — review preview with optional translation, Custom Settings (tone, nuance, guest name, property name, signature), "Generate" button with response tab counter, multi-tab response display, edit and re-translate support, "Use Selected" save action. |
