<!-- Sources read:
  api/jobs/jobs.routes.js
  api/jobs/jobs.controller.js
  api/jobs/jobs.service.js
  middlewares/auth.js (authenticateApiKey)
  models/SourcesModel.js
  models/schemas/sources.schema.js
  app.js (route mount point)
-->

# Jobs API

## Overview

The Jobs API (`/api/jobs`) is a lightweight work-queue interface for external scraper workers. It currently targets VRBO source records: a worker claims a batch of pending VRBO sources, scrapes them, then reports success (with the raw scraped payload) or failure (with an error message). Authentication uses a static API key sent in the `X-Api-Key` header — no user JWT is involved. The endpoint is used exclusively by the Revyoos VRBO crawler workers.

---

## Authentication

All three routes use `authenticateApiKey` middleware:

- The request must include an `X-Api-Key` header.
- The value must match the `SCRAPER_API_KEY` environment variable.
- On mismatch or absence: HTTP 401 — `"Invalid or missing API key"`.

---

## Source status values

| Status code | Meaning |
|---|---|
| `0` | READY — available to be claimed |
| `1` | SUCCESS — successfully processed |
| `2` | IN_PROCESS — claimed by a worker |
| `-3` | ERROR — processing failed |

---

## API Endpoints

All routes are mounted at `/api/jobs`.

---

### `GET /api/jobs/claim`

Atomically claim up to `slots` VRBO source records that have `status_source: 0` (READY) for processing.

**Auth:** `X-Api-Key` header matching `SCRAPER_API_KEY`.

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `slots` | integer | No | Number of jobs to claim. Default: `1`. Max: `20`. |

**Server behaviour:**
- Iterates up to `slots` times; each iteration finds one VRBO source with `status_source: 0` using `findOne`.
- Stops early if no more READY sources are found.

> **Note:** The intended implementation uses `findOneAndUpdate` to atomically set `status_source: IN_PROCESS` on each claimed source (preventing duplicate claims by concurrent workers). The current code uses a non-atomic `findOne` without the status update — the `findOneAndUpdate` call is commented out.

**Response:**

```json
{
  "success": true,
  "data": {
    "jobs": [
      {
        "id": "64a1b2c3d4e5f6a7b8c9d0e1",
        "url": "https://www.vrbo.com/123456"
      }
    ]
  }
}
```

Each job object contains:
- `id` — the Source document `_id` (used in subsequent complete/fail calls).
- `url` — the `url_source` field (the VRBO listing URL to scrape).

---

### `POST /api/jobs/:id/complete`

Mark a job as successfully completed and store the scraped data payload.

**Auth:** `X-Api-Key` header.

**Path parameters:**

| Parameter | Description |
|---|---|
| `id` | The Source document `_id` returned by the claim endpoint. |

**Request body:** Raw scraped result object. Stored as-is in `vrboData` on the Source document.

**Server behaviour:** Sets `status_source: 1` (SUCCESS) and `vrboData: <body>` on the Source document.

**Response:**

```json
{
  "success": true
}
```

---

### `POST /api/jobs/:id/fail`

Mark a job as failed and record the error.

**Auth:** `X-Api-Key` header.

**Path parameters:**

| Parameter | Description |
|---|---|
| `id` | The Source document `_id` returned by the claim endpoint. |

**Request body:**

| Field | Type | Description |
|---|---|---|
| `error` | string or object | Error message or object describing the failure. Objects are JSON-stringified before storage. |

**Server behaviour:** Sets `status_source: -3` (ERROR) and `s_error_info: <error string>` on the Source document.

**Response:**

```json
{
  "success": true
}
```

---

## Data Model — `Sources` (collection: `Sources`)

Relevant fields for the Jobs API:

| Field | Type | Description |
|---|---|---|
| `_id` | ObjectId | Job identifier used in complete/fail calls. |
| `type_source` | string | Channel type. Enum: `tripadvisor`, `airbnb`, `booking`, `vrbo`, `trustpilot`, `expedia`, `google`, `revyoos`. Jobs API only processes `vrbo`. |
| `url_source` | string | The listing URL to scrape. |
| `status_source` | number | Processing status. Enum: `0` (READY), `1` (SUCCESS), `2` (IN_PROCESS), `-3` (ERROR), and others. |
| `vrboData` | object | Raw scraped payload stored by `completeJob`. |
| `s_error_info` | string | Error message stored by `failJob`. |
| `fk_id_user_source` | ObjectId | Owning user. |
| `fk_id_holding_source` | ObjectId | Associated property. |

---

## Components

| File | Purpose |
|---|---|
| `api/jobs/jobs.routes.js` | Mounts the three jobs routes under `/api/jobs`; applies `authenticateApiKey` middleware to all. |
| `api/jobs/jobs.controller.js` | Thin controller: parses `slots` (capped at 20), delegates to service, returns JSON. |
| `api/jobs/jobs.service.js` | Core logic: `claimJobs` (find up to N VRBO READY sources), `completeJob` (set SUCCESS + vrboData), `failJob` (set ERROR + s_error_info). |
| `middlewares/auth.js` (`authenticateApiKey`) | Validates `X-Api-Key` header against `SCRAPER_API_KEY` env var. |
| `models/SourcesModel.js` + `models/schemas/sources.schema.js` | Source document model used by the jobs service. |
