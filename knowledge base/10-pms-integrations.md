<!-- Sources read:
  nimad_vue3/src/revamp/pages/PMSConnection.vue
  nimad_vue3/src/revamp/pages/IntegrationStatus.vue
  nimad_vue3/src/revamp/pages/pms/ConnectionStatus.vue
  nimad_vue3/src/revamp/pages/pms/GuestyIntegration.vue
  nimad_vue3/src/revamp/pages/pms/HostawayIntegration.vue
  nimad_vue3/src/revamp/pages/pms/HostfullyIntegration.vue
  nimad_vue3/src/revamp/pages/pms/OtherPms.vue
  nimad_vue3/src/revamp/helpers/constants.js (PMS_WITH_INTEGRATION, PMS_WITHOUT_INTEGRATION, HOSTFULLY_*)
  nimad_vue3/src/constants/pms.js (GUESTY_ID, HOSTAWAY_ID, HOSTFULLY_ID)
  api/client/pms/pms.routes.js
  api/client/pms/pms.validation.js
  api/client/pms/pms.controller.js
  api/client/pms/hostfully/hostfully.service.js
  api/admin/pms/pms.service.js
-->

# PMS Integrations

## Overview

PMS Connection (`/account/pms-connection`) lets users link their Revyoos account to a Property Management System so that properties and reviews are imported and kept in sync automatically. Three PMS providers have direct API integrations (Guesty, Hostaway, Hostfully); additional providers can be registered as a non-integration preference (stored on the user record). Connecting any PMS deletes all existing user properties and triggers a re-import. Disconnecting marks the integration as disconnected but preserves stored credentials for potential reconnection.

---

## User Flow

### PMS Connection page (`/account/pms-connection`)

1. User navigates to `/account/pms-connection`.
2. Page title: **"PMS Connection"**. Subtitle: **"Connect your software to keep your data updated automatically."**

**Connection Status card** (always visible at the top):
- If no PMS is connected: badge **"Not Connected"** and text **"Your account is currently not linked to any PMS."**
- If a PMS is connected: PMS logo + badge **"Connected"** (green) or **"Disconnected"** (red).
  - When `connected`: **"Disconnect"** button (`data-testid="pms-disconnect-btn"`). While disconnecting: **"Disconnecting..."**. On error: `toast.error(getApiError(err, 'Failed to disconnect this integration.'))`.
  - When disconnected but credentials exist (`canReconnect`): **"Reconnect"** button (`data-testid="pms-reconnect-btn"`). While reconnecting: **"Reconnecting..."**. On error: `toast.error(getApiError(err, 'Failed to reconnect this integration.'))`. A yellow warning: **"Previous Session Found. Integration data already exists. You can restore your sync."**

**Sync your properties card** — section heading **"Sync your properties"**, description **"Available Direct Connections"**:
- Three radio cards for direct-integration PMS options. Radio cards are disabled when any PMS is already connected (`connectedToStoredPms`).

| Radio value | Logo | Subtitle |
|---|---|---|
| `guesty` | `logo-guesty.svg` | `"Full instant synchronization."` |
| `hostaway` | `logo-hostaway.svg` | `"Works with <strong>Airbnb</strong> and <strong>Vrbo</strong>."` |
| `hostfully` | `logo-hostfully.svg` | `"Easy one-click connection."` |

- When no radio is selected: **OtherPms** component is shown (see below).
- When a radio is selected: the corresponding integration form is shown.
- Both forms share a yellow warning before connecting:
  - **"Important considerations before connecting:"**
  - _"Existing data (properties, reviews, widgets) will be refreshed to avoid duplicates."_
  - _"If you exceed your property limit, your plan will be upgraded automatically."_
  - Checkbox: **"I have reviewed and agree to the above considerations, including the automatic subscription upgrade."**
  - Buttons: **"Cancel"** (`data-testid="pms-cancel-btn"`) / **"Connect PMS"** (`data-testid="pms-connect-btn"`). **"Connect PMS"** is disabled until the checkbox is ticked.

