<!-- Sources read:
  nimad_vue3/src/revamp/pages/Dashboard.vue
  nimad_vue3/src/revamp/components/stats/StatsOverview.vue
  nimad_vue3/src/revamp/components/stats/ScoresPerChannel.vue
  nimad_vue3/src/revamp/components/stats/SentimentByRating.vue
  nimad_vue3/src/revamp/components/stats/SentimentPerTopic.vue
  nimad_vue3/src/revamp/components/stats/GuestInsights.vue
  nimad_vue3/src/revamp/components/stats/TrendCard.vue
  nimad_vue3/src/revamp/components/stats/CompanySummary.vue
  nimad_vue3/src/revamp/components/stats/SentimentTooltip.vue
  nimad_vue3/src/revamp/api/stats.js
  api/client/stats/stats.routes.js
  api/client/stats/stats.validation.js
  api/client/stats/stats.service.js
  api/client/users/users.routes.js
  api/client/users/users.service.js (generateCompanySummary)
-->

# Analytics / Stats Overview

## Overview

The Dashboard (`/`) is the main analytics surface. It shows account-wide review stats including overall sentiment, average rating, total review count, per-channel scores, sentiment breakdowns by rating and topic, guest insight tags, trend charts over time, and an AI-generated global summary. Charts that require AI analytics data (`businessAi` plan) are gated: non-authorized users see an upgrade prompt instead. Stats can also be scoped to a single property when the same stat components are embedded in the property detail page.

---

## User Flow

### Dashboard (`/`)

1. User navigates to `/`.
2. A gradient banner at the top shows the company name, average rating, and total review count.
3. If the user's plan is not `businessAi`: an **UpgradeAlert** banner is shown once at the top (feature: `"sentiment"`). Sentiment-gated components still render in a locked/blurred state.
4. If no reviews exist:
   - If the user has properties: **"No data available for analysis. Add booking channels to get started."**
   - If the user has no properties: `QuickStartWizard` is shown.
5. If reviews exist, the following widgets load in order:

**Stats Overview** row (top):
- When `businessAi`: Sentiment donut chart (Positive / Neutral / Negative percentages), **"Average Rating"** card, **"Total Reviews"** card.
- When other plans: only **"Average Rating"** card and **"Total Reviews"** card (2-column layout).
- Sentiment tooltip: _"Based on reviews with text content."_

**Two-column grid:**
- **Scores per Channel** (all plans): Table with columns **Channel**, **Rating**, **Reviews**; plus **Sentiment** column (with sentiment bar) for `businessAi`. Title: **"Scores per Channel"** (businessAi) / **"Rating per Channel"** (other plans). Error state: **"Failed to load channel data."** Empty state: **"No channel data available."**
- **Sentiment and Reviews by Rating** (all plans): Table with columns **Rating**, **Reviews**; plus **Sentiment** column for `businessAi`; always shows **Distribution** progress bar column. Ratings are grouped into buckets: 5, 4–4.9, 3–3.9, 2–2.9, 1–1.9. Title: **"Sentiment and Reviews by Rating"** (businessAi) / **"Rating Distribution"** (other plans). Error state: **"Failed to load rating data."**

**businessAi-only two-column grid:**
- **Sentiment per Topic**: Table with columns **Topic**, **Reviews**, **Sentiment** (bar). Topics: `Amenities`, `Location`, `Cleanliness`, `Accuracy`, `Value for money`, `Check-in`, `Communication`. Error state: **"Failed to load topic data."** Empty state: **"No topic data available."**
- **What Guests Love & What to Fix**: Tag cloud showing positive tags (green) and negative tags (red) from `AnalyticsModel`. Initially shows 5 of each; **"Show more"** / **"Show less"** toggle reveals up to 20. Each tag shows name and count: e.g. `Pool (14)`. Error state: **"Failed to load tag data."** Empty state: **"No tag data available."**

