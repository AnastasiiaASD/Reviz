# Sentiment Analysis

## Overview

Sentiment Analysis automatically classifies review text as **Positive**, **Neutral**, or **Negative** and surfaces that data across multiple views: an overall dashboard, per-property stats, breakdowns by topic, channel, and star rating, and inline highlighting on individual review cards. Users can also filter their review list by sentiment.

---

## Sentiment Values

| Value | Description |
|-------|-------------|
| `Positive` | Review text expresses satisfaction |
| `Neutral` | Review text is neither clearly positive nor negative |
| `Negative` | Review text expresses dissatisfaction |

---

## Where Sentiment Appears

### Stats Overview
A donut chart showing the overall positive / neutral / negative split across all reviews (or a single property when filtered). The positive percentage is displayed in the center of the donut.

### Sentiment by Topic
A table breaking down sentiment across review categories:

| Topic | Examples |
|-------|---------|
| Amenities | Facilities, equipment |
| Location | Area, surroundings |
| Cleanliness | Hygiene, tidiness |
| Communication | Host responsiveness |
| Check-in | Arrival process |
| Value | Price-to-quality ratio |

Each row shows the review count and a horizontal sentiment bar (positive / neutral / negative segments).

### Sentiment by Channel
Per-booking-channel table showing average rating, review count, and sentiment bar for each source (Airbnb, Booking, TripAdvisor, etc.).

### Sentiment by Rating
Table mapping each star rating (1–5) to its sentiment distribution, showing how review text sentiment correlates with the numeric score.

### Sentiment Trends
A time-series line chart tracking the positive sentiment percentage over time. Configurable by grouping period (day or month) and date range.

### Guest Insights (Tags)
Top tags extracted from reviews, split into two lists — positive tags and negative tags — showing the most frequently mentioned topics. Expandable from 5 to 20 tags.

### Review Cards
Each review card has a left border color coded by sentiment and highlights sentiment tags inline within the review text on hover.

### Review Filters
The review list can be filtered by one or more sentiment values. Available under the Analytics section (requires Business AI plan).

---

## Access Control

| Feature | Requirement |
|---------|-------------|
| Stats Overview (sentiment donut) | Authenticated |
| Sentiment by Topic / Channel / Rating / Trends | Authenticated |
| Sentiment filter on reviews list | Business AI plan (`businessAi`) |
| Guest Insights (tags) | Authenticated |

---

## API Endpoints

All endpoints require `Bearer <token>` authentication. All `holdingId` parameters are optional — omitting them returns stats across all of the user's properties.

---

### `GET /api/stats/sentiment`

Overall sentiment distribution across all reviews.

**Query parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `holdingId` | string | No | Filter to a single property |

**Response:**
```json
{
  "positive": 72.5,
  "neutral": 15.0,
  "negative": 12.5
}
```

---

### `GET /api/stats/categories`

Sentiment breakdown per review topic/category.

**Query parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `holdingId` | string | No | Filter to a single property |

**Response:**
```json
[
  {
    "category": "Cleanliness",
    "total": 120,
    "positive": 85,
    "neutral": 20,
    "negative": 15
  }
]
```

---

### `GET /api/stats/channels`

Sentiment and rating breakdown per booking channel.

**Query parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `holdingId` | string | No | Filter to a single property |

**Response:**
```json
[
  {
    "channel": "airbnb",
    "totalReviews": 61,
    "averageRating": 4.68,
    "positive": 80.3,
    "neutral": 11.5,
    "negative": 8.2
  }
]
```

---

### `GET /api/stats/rating`

Sentiment distribution per star rating score (1–5).

**Query parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `holdingId` | string | No | Filter to a single property |

**Response:**
```json
[
  {
    "score": 5,
    "total": 150,
    "positive": 91.3,
    "neutral": 6.0,
    "negative": 2.7
  }
]
```

---

### `GET /api/stats/tags`

Top tags extracted from reviews, grouped by sentiment.

**Query parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `holdingId` | string | No | Filter to a single property |

**Response:**
```json
{
  "positive": [
    { "tag": "clean", "count": 45 },
    { "tag": "great location", "count": 38 }
  ],
  "negative": [
    { "tag": "noisy", "count": 12 },
    { "tag": "small bathroom", "count": 9 }
  ]
}
```

---

### `GET /api/stats/trends`

Time-series data for reviews, average rating, and positive sentiment percentage.

**Query parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `holdingId` | string | — | Filter to a single property |
| `groupBy` | `day` \| `month` | `month` | Time grouping |
| `from` | string (date) | — | Start date filter |
| `to` | string (date) | — | End date filter |

**Response:**
```json
[
  {
    "date": "2024-01",
    "totalReviews": 23,
    "averageRating": 4.6,
    "sentimentPositive": 78.3
  }
]
```

---

## Components

| Component | Purpose |
|-----------|---------|
| `SentimentDonut.vue` | SVG donut chart — positive % in centre |
| `SentimentBar.vue` | Horizontal bar — positive / neutral / negative segments |
| `SentimentTag.vue` | Inline badge with sentiment colour |
| `SentimentTooltip.vue` | Info tooltip: "Based on reviews with text content" |
| `StatsOverview.vue` | Card grid — donut, average rating, total reviews |
| `SentimentPerTopic.vue` | Sentiment breakdown table by topic |
| `ScoresPerChannel.vue` | Rating + sentiment table by channel |
| `SentimentByRating.vue` | Sentiment table per star score |
| `TrendCard.vue` | Line chart for reviews / rating / sentiment over time |
| `GuestInsights.vue` | Top positive and negative tags |
| `ReviewCard.vue` | Review card with sentiment border and inline tag highlights |
| `ReviewsFilters.vue` | Filter panel including sentiment checkboxes |
