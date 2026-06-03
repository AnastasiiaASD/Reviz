<!-- Sources read:
  api/client/tapfilliate/tapfilliate.routes.js
  api/client/tapfilliate/tapfilliate.validation.js
  api/client/tapfilliate/tapfilliate.controller.js
  api/client/tapfilliate/tapfilliate.service.js
  helpers/TapfilliateHelper.js
  constants/pms.js (REFERAL_MAP, REFERAL_MAP_FLIPPED, DEMO_REFERAL_CODE)
  nimad_vue3/src/revamp/api/tapfiliate.js
  nimad_vue3/src/revamp/pages/Register.vue (tapfiliate trigger on sign-up)
  nimad_vue3/src/revamp/pages/PMSConnection.vue (tapfiliate trigger on PMS connect/reconnect)
  nimad_vue3/src/revamp/pages/pms/GuestyIntegration.vue
  nimad_vue3/src/revamp/pages/pms/ConnectionStatus.vue
  nimad_vue3/src/revamp/pages/pms/OtherPms.vue
  plugins_api/StripewebhookApiPlugin.js (conversion posting on invoice.payment_succeeded)
-->

# Affiliate / Tapfiliate

## Overview

Revyoos tracks partner-referred sign-ups and paid conversions via the Tapfiliate affiliate platform. When a user registers through a PMS partner referral link (identified by a `?ref=` query parameter), a Tapfiliate customer record is created for that user with their referral code. When the user subsequently connects or reconnects a PMS, the affiliate record is updated to reflect the active integration. When a paid Stripe invoice is processed, a Tapfiliate conversion is posted to credit the referring affiliate.

---

## User Flow

### Registration with a referral link

1. User arrives at the Revyoos registration page with a `?ref=` query parameter (e.g. `?ref=lodgify`).
2. After the user completes registration successfully, the frontend calls `POST /api/tapfilliate` with `{ ref: "<tapfiliate-referral-code>" }`.
3. If the `ref` value matches a known referral code, a Tapfiliate customer record is created and stored on the user as `o_affiliate_complete` and `o_affiliate`.
4. If no `?ref=` is present, no Tapfiliate call is made.

### PMS connect / reconnect

1. After successfully connecting Guesty, Hostaway, Hostfully, or setting an "Other PMS" preference, the PMS Connection page emits `runTapfiliate` with the PMS identifier.
2. The parent (`PMSConnection.vue`) maps the PMS identifier to its Tapfiliate referral code via `REFERAL_MAP` and calls `PUT /api/tapfilliate` with `{ ref: "<tapfiliate-referral-code>" }`.
3. Also triggered after a PMS **reconnect** (via `ConnectionStatus.vue`).

### Paid invoice conversion

When Stripe fires `invoice.payment_succeeded` (handled by the Stripe webhook):
1. If the invoice is paid (`status === 'paid'`) and `amount_paid > 0` and the user has an `o_affiliate_complete.id` stored.
2. The Tapfiliate customer record is fetched to verify the `customer_id` matches and the affiliate is not canceled.
3. A conversion is posted to Tapfiliate with `external_id = invoice.id` and `amount = invoice.amount_paid / 100`.

---

## Referral Code Map

| PMS name (internal key) | Tapfiliate referral code |
|---|---|
| `lodgify` | `lodgify` |
| `guesty` | `ngfmodyb` |
| `hostfully` | `hostfully` |
| `hostaway` | `ngm2yzg` |
| `bookster` | `booksterhq` |
| `hostify` | `hostify` |
| `kross-booking` | `kross` |
| `smoobu` | `smoobugmbh` |

`REFERAL_MAP_FLIPPED` is the inverse — maps Tapfiliate codes back to PMS names (used in the update flow and for dev-mode metadata).

In development environments (`NODE_DEMO=1` or `NODE_DEV=1`), all Tapfiliate calls replace the referral code with the demo code `mzk1mwm` and inject `meta_data: { affiliate_type: 'test', affiliate: '<pms-name>' }`.

---

## Update logic (PUT)

When `PUT /api/tapfilliate` is called:

1. Checks whether the `ref` in the request body is a known Tapfiliate code (i.e. present in `REFERAL_MAP` values).
2. If the user has **no existing** affiliate record: creates a new Tapfiliate customer with `status: 'trial'`.
3. If the user **already has** an affiliate record and the stored affiliate ID differs from the incoming PMS:
   - Deletes the old Tapfiliate customer record.
   - Creates a new Tapfiliate customer record with the new referral code.
4. If the PMS matches the currently stored affiliate, no action is taken.
5. On success: updates `o_affiliate_complete` and `o_affiliate` on the user document.

