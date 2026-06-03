# AI Features

## Overview

Revyoos uses OpenAI across four distinct features: automated review response generation, review and text translation, sentiment and topic analysis, and AI-generated property/company summaries. All AI features are powered by the OpenAI API and gated behind subscription plan requirements.

---

## Features at a Glance

| Feature | Plan Required | OpenAI Model |
|---------|--------------|--------------|
| AI Response Generation | Business / Business AI | `gpt-3.5-turbo` |
| Review Translation | Business / Business AI | `gpt-3.5-turbo` |
| Text Translation (general) | Any active subscription | `gpt-4o` |
| Sentiment & Topic Analysis | Business AI | `gpt-4o` |
| Property Quarterly Summaries | Business AI | `gpt-5-nano` |
| Company Summary | Business AI | `gpt-4o` |

---

## 1. AI Response Generation

Generates a ready-to-publish reply to a guest review based on the review content and configurable tone settings.

### Configuration Options

Users configure global defaults via **Settings → AI Response Settings**. These can be overridden per-review.

| Option | Values | Description |
|--------|--------|-------------|
| `tone` | `formal`, `informal` | Overall register of the response |
| `nuance` | `neutral`, `empathetic`, `apologetic`, `inviting`, `solutionOriented`, `reassuring`, `enthusiastic` | Emotional style of the response |
| `language` | Any language code | Language to translate the response into |
| `isUsingGuestName` | boolean | Include the guest's name in the response |
| `isUsingPropertyName` | boolean | Include the property name in the response |
| `signature` | string | Custom sign-off appended to the response |
| `isNeedToTranslate` | boolean | Translate the response to `language` after generation |

### How It Works

1. User opens a review and clicks **Generate response**.
2. The app sends the review text, language, tone, nuance, and content flags to the API.
3. OpenAI generates a response (max 60 words, one paragraph, no line breaks).
4. Up to 5 variations are stored per review.
5. If `isNeedToTranslate` is true, the generated response is also translated into the user's preferred language.
6. The user selects a response and saves it via `PUT /api/reviews/:reviewId/response`.

### Prompt Template

```
Write a reply to this review "{review}".
Write the answer in this language "{reviewLanguage}".
Act as a property manager.
Write everything in one paragraph. Do not use line breaks.
Thank the guest only at the end.
Keep the response within 60 words.
Do not start with "Dear" and do not finish with "Best regards" or any other greeting.
```

**Nuance additions (appended dynamically):**

| Nuance | Prompt addition |
|--------|----------------|
| `empathetic` | Show understanding of the reviewer's feelings and emotions. |
| `apologetic` | Acknowledge mistakes and express regret for any inconvenience. |
| `inviting` | Encourage further communication or dialogue with the reviewer. |
| `solutionOriented` | Focus on presenting solutions to the issues raised in the review. |
| `reassuring` | Offer assurance that concerns will be addressed. |
| `enthusiastic` | Convey excitement and energy in your response. |

### API Endpoints

#### `POST /api/reviews/:reviewId/response`

Generate an AI response for a review.

**Auth:** `Bearer <token>`  
**Plan:** Business or Business AI

**Request body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `tone` | `formal` \| `informal` | Yes | Response tone |
| `nuance` | string | No | Emotional nuance (defaults to `neutral`) |
| `reviewLanguage` | string | Yes | Language of the original review |
| `language` | string | Yes | Language to write/translate the response in |
| `reviewRating` | number | No | Star rating of the review |
| `isUsingGuestName` | boolean | No | Include guest name (default `false`) |
| `isUsingPropertyName` | boolean | No | Include property name (default `false`) |
| `isNeedToTranslate` | boolean | No | Translate response after generation (default `false`) |
| `signature` | string | No | Custom sign-off text |

**Response:**
```json
{
  "answer": "Thank you for staying with us...",
  "translate": "Gracias por alojarse con nosotros..."
}
```

#### `PUT /api/reviews/:reviewId/response`

Save the user-selected AI response to publish.

**Auth:** `Bearer <token>`  
**Plan:** Business or Business AI

**Request body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `answer` | string (min 1) | Yes | The response text to save |
| `translate` | string (min 1) | Yes | Translated version of the response |

---

## 2. Review Translation

Translates the full text of a review into a user-specified language.

### How It Works

1. User clicks **Translate** on a review.
2. The app sends the review ID and target language to the API.
3. OpenAI translates the review content.
4. The translated text is cached on the review document per language so the same translation is not re-generated on subsequent requests.

### API Endpoint

#### `POST /api/reviews/:reviewId/translate`

**Auth:** `Bearer <token>`  
**Plan:** Business or Business AI

**Request body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `language` | string (min 1) | Yes | Target language for translation |

**Response:**
```json
{
  "translation": "Translated review text here..."
}
```

---

## 3. General Text Translation

A utility endpoint for translating arbitrary text using a strict prompt that prevents the model from adding, removing, or paraphrasing content.

### Prompt

```
You are a strict translation engine.
- Translate ONLY the provided text.
- Do NOT add, remove, or infer anything.
- Do NOT paraphrase or expand.
- Preserve original meaning and structure.
- If the input is incomplete, keep it incomplete.
Return ONLY the translated text.
```

