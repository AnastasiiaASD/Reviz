<!-- Sources read:
  api/admin/index.js
  api/admin/users/users.routes.js
  api/admin/users/users.controller.js
  api/admin/users/users.service.js
  api/admin/stats/stats.routes.js
  api/admin/stats/stats.controller.js
  api/admin/stats/stats.service.js
  api/admin/logs/logs.routes.js
  api/admin/logs/logs.controller.js
  api/admin/logs/logs.service.js
  api/admin/reviews/reviews.routes.js
  api/admin/reviews/reviews.service.js
  api/admin/pms/pms.controller.js
  api/admin/pms/pms.service.js (referenced)
-->

# Admin Panel

## Overview

The Admin Panel is a backend-only API mounted at `/api/nimad`. It provides admin-only endpoints for user management, platform statistics, audit log access, and review moderation. No frontend Vue components for the admin panel exist in this repository — the API is consumed by a separate admin dashboard application. All protected routes require both JWT authentication and the `admin` role (`n_admin: true` on the user document). Authentication uses a two-step flow: password sign-in or email OTP, both returning a 1-day admin JWT.

---

## Authentication

### Password sign-in

- `POST /api/nimad/users/signin` — email + password. Requires `n_admin: true` on the user record. Returns `{ user, token }`.

### OTP flow (two steps)

1. `POST /api/nimad/users/request-otp` — admin emails a 6-digit OTP. OTP is bcrypt-hashed and stored in Redis at key `admin:otp:{email}` with a 5-minute TTL and a max of 5 attempts. Email sent with subject: **"Your OTP Code"**, body: `"Your OTP code is: {otp}"`. Non-admin email attempts are logged to `LogsM` as type `'NON ADMIN LOGIN ATTEMPT'`.
2. `POST /api/nimad/users/verify-otp` — validates OTP against the Redis hash. Each failed attempt increments the counter. After 5 failed attempts the key is deleted and further attempts fail with `"OTP has expired. Please request a new one."`. On success: key is deleted and a 1-day admin JWT is returned.

Admin JWT payload: `{ _id, role: 'admin' }`. Expires in `1d`.

---

## Access Control

| Action | Requirement |
|---|---|
| Sign in (password) | `n_admin: true` on user document. |
| Request / verify OTP | `n_admin: true` on user document. |
| All other admin endpoints | Authenticated JWT + `authorize('admin')` middleware. |

---

## API Endpoints

All admin routes are prefixed `/api/nimad`.

---

### User Management (`/api/nimad/users`)

---

#### `GET /api/nimad/users`

Get a paginated list of users. Supports filtering, sorting, and CSV export.

**Auth:** Admin JWT.

**Query parameters:**

| Parameter | Type | Description |
|---|---|---|
| `page` | integer | Page number. Page size: 100. |
| `sortField` | string | Field to sort by. |
| `sortOrder` | string | `asc` or `desc`. |
| `filters` | string | URL-encoded JSON object with optional filter fields (see below). |
| `export_csv` | boolean | If truthy: returns full CSV dump (up to all records) instead of paginated JSON. |
| `exportFields` | string | Comma-separated list of CSV column keys to include in export. |

**Filter fields (inside `filters` JSON):**

| Filter key | Type | Behaviour |
|---|---|---|
| `email_user` | string | Case-insensitive regex search on email. |
| `name_user` | string | Case-insensitive regex search on name. |
| `website` | string | Case-insensitive regex search on website. |
| `name_com` | string | Case-insensitive regex search on `o_company.name_com`. |
| `stripe_id` | string | Exact match on `stripe_customer_id`. |
| `pms` | string | Exact match on `pmsData.id`. |
| `plan` | string | `basic`, `business`, `businessAi`, `premium` — regex-based match on `o_plan.id`. |
| `status` | string | `active` (`b_active_subscription: true`), `trial` (`date_end_trial > now`, not subscribed), `expired` (trial ended, no plan), `inactive` (not subscribed, has plan, trial ended). |
| `b_has_no_properties` | boolean | Filters users with `n_total_holdings = 0`. |
| `b_has_no_reviews` | boolean | Filters users with `n_total_reviews = 0`. |

**CSV export columns (keys):**

`id`, `name`, `email`, `company`, `status`, `plan`, `amount`, `interval`, `properties`, `rating`, `reviews`, `registrationDate`, `lastLogin`, `pms`, `stripe`, `tapRef`, `tapId`.

Status values in CSV: `"Active"`, `"Trial"`, `"Inactive"`.

CSV filename format: `users_report_YYYY-MM-DD.csv`.

---

#### `GET /api/nimad/users/:id`

Get a single user by ID. Password field (`password_user`) is stripped from the response.

**Auth:** Admin JWT.

---

#### `PUT /api/nimad/users/:id`

Update a user. Only specific fields are allowed; all other submitted fields are ignored. Changes are compared to the pre-update state and written to the admin audit log.

**Auth:** Admin JWT.

**Allowed update fields:**