---

### Guesty connection form

- Heading: **"Connecting with Guesty"**.
- Field: **"Guesty integration token"** — textarea (`data-testid="guesty-token-input"`).
- Notes below field:
  - _"(!) The integration token can be used to create client credentials once."_
  - _"(!) The integration token will expire within 3 hours if not used to create client credentials."_
- On **"Connect PMS"**: validates token client-side (`guestySchema`). On API success: clears the token field, emits `connect` (parent refetches user), triggers Tapfiliate update.

---

### Hostaway connection form

- Heading: **"Connecting with Hostaway"**.
- Two fields side by side:
  - **"Hostaway user ID"** — text input (`data-testid="pms-hostaway-id-input"`).
  - **"Hostaway integration token"** — text input (`data-testid="pms-hostaway-token-input"`).
- Notes below fields:
  - _"(!) The integration token can be used to create client credentials once."_
  - _"(!!) The integration token will expire within 20 days if not used to create client credentials."_
- On **"Connect PMS"**: validates both fields (`hostawaySchema`). On error: `toast.error(getApiError(err, 'Something went wrong.'))`.

---

### Hostfully connection form

- Heading: **"Connecting with Hostfully"**.
- Description text: _"If you are using Hostfully direct booking property listings urls in your website, your reviews will automatically appear on your website. If not you will have to add Revyoos widget manually in your website, please specify:"_
- Two radio options:
  - **"I use Hostfully direct booking website or I have my own website but I am using Hostfully direct bookings site for my properties."**
  - **"I have my own independent website"**
  - Link: **"I am not sure (please contact us)"** → `/contact-us`.
- Info banner (blue): **"Easy one-click connection."** — _"We will redirect you to Hostfully to securely approve the connection. Please make sure the Revyoos channel is active."_
- On **"Connect PMS"**: saves `is_using_hostfully_website` preference via `updateUser`, updates Tapfiliate, then redirects the browser to `https://api.hostfully.com/api/auth/oauth/authorize` with params `state=userId`, `scope=FULL`, `grantType=REFRESH_TOKEN`, `clientId`, `redirectUri`.

---

### OtherPms — no direct integration

- Shown when no radio is selected on the main page.
- Center display: _"Using a different software?"_ + description _"Tell us which one you use so we can focus our efforts on building the connections you need."_
- Shows current selection: **"Currently: [name]"** (or `"I don't use a PMS"` if none set). Link: **"Set your current software →"** (`data-testid="pms-set-software-btn"`).
- When expanded: a **"Which PMS do you work with?"** dropdown (`data-testid="business-pms-select"`).
  - First item: **"I don't use a PMS"** (`value="noPms"`).
  - Then all `PMS_WITHOUT_INTEGRATION` options:

| Value | Label |
|---|---|
| `avantio` | Avantio |
| `bookster` | Bookster |
| `hostify` | Hostify |
| `kross-booking` | Kross Booking |
| `lodgify` | Lodgify |
| `smoobu` | Smoobu |
| `other` | Other (please specify) |

  - When `other` is selected: an additional **"Other PMS"** text input appears (`data-testid="business-other-pms-input"`).
- **"Save"** button (`data-testid="pms-save-other-pms-btn"`) — disabled until a value is selected or while saving. On success: parent updates user store. On error: `toast.error(getApiError(err, 'Failed to save your selected integration.'))`.
- **"← Go Back"** link resets the form.

---

### Integration Status page (`/integration-status`)

Shown after a Hostfully OAuth callback redirect. Accessible without authentication.

- **Success state** (`?status=success`): checkmark icon, heading **"PMS Connected"**, message from `?text=` query param, countdown from 5 seconds then auto-redirects to `/dashboard`. Button: **"Go to Dashboard"**.
- **Error state** (any other `?status`): X-circle icon, heading **"Connection Failed"**, message from `?text=` query param. Button: **"Go to Dashboard"**.