---

## Access Control

| Action | Requirement |
|---|---|
| Create Tapfiliate connection | Authenticated (Bearer JWT). |
| Update Tapfiliate connection | Authenticated (Bearer JWT). |
| Post conversion (server-side) | Internal — triggered by Stripe webhook only. |

---

## API Endpoints

All Tapfiliate endpoints are mounted at `/api/tapfilliate` and require `authenticate` middleware.

---

### `POST /api/tapfilliate`

Create a new Tapfiliate customer connection. Called during registration when a `?ref=` query param is present.

**Auth:** Bearer JWT (authenticated).

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `ref` | string | Yes | Tapfiliate referral code. Enum: `smoobugmbh`, `kross`, `hostify`, `booksterhq`, `ngm2yzg`, `hostfully`, `ngfmodyb`, `lodgify`. |

**Server behaviour:**
1. Validates `ref` is in `REFERAL_MAP` values.
2. Calls Tapfiliate `POST /customers/` with `{ status: 'trial', user_agent, referral_code: ref, customer_id: user.stripe_customer_id }`.
3. Saves returned Tapfiliate customer data to `user.o_affiliate_complete` and `user.o_affiliate`.

**Response (success):**

```json
{
  "success": true,
  "data": "Successfully created tapfilliate connection"
}
```

**Response (invalid ref):** HTTP 500 — `"Wrong referral code"`.

---

### `PUT /api/tapfilliate`

Update an existing Tapfiliate connection. Called after a PMS is connected, reconnected, or an "Other PMS" preference is saved.

**Auth:** Bearer JWT (authenticated).

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `ref` | string | Yes | Tapfiliate referral code (same enum as POST). |

**Server behaviour:** See [Update logic](#update-logic-put) above.

**Response (success):**

```json
{
  "success": true,
  "message": "Successfully updated tapfilliate connection"
}
```

---

## Tapfiliate API integration (server-side helper)

`TapfilliateHelper` wraps Tapfiliate REST API v1.6 at `https://api.tapfiliate.com/1.6/`. Authentication uses the `TAPFILIATE_API_KEY` environment variable sent as the `X-Api-Key` header.

| Method | Tapfiliate endpoint | Purpose |
|---|---|---|
| `createAffilliate(payload)` | `POST /customers/` | Create a new affiliate customer record. |
| `getAffilliate(affiliateId)` | `GET /customers/{affiliateId}` | Fetch an existing affiliate customer record. |
| `deleteAffilliate(affiliateId)` | `DELETE /customers/{affiliateId}/` | Delete an affiliate customer record (before re-creating with a different PMS). |
| `getConversions(customerId)` | `GET /conversions/?customer_id=...` | Fetch conversion records for a customer. |
| `postConversion(payload)` | `POST /conversions/` | Post a paid conversion event. Payload: `{ external_id, customer_id, amount, meta_data }`. |

---

## User document fields

| Field | Description |
|---|---|
| `o_affiliate_complete` | Full Tapfiliate customer object returned from `POST /customers/`. |
| `o_affiliate` | Shorthand affiliate identity: `{ id, firstname }`. |

---

## Components / trigger points

| Location | Trigger | Action |
|---|---|---|
| `nimad_vue3/src/revamp/pages/Register.vue` | After successful registration if `?ref=` query param is present | Calls `POST /api/tapfilliate` with the ref code |
| `nimad_vue3/src/revamp/pages/PMSConnection.vue` (`runUpdateTapfiliate`) | After Guesty, Hostaway, Hostfully connect; after any PMS reconnect; after "Other PMS" save | Maps PMS id → referral code via `REFERAL_MAP`, calls `PUT /api/tapfilliate` |
| `nimad_vue3/src/revamp/pages/pms/GuestyIntegration.vue` | On successful `POST /api/pms/connect` | Emits `runTapfiliate('guesty')` to parent |
| `nimad_vue3/src/revamp/pages/pms/HostawayIntegration.vue` | On successful `POST /api/pms/connect` | Emits `runTapfiliate('hostaway')` to parent |
| `nimad_vue3/src/revamp/pages/pms/ConnectionStatus.vue` | On successful `POST /api/pms/reconnect` | Emits `runTapfiliate(integrationId)` to parent |
| `nimad_vue3/src/revamp/pages/pms/OtherPms.vue` | On successful PMS preference save | Emits `runTapfiliate(selectedPms)` to parent |
| `plugins_api/StripewebhookApiPlugin.js` | Stripe `invoice.payment_succeeded` webhook event | Calls `TapfilliateHelper.postConversion()` if user has affiliate and invoice is paid |