| Field | Description |
|---|---|
| `o_company` | Company object (incl. `name_com`). Company name uniqueness is validated. |
| `name_user` | User display name. |
| `date_end_trial` | Trial expiry date. |
| `email_user` | Email address. |
| `guestyFilters` | Guesty-specific filter settings. |

**Audit log:** Writes an `'UPDATE'` + `'USER'` log entry with before/after values for: `o_company.name_com`, `name_user`, `email_user`, `date_end_trial`. Date fields are formatted as `YYYY-MM-DD HH:mm:ss` in the log.

**Response (success):**

```json
{
  "success": true,
  "message": "User updated successfully",
  "data": { "user": {} }
}
```

---

#### `POST /api/nimad/users/:id/signin`

Impersonate a user — generates a user-role JWT for the target user without requiring their password. Used to log in as a specific user for support purposes.

**Auth:** Admin JWT.

**Server behaviour:**
1. Loads user by `id`.
2. Signs a JWT with `{ _id: user._id, role: 'user' }`, expires in `1d`.
3. Logs the action to the admin audit log as `action: 'LOGIN'`, `resource_type: 'USER'` with description: `"Logged in as an user {email}"`.

**Response:**

```json
{
  "success": true,
  "message": "Login successful",
  "data": { "token": "...", "user": { /* user object without password */ } }
}
```

---

### PMS Management (`/api/nimad/users/:id/pms/*`)

All PMS routes take a user ID path parameter and require admin JWT.

| Endpoint | Body | Description |
|---|---|---|
| `POST /api/nimad/users/:id/pms/connect` | `{ pms, pmsData, otherPmsName }` | Connect user to a PMS. Calls `PmsService.connectPms()` then `updatePmsData()`. |
| `POST /api/nimad/users/:id/pms/disconnect` | (none) | Mark the user's PMS as disconnected. |
| `POST /api/nimad/users/:id/pms/reconnect` | `{ pms }` | Restore a disconnected PMS connection; triggers re-import. |
| `POST /api/nimad/users/:id/pms/resync` | `{ pms }` | Trigger a background re-import without changing credentials. |

---

### Statistics (`/api/nimad/stats`)

All stats routes require admin JWT.

---

#### `GET /api/nimad/stats/users-counts`

Returns total platform-wide document counts.

**Response:**

```json
{
  "success": true,
  "data": {
    "totalUsers": 4200,
    "totalHoldings": 31000,
    "totalReviews": 850000
  }
}
```

---

#### `GET /api/nimad/stats/dashboard`

Returns current subscriber and trial user counts.

**Response:**

```json
{
  "success": true,
  "data": {
    "subscribedUsers": 312,
    "trialUsers": 88
  }
}
```

---

#### `GET /api/nimad/stats/open-ai`

Fetches OpenAI organization cost data for the last 20 days (1-day buckets) directly from the OpenAI API. Uses `OPENAI_API_KEY`.

**Response:** Raw OpenAI API response (`/v1/organization/costs`).

---

#### `GET /api/nimad/stats/channels-bots`

Returns per-channel source sync status counts and aggregate totals. Excludes sources of type `revyoos`, `stayz`, `facebook`.

**Response:**

```json
{
  "success": true,
  "data": {
    "totalCounts": {
      "pending": 120,
      "error": 15,
      "completed": 4200,
      "total": 4335,
      "errorsPercentage": 0.35,
      "progressPercentage": 97.23
    },
    "channelCounts": {
      "airbnb": {
        "pending": 40,
        "error": 5,
        "completed": 1800,
        "total": 1845,
        "errorsPercentage": 0.27,
        "progressPercentage": 97.83
      }
    }
  }
}
```

Source statuses: `0` = pending, `-3` = error, `1` = completed.

---

#### `GET /api/nimad/stats/channels-bots/errors`

Returns grouped error messages per channel, ranked by count.

**Response:**

```json
{
  "success": true,
  "data": {
    "channelErrors": {
      "airbnb": [
        { "type": "CAPTCHA_REQUIRED", "count": 45 },
        { "type": "SESSION_EXPIRED", "count": 12 }
      ],
      "booking": [
        { "type": "RATE_LIMIT", "count": 8 }
      ]
    }
  }
}
```

---

#### `GET /api/nimad/stats/channels-distribution`

Returns the number of source records per channel, scoped to active users (those in trial or with an active subscription).

**Response:**

```json
{
  "success": true,
  "data": [
    { "channel": "airbnb", "reviews": 8200 },
    { "channel": "booking", "reviews": 4100 }
  ]
}
```

---

#### `GET /api/nimad/stats/subscription-distribution`

Returns user count grouped by plan tier (first part of plan nickname split on `_`).

**Response:**

```json
{
  "success": true,
  "data": [
    { "plan": "business", "users": 180 },
    { "plan": "businessAi", "users": 95 },
    { "plan": "basic", "users": 37 }
  ]
}
```

---

### Logs (`/api/nimad/logs`)

All log routes require admin JWT.

---

#### `GET /api/nimad/logs`

Returns system logs of type `'NON ADMIN LOGIN ATTEMPT'` — records of attempts to sign in to the admin panel with a non-admin email.

**Response:**