---

## Hostfully OAuth Callback (server-side)

When Hostfully redirects back to `GET /api/pms/hostfully/callback`:

1. Validates `status`, `state` (userId), `code` from query params.
2. If `status !== 'SUCCESSFUL'`: cleans up `is_using_hostfully_website` on user → redirects to `/clients/#/integration-status?status=error&text=Hostfully+connection+failed`.
3. Exchanges `code` for `accessToken` + `refreshToken` via server-to-server call to Hostfully's token endpoint.
4. Fetches the agency UID from Hostfully's `GET /api/v3/agencies`.
5. Deletes all existing user properties.
6. Saves `hostfullyData: { accessToken, refreshToken }`, `pmsData: { id: "hostfully" }`, `hostfully_UID`, and `is_notification_required: 'import'` on the user.
7. On success: redirects to `/clients/#/integration-status?status=success&text=Hostfully+connected+successfully.+Your+properties+are+now+syncing+-+please+refresh+the+page+in+a+few+minutes.`

---

## Server-side connect behaviour (Guesty and Hostaway)

On `POST /api/pms/connect` with credentials:

1. Calls `PmsService.connectPms(pms, pmsData)`:
   - **Guesty**: calls Guesty API to exchange integration token for client credentials (`guestyData`). Sets `is_notification_required: 'import'` on user.
   - **Hostaway**: exchanges `hostawayId` + `hostawayToken` for an access token. Stores `accessToken`, `tokenExpiredDate`, `clientId`, `clientSecret` in `hostawayData`. Sets `is_notification_required: 'import'`.
2. Sends email notification to Revyoos team if `isSendNotification: true`.
3. Updates `pmsData.id` on the user record.
4. Deletes all user properties (`deleteAllHoldings`).
5. Recalculates user data totals.
6. Syncs to Zoho CRM.

**Disconnect** (`POST /api/pms/disconnect`): sets `disconnected: true` on the active PMS's data object in the user record. Syncs to Zoho.

**Reconnect** (`POST /api/pms/reconnect`): sets `disconnected: false` on the stored PMS data. Sets `is_notification_required: 'import'`. Syncs to Zoho.

**Resync** (`POST /api/pms/resync`): sets `is_notification_required: 'import'` to trigger a background re-import. Syncs to Zoho.

---

## Access Control

| Action | Requirement |
|---|---|
| View `/account/pms-connection` | Authenticated (`requiresAuth: true`). |
| Connect a PMS | Authenticated (Bearer JWT). |
| Disconnect a PMS | Authenticated (Bearer JWT). |
| Reconnect a PMS | Authenticated (Bearer JWT). |
| Resync a PMS | Authenticated (Bearer JWT). |
| Hostfully OAuth callback (`GET /api/pms/hostfully/callback`) | **No authentication** — public redirect endpoint. |
| View `/integration-status` | **No authentication** — public status page. |

---

## API Endpoints

All PMS endpoints are mounted at `/api/pms`. The `authenticate` middleware is applied to all except the Hostfully callback.

---

### `GET /api/pms/hostfully/callback`

OAuth callback endpoint for Hostfully. No authentication required. Redirects browser to `/clients/#/integration-status?status=...&text=...`.

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `state` | string | Yes | User `_id` (set as the OAuth `state` param during the redirect). Min 1, max 100 characters. |
| `status` | string | Yes | `SUCCESSFUL`, `DECLINED`, or `INCORRECT_REQUEST`. |
| `code` | string | Conditional | Authorization code. Required when `status=SUCCESSFUL`. Min 1, max 100 characters. |

**Response:** HTTP 302 redirect to `/clients/#/integration-status`.

---

### `POST /api/pms/connect`

Connect the user to a PMS.

**Auth:** Bearer JWT (authenticated).

**Request body** (discriminated union on `pms`):

For `pms: "guesty"`:

| Field | Type | Required | Description |
|---|---|---|---|
| `pms` | string | Yes | `"guesty"` |
| `pmsData.guestyToken` | string | Yes | Guesty integration token. |
| `isSendNotification` | boolean | No | Send admin email notification. |
| `notificationAction` | string | Conditional | Required if `isSendNotification` is provided. |

For `pms: "hostaway"`:

| Field | Type | Required | Description |
|---|---|---|---|
| `pms` | string | Yes | `"hostaway"` |
| `pmsData.hostawayId` | string | Yes | Hostaway user ID. |
| `pmsData.hostawayToken` | string | Yes | Hostaway integration token. |
| `isSendNotification` | boolean | No | Send admin email notification. |
| `notificationAction` | string | Conditional | Required if `isSendNotification` is provided. |

For `pms: "hostfully"`:

| Field | Type | Required | Description |
|---|---|---|---|
| `pms` | string | Yes | `"hostfully"` |

For `pms: "noPms"`:

| Field | Type | Required | Description |
|---|---|---|---|
| `pms` | string | Yes | `"noPms"` |

**Response (success):**

```json
{
  "success": true,
  "data": { "pms": "guesty" }
}
```

---

### `POST /api/pms/disconnect`

Mark the user's active PMS connection as disconnected. Preserves credentials for reconnection.

**Auth:** Bearer JWT (authenticated).

**Request body:** Empty.

**Response (success):**

```json
{
  "success": true,
  "message": "Successfully disconnected from PMS"
}
```

---

### `POST /api/pms/reconnect`

Restore a previously disconnected PMS connection and trigger a re-import.

**Auth:** Bearer JWT (authenticated).

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `pms` | string | Yes | `"hostaway"`, `"guesty"`, or `"hostfully"`. |

**Response (success):**

```json
{
  "success": true,
  "message": "Successfully reconnected to PMS"
}
```

---

### `POST /api/pms/resync`

Trigger a background re-import of PMS data without changing connection credentials.

**Auth:** Bearer JWT (authenticated).

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `pms` | string | Yes | `"hostaway"`, `"guesty"`, or `"hostfully"`. |

**Response (success):**

```json
{
  "success": true,
  "message": "PMS resync initiated successfully"
}
```

---

## Components

| File | Route | Purpose |
|---|---|---|
| `nimad_vue3/src/revamp/pages/PMSConnection.vue` | `/account/pms-connection` | Main PMS page shell — radio card picker, connection state logic (`findActiveIntegration`, `getIntegrationIsActive`, `canReconnectIntegration`), Tapfiliate hook on connect events. |
| `nimad_vue3/src/revamp/pages/pms/ConnectionStatus.vue` | (sub-component) | Connection Status card — shows PMS logo + Connected/Disconnected badge; Disconnect and Reconnect buttons; "Previous Session Found" warning. |
| `nimad_vue3/src/revamp/pages/pms/GuestyIntegration.vue` | (sub-component) | Guesty token textarea form; acceptance checkbox; "Connect PMS" action calling `POST /api/pms/connect`. |
| `nimad_vue3/src/revamp/pages/pms/HostawayIntegration.vue` | (sub-component) | Hostaway user-ID + token inputs form; acceptance checkbox; "Connect PMS" action. |
| `nimad_vue3/src/revamp/pages/pms/HostfullyIntegration.vue` | (sub-component) | Hostfully website-type radio selector; acceptance checkbox; saves preference then redirects browser to Hostfully OAuth authorize URL. |
| `nimad_vue3/src/revamp/pages/pms/OtherPms.vue` | (sub-component) | Non-integration PMS preference selector; "Set your current software" link; dropdown of 7 options; "Other PMS" free-text fallback; saves via `updateUser`. |
| `nimad_vue3/src/revamp/pages/IntegrationStatus.vue` | `/integration-status` | Post-OAuth status page — success (checkmark, countdown redirect) or error (X icon, manual "Go to Dashboard") depending on `?status` query param. |