**Global Summary** (businessAi-only): Card titled **"Global Summary"**.
- If a summary has been generated (stored as `user.analitycsSummaryBullet`): shows **"Strengths"** (thumbs-up, green dots) and **"Improvements"** (thumbs-down, red dots) lists as bullet points.
- If no summary yet: text **"Generate a summary of all your reviews across properties."** and a **"Generate Now"** button. On click: calls `POST /api/users/summary`. Skeleton placeholders shown while generating. On failure: `toast.error(...)`.

**Trend Charts** (two-column, all plans):
- **Reviews over Time**: Line chart of review count per period.
- **Ratings over Time**: Line chart of average rating per period.

**Sentiment over Time** (businessAi-only):
- Line chart of positive sentiment percentage per period.

All trend charts have a **Day / Month** group-by toggle. Default: `Month`. Day mode shows the last 30 days; Month mode shows the last 12 months. Switching group-by refetches data. Error state: **"Failed to load chart data."** Empty state: **"No data available for this period."**

---

## Access Control

| Action | Requirement |
|---|---|
| View Dashboard stats (basic) | Authenticated. |
| View sentiment stats (donut, per-channel sentiment bar, by-rating sentiment bar) | Authenticated + plan `businessAi`. |
| View Sentiment per Topic, Guest Insights | Authenticated + plan `businessAi`. |
| View/generate Global Summary | Authenticated + plan `businessAi`. `subscribed('businessAi')` middleware on the generate endpoint. |
| View Sentiment over Time trend chart | Authenticated + plan `businessAi`. |
| All stats endpoints (`/api/stats/*`) | Authenticated (Bearer JWT). |

---

## API Endpoints

All stats endpoints are mounted at `/api/stats` and require `authenticate` middleware.

---

### `GET /api/stats/sentiment`

Returns the count of reviews per sentiment type.

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
    "sentiment": [
      { "sentiment": "Positive", "total": 142 },
      { "sentiment": "Neutral", "total": 38 },
      { "sentiment": "Negative", "total": 20 }
    ]
  }
}
```

---

### `GET /api/stats/channels`

Returns per-channel rating and sentiment statistics.

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
    "channels": [
      {
        "channel": "airbnb",
        "rating": 4.72,
        "reviewsTotal": 84,
        "positive": 78.5,
        "neutral": 14.2,
        "negative": 7.3
      }
    ]
  }
}
```

`positive`, `neutral`, `negative` are percentages (0–100), rounded to 2 decimal places.

---

### `GET /api/stats/rating`

Returns review count and sentiment breakdown per star-rating bucket.

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
    "rating": [
      {
        "score": 5,
        "reviewsTotal": 100,
        "tagsTotal": 230,
        "positive": 82.6,
        "neutral": 11.3,
        "negative": 6.1
      },
      { "score": 4, "reviewsTotal": 45, "tagsTotal": 90, "positive": 60.0, "neutral": 25.0, "negative": 15.0 }
    ]
  }
}
```

Ratings are bucketed server-side: score `5` is exact; `4–4.9` → bucket `4`; `3–3.9` → bucket `3`; `2–2.9` → bucket `2`; `<2` → bucket `1`.

---

### `GET /api/stats/categories`

Returns per-topic sentiment statistics. Topics are fixed: `Amenities`, `Location`, `Cleanliness`, `Accuracy`, `Value for money`, `Check-in`, `Communication`. All 7 topics are always returned (with zeros if no data).

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
    "categories": [
      {
        "category": "Cleanliness",
        "positive": 91.2,
        "neutral": 5.1,
        "negative": 3.7,
        "tagsTotal": 136,
        "reviewsTotal": 88
      }
    ]
  }
}
```

---

### `GET /api/stats/tags`