```json
{
  "success": true,
  "data": [ /* log entries from LogsM */ ]
}
```

---

#### `GET /api/nimad/logs/adminLogs`

Returns paginated admin audit logs. Supports filtering and CSV export. Page size: 100.

**Query parameters:**

| Parameter | Type | Description |
|---|---|---|
| `page` | integer | Page number. |
| `sortField` | string | Sort field. |
| `sortOrder` | string | `asc` or `desc`. |
| `filters` | string | URL-encoded JSON with optional filter fields (see below). |
| `export_csv` | boolean | If truthy: returns CSV (up to 10,000 records). |
| `exportFields` | string | CSV columns to include. |

**Filter fields (inside `filters` JSON):**

| Filter key | Type | Behaviour |
|---|---|---|
| `admin_email` | string | Case-insensitive regex. |
| `action` | string | Exact match (e.g. `UPDATE`, `LOGIN`). |
| `resource_type` | string | Exact match (e.g. `USER`). |
| `resource_id` | string | Case-insensitive regex on resource ID string. |
| `date_from` | string | ISO date — start of day, inclusive. |
| `date_to` | string | ISO date — end of day, inclusive. |

CSV filename format: `audit_logs_report_YYYY-MM-DD.csv`.

---

### Reviews (`/api/nimad/reviews`)

All review routes require admin JWT. Only Revyoos-native reviews (`type_source_reviews: 'revyoos'` and `fk_id_file_reviews: null`) are accessible via the admin API.

---

#### `GET /api/nimad/reviews`

Get a paginated list of Revyoos-type reviews. Page size: 100.

**Query parameters:**

| Parameter | Type | Description |
|---|---|---|
| `page` | integer | Page number. |
| `sortField` | string | Sort field. |
| `sortOrder` | string | `asc` or `desc`. |
| `filters` | string | URL-encoded JSON with optional filter fields. |

**Filter fields (inside `filters` JSON):**

| Filter key | Behaviour |
|---|---|
| `email_user` | Resolves matching user IDs, then filters reviews by those user IDs. |
| `name_holding` | Resolves matching holding IDs, then filters reviews by those holding IDs. |
| `comment` | Case-insensitive regex search on `content_reviews`. |

---

#### `DELETE /api/nimad/reviews/:id`

Permanently delete a Revyoos-native review. Before deletion, the document is moved to the `RecycleM` collection for recovery purposes. Only deletes records where `type_source_reviews = 'revyoos'` and `fk_id_file_reviews = null`.

---

## Admin Audit Log

Every write action performed by an admin is recorded in the `AdminAuditLogsM` collection.

**Logged events:**

| Action | Resource Type | Trigger |
|---|---|---|
| `UPDATE` | `USER` | `PUT /api/nimad/users/:id` — only logged when at least one tracked field changed. |
| `LOGIN` | `USER` | `POST /api/nimad/users/:id/signin` — every impersonation. |

**Log entry fields:**

| Field | Description |
|---|---|
| `admin_user_id` | Admin user's MongoDB ID. |
| `admin_email` | Admin user's email. |
| `action` | `UPDATE`, `LOGIN`, etc. |
| `resource_type` | `USER`, etc. |
| `resource_id` | Target resource ID (string). |
| `old_data` | Document state before the change. |
| `new_data` | Document state after the change. |
| `description` | Human-readable summary of the change. |
| `changes` | Object with `changedFields`, `oldValues`, `newValues`, `details` (array of `"field: old → new"` strings). |
| `user_agent` | Request user-agent. |
| `request_details` | `{ method, url, params, body }`. |

Date fields in change diffs are formatted as `YYYY-MM-DD HH:mm:ss`. Tracked fields for user updates: `o_company.name_com`, `name_user`, `email_user`, `date_end_trial`.

---

## Components

There are no Vue frontend components for the admin panel in this repository. The admin API is consumed by an external admin dashboard application.

| File | Purpose |
|---|---|
| `api/admin/index.js` | Admin router — mounts `/users`, `/stats`, `/logs`, `/reviews` at `/api/nimad`. |
| `api/admin/users/users.routes.js` | User management + admin auth routes. |
| `api/admin/users/users.service.js` | User listing (with filters + CSV export), user update (allowed fields only), admin sign-in, OTP request/verify, user impersonation. |
| `api/admin/stats/stats.routes.js` | Stats routes. |
| `api/admin/stats/stats.service.js` | Stats aggregations: counts, OpenAI costs, channel bot status, channel distribution, subscription distribution. |
| `api/admin/logs/logs.routes.js` | Logs routes. |
| `api/admin/logs/logs.service.js` | `logAdminAction` (writes to `AdminAuditLogsM`), `getAdminLogs` (paginated audit logs), `getLogs` (system login attempt logs). |
| `api/admin/reviews/reviews.routes.js` | Reviews routes. |
| `api/admin/reviews/reviews.service.js` | `getReviews` (filtered Revyoos reviews), `deleteReview` (move to recycle + hard delete). |
| `api/admin/pms/pms.controller.js` | Admin PMS connect, disconnect, reconnect, resync for a given user ID. |