### API Endpoint

#### `POST /api/utils/translate`

**Auth:** `Bearer <token>`  
**Plan:** Any active subscription or trial

**Request body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `text` | string (min 1) | Yes | Text to translate |
| `language` | string (min 1) | Yes | Target language |

**Response:**
```json
{
  "translation": "Translated text here..."
}
```

---

## 4. Sentiment & Topic Analysis

Automatically analyses each review's text to determine its overall sentiment and extract topic-level impressions across 7 categories.

### Categories

| Category | Example Sub-topics |
|----------|--------------------|
| Amenities | Pool, parking, kitchen, Wi-Fi, safety |
| Location | View, accessibility, neighbourhood |
| Accuracy | Photos match, description accuracy |
| Cleanliness | General hygiene, maintenance |
| Check-in | Process, instructions, efficiency |
| Communication | Responsiveness, clarity |
| Value for money | Price-to-quality perception |

### Output Structure

```json
{
  "generalImpression": "Positive",
  "topics": [
    {
      "text": "The pool was fantastic",
      "category": "Amenities",
      "subCategory": "Pool",
      "impressions": "Positive"
    }
  ]
}
```

`generalImpression` and `impressions` values: `Positive`, `Neutral`, or `Negative`.

### How It Works

Analysis runs as a background job after reviews are ingested. The extracted tags and sentiment values are stored on the review document and power all stats endpoints (`/api/stats/*`). See [Sentiment Analysis documentation](./sentiment-analysis.md) for how the data is surfaced in the UI.

---

## 5. Property Quarterly Summaries

Generates a structured bullet-point summary of a property's strengths and areas for improvement, based on reviews from a specific quarter.

### How It Works

1. User triggers summary generation via `POST /api/holdings/:holdingId/summaries`.
2. A summary record (status `0` = pending) is created in the database.
3. A background task picks up the pending record, fetches all reviews for the requested quarter, aggregates their analytics tags, and calls OpenAI.
4. OpenAI returns a JSON object with `strengths` and `improvements` arrays.
5. The record is updated to status `1` (complete) with the generated content, token usage, and execution time.

### Data Window

| Plan interval | Reviews analysed |
|---------------|-----------------|
| Monthly | Last 1 year |
| All other intervals | Last 2 years |

### Output Structure

```json
{
  "strengths": [
    { "key": "Cleanliness", "description": "Guests consistently praised the spotless condition of the property." }
  ],
  "improvements": [
    { "key": "Wi-Fi", "description": "Several guests reported slow or unreliable internet connection." }
  ]
}
```

### Summary Status Values

| Value | Meaning |
|-------|---------|
| `0` | Pending (queued for processing) |
| `1` | Complete |
| `-3` | Error |

### API Endpoints

#### `GET /api/holdings/:holdingId/summaries`

Retrieve generated summaries for a property.

**Auth:** `Bearer <token>`  
**Plan:** Business AI

**Query parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `quarter` | integer (1–4) | No | Filter by quarter |
| `year` | integer (≥ 2000) | No | Filter by year |

**Response:**
```json
[
  {
    "_id": "string",
    "holdingId": "string",
    "quarter": 1,
    "year": 2024,
    "status": 1,
    "rating": 4.7,
    "reviewsTotal": 38,
    "summary": {
      "strengths": [{ "key": "string", "description": "string" }],
      "improvements": [{ "key": "string", "description": "string" }]
    },
    "summaryTokens": { "prompt": 1200, "completion": 320 },
    "summaryTime": 4200
  }
]
```

#### `POST /api/holdings/:holdingId/summaries`

Queue a new quarterly summary for generation.

**Auth:** `Bearer <token>`  
**Plan:** Business AI

**Request body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `quarter` | integer (1–4) | Yes | Quarter to summarise |
| `year` | integer (≥ 2000) | Yes | Year to summarise |

---

## 6. Company Summary

Generates a company-wide summary across all properties, aggregating review tags from the entire portfolio.

### API Endpoint

#### `POST /api/users/summary`

**Auth:** `Bearer <token>`  
**Plan:** Business AI

No request body required. The summary is generated based on all reviews belonging to the authenticated user.

**Response:**
```json
{
  "strengths": [{ "key": "string", "description": "string" }],
  "improvements": [{ "key": "string", "description": "string" }]
}
```

---

## Data Stored Per Review

| Field | Description |
|-------|-------------|
| `generatedAnswers[]` | Up to 5 AI-generated responses with tone/nuance metadata |
| `copiedAnswer` | User-selected response saved for publishing |
| `translation[language]` | Cached translations keyed by language code |
| `generatingSettings` | Settings used at generation time |

## Data Stored Per User

| Field | Description |
|-------|-------------|
| `chatSettings` | Default language, tone, nuance, signature flags |
| `analitycsSummaryBullet` | Latest company summary bullet points |
| `analitycsSummaryTokens` | Token usage for the last company summary |
| `analitycsSummaryTime` | Execution time for the last company summary |