Returns the top guest insight tags grouped by sentiment (`Positive` / `Negative`).

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
    "tags": [
      {
        "sentiment": "Positive",
        "tags": [
          { "name": "Pool", "total": 14 },
          { "name": "Location", "total": 11 }
        ]
      },
      {
        "sentiment": "Negative",
        "tags": [
          { "name": "Noise", "total": 5 }
        ]
      }
    ]
  }
}
```

---

### `GET /api/stats/trends`

Returns review count, average rating, and sentiment breakdown per time period (day or month).

**Auth:** Bearer JWT (authenticated).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `holdingId` | string | No | Scope to a single property. |
| `groupBy` | string | No | `day` or `month`. Default: `month`. |
| `from` | string | No | Start date (ISO date string, inclusive). |
| `to` | string | No | End date (ISO date string, inclusive). |

**Response:**

```json
{
  "success": true,
  "data": {
    "trends": [
      {
        "year": 2026,
        "month": 4,
        "reviewsTotal": 32,
        "rating": 4.6,
        "positive": 18,
        "neutral": 9,
        "negative": 5
      }
    ]
  }
}
```

When `groupBy=day`, each entry also includes a `day` field. `positive`, `neutral`, `negative` are raw counts (not percentages) in the trends response — the frontend computes the sentiment percentage client-side: `(positive / (positive + neutral + negative)) * 100`.

---

### `POST /api/users/summary`

Generate an AI-written Global Summary of the user's review analytics. Stored on the user record; replaces any existing summary.

**Auth:** Bearer JWT + plan `businessAi` (`subscribed('businessAi')` middleware).

**Request body:** Empty.

**Server behaviour:**
1. Fetches reviews from the last 1 year (monthly plans) or 2 years (annual plans) that have associated `AnalyticsModel` records.
2. Collects all tag text snippets from the analytics records.
3. If no tag text exists: HTTP 400 — `"No review data available to generate a summary"`.
4. Calls OpenAI to generate a structured summary with `strengths` and `improvements` arrays.
5. Saves the result to `user.analitycsSummaryBullet`.

**Response (success):**

```json
{
  "success": true,
  "data": {
    "strengths": [
      { "key": "Pool", "description": "Guests frequently praise the pool area." }
    ],
    "improvements": [
      { "key": "Noise", "description": "Several guests mention noise issues at night." }
    ]
  }
}
```

**Response (no data):** HTTP 400 — `"No review data available to generate a summary"`.

---

## Components

| File | Route | Purpose |
|---|---|---|
| `nimad_vue3/src/revamp/pages/Dashboard.vue` | `/` | Dashboard shell — company banner, plan gate (UpgradeAlert), conditional rendering of all stats widgets based on review/property count. |
| `nimad_vue3/src/revamp/components/stats/StatsOverview.vue` | (used in Dashboard.vue) | Sentiment donut (businessAi only), Average Rating card, Total Reviews card. |
| `nimad_vue3/src/revamp/components/stats/ScoresPerChannel.vue` | (used in Dashboard.vue and property detail) | Per-channel rating table with optional sentiment bar column. |
| `nimad_vue3/src/revamp/components/stats/SentimentByRating.vue` | (used in Dashboard.vue and property detail) | Per-rating-bucket table with distribution bar and optional sentiment bar column. |
| `nimad_vue3/src/revamp/components/stats/SentimentPerTopic.vue` | (used in Dashboard.vue, businessAi only) | Per-topic sentiment breakdown table with 7 fixed categories. |
| `nimad_vue3/src/revamp/components/stats/GuestInsights.vue` | (used in Dashboard.vue, businessAi only) | Positive and negative guest tag clouds with show more/less toggle. |
| `nimad_vue3/src/revamp/components/stats/CompanySummary.vue` | (used in Dashboard.vue, businessAi only) | AI-generated global summary of strengths and improvements; "Generate Now" trigger. |
| `nimad_vue3/src/revamp/components/stats/TrendCard.vue` | (used in Dashboard.vue and property detail) | Line chart for reviews/ratings/sentiment over time; day/month toggle; date-range controlled by group-by. |
| `nimad_vue3/src/revamp/components/stats/SentimentBar.vue` | (shared sub-component) | Horizontal stacked bar showing positive/neutral/negative percentages. |
| `nimad_vue3/src/revamp/components/stats/SentimentTooltip.vue` | (shared sub-component) | Info tooltip with text: _"Based on reviews with text content."_ |
| `nimad_vue3/src/revamp/components/stats/GroupByToggle.vue` | (shared sub-component) | Day / Month toggle for trend charts. |
