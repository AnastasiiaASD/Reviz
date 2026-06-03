<!-- Sources read:
  api/client/billing/billing.routes.js
  api/client/billing/billing.controller.js (via summary)
  api/client/billing/billing.service.js (via summary)
  api/client/users/users.routes.js
  nimad_vue3/src/revamp/pages/ManageSubscription.vue
  nimad_vue3/src/revamp/pages/PaymentStatus.vue
  nimad_vue3/src/revamp/pages/subscription/PlanCards.vue
  nimad_vue3/src/revamp/pages/subscription/BillingSummary.vue
  nimad_vue3/src/revamp/pages/subscription/BillingInfoForm.vue
  nimad_vue3/src/revamp/helpers/pricing.js
  plugins_api/StripewebhookApiPlugin.js
-->

# Subscription & Billing

## Overview

The Manage Subscription page (`/account/subscription`) lets users select a plan (Basic, Business, or Business AI), choose a billing period (monthly or yearly), set a property tier, apply discount codes, and proceed through a Stripe-powered checkout. Existing active subscribers upgrade in-place via proration; new subscribers are sent to a Stripe Checkout Session. Stripe lifecycle events are handled server-side via a webhook endpoint to keep billing and user records in sync.

---

## User Flow

### Manage Subscription page (`/account/subscription`)

1. User navigates to `/account/subscription`.
2. Page title: **"Manage Subscription"**. Subtitle: **"Choose a plan that fits your needs and manage your billing details."**
3. Page loads four resources in parallel: current user, pricing, exchange rates, and current subscription.
4. The page has a two-column layout: left for configuration, right for the sticky **Billing Summary** card.

**Section 1 — Select your base plan:**

- Heading: **"Select your base plan"**. Description: _"Customize your plan and enjoy the advantages adapted to your business."_
- Period toggle: **Monthly** / **Yearly** (badge: **"Save 25%"**).
- Currency toggle: **EUR** / **USD** / **GBP** (display-only conversion; billing is always in EUR).
- Three plan cards (radio-style):

| Plan key | Label | Description | Max properties |
|---|---|---|---|
| `basic` | Basic | _"The essential toolkit for businesses growing up."_ | 19 |
| `business` | Business | _"The full-featured platform built for big property managers."_ | 2,999 |
| `businessAi` | Business AI | _"The future of property management: Smart, Intelligent, and Insightful."_ | 2,999 |

- Basic plan card is disabled (`opacity-40`, `pointer-events-none`, `grayscale`) when selected properties > 19.
- Each card shows the per-month price from the API (yearly total ÷ 12 for yearly period).
- **"What's included in [Plan]"** list expands below the cards with feature bullets.

Features per plan:

- **Basic:** Automatic review collection, Direct review request, Global review widget, Property review widget, Widget customization, Dashboard, SEO Pages, Up to 19 properties.
- **Business:** Everything in Basic + Owner Reviews, Rich Snippets for widgets (SEO), Massive property upload, Review upload, Excel / CSV Backup, API connection (On demand), AI responses with ChatGPT, Browser Extension for Airbnb, Up to 2,999 properties.
- **Business AI:** Everything in Business + Sentiment Analytics with AI, Understand emotions behind every review, Spot trends in customer satisfaction, Improve property based on real feedback, Deep understanding, not just averages.

**Section 2 — Number of properties:**

- Heading: **"Number of properties"**. Description: _"Select how many properties you need to manage."_
- Dropdown of property tiers. Tiers for Basic: 1–19. Tiers for Business/BusinessAi: 1–2,999.
- Tier key format and labels:

| Tier key | Display label |
|---|---|
| 1 | 1 |
| 4 | 2–4 |
| 9 | 5–9 |
| 19 | 10–19 |
| 29 | 20–29 |
| 49 | 30–49 |
| 69 | 50–69 |
| 99 | 70–99 |
| 149 | 100–149 |
| 199 | 150–199 |
| 299 | 200–299 |
| 499 | 300–499 |
| 749 | 500–749 |
| 999 | 750–999 |
| 1249 | 1,000–1,249 |
| 1499 | 1,250–1,499 |
| 1749 | 1,500–1,749 |
| 1999 | 1,750–1,999 |
| 2249 | 2,000–2,249 |
| 2499 | 2,250–2,499 |
| 2749 | 2,500–2,749 |
| 2999 | 2,750–2,999 |

- Text: _"More than 3,000?"_ + link **"Contact us"**.
- When the selected plan changes, the property tier is auto-adjusted to the nearest tier ≥ current selection.

**Section 3 — Billing information:**

- Heading: **"Billing information"**. Description: _"Your tax details for accurate invoice generation."_
- Fields: **Business Name** (text input), **Tax Country** (dropdown).
- If the selected country is an EU country (excluding Canary Islands): **Tax ID / VAT** input (disabled when noVat is checked) + **"I don't have a VAT number"** checkbox. When checkbox is ticked: **National ID** input replaces the VAT field.
- If the selected country is non-EU: _"No Tax ID/VAT number needed for your country."_
- Save button: calls `PUT /api/users` with billing fields. On success emits `billing-saved` which triggers a fresh billing summary fetch.
- The **"Proceed to checkout"** / **"Update subscription"** button in the Billing Summary is disabled until `taxCountry` is saved (`hasBillingInfo` check).

**Section 4 — Discount Code:**

- Heading: **"Discount Code"**. Description: _"Have a coupon? Apply it here for a discount on your plan."_
- Text input with **"Apply"** button. On apply: calls `POST /api/users/discount-code`. On success: `toast.success('Coupon applied successfully!')`. On error: `toast.error(resp.message || 'Invalid coupon code.')`.

---

### Billing Summary card (right column, sticky)

- Heading: **"Billing Summary"**.
- **Current plan selected state:** if the selection matches the active plan, period, and properties, shows: _"This is your current plan."_
- **Invoice breakdown** (when a priced plan is selected):
  - Plan line: e.g. `Business (yearly)` — amount.
  - Unused time proration (negative lines): **"Unused time on previous subscription"** — shown in green as a credit.
  - Coupon discount (if applied): `"Coupon (N% off)"` — amount in green. **"Remove coupon"** link below.
  - Tax (exclusive): **"Tax"** — amount.
  - Tax (inclusive): **"Tax (included)"** — amount.
  - **"Total due today"** — large bold amount.
- Prices displayed in selected currency (USD/GBP converted from EUR using ECB rates).
- Footer note: _"Prices shown in [currency] (converted from EUR)."_ / _"Prices shown in EUR."_
- Warning banner (amber) if user's property count exceeds the selected tier: _"The selected plan only allows up to N properties (your account has N properties)."_
- **Checkout button:**
  - Label when active subscriber: **"Update subscription"** / while processing: **"Updating your subscription..."**
  - Label when no subscription: **"Proceed to checkout"** / while processing: **"Opening secure checkout..."**
  - Disabled when: billing info not saved, no price selected, property count exceeds tier, or summary is loading.
  - If active subscriber: calls `PUT /api/users/subscription` → on success redirects to `/payment/success`.
  - If no subscription: calls `POST /api/users/subscription` → receives `session.url` → redirects browser to Stripe Checkout.
- Footer: _"Powered by Stripe"_.

---

### Payment Success page (`/payment/success`)

- Full-screen centered card.
- Green checkmark icon.
- Heading: **"Plan updated!"**
- Text: _"Your subscription has been successfully updated. You now have full access to your plan."_
- Button: **"Back to My Account"** → navigates to `/account`.
- On mount: refetches current user to update the store (non-blocking).

---

### Payment Error / Cancelled page (`/payment/error`)

- Full-screen centered card.
- Amber alert icon.
- Heading: **"Checkout cancelled"**
- Message: from `?message=` query param (URL-decoded) or default: _"The checkout was not completed. No charges were made."_
- Additional text: _"You can try again with a different payment method or contact support if you need help."_
- Button: **"Back to Manage Subscription"** → navigates to `/account/subscription`.

---

## Price nickname format

Price nicknames stored in Stripe follow the pattern:

```
{plan}_{period}_{tier}_ppt
```

Examples: `business_yearly_49_ppt`, `businessAi_monthly_1_ppt`, `basic_yearly_19_ppt`.

The `parsePlanId` helper splits on `_` to extract plan, period, and properties from a subscription's nickname.

---

## Access Control

| Action | Requirement |
|---|---|
| View Manage Subscription page | Authenticated (`requiresAuth: true`). |
| Get pricing (public) | **No authentication.** |
| Get exchange rates (public) | **No authentication.** |
| Get user-specific pricing | Authenticated (Bearer JWT). |
| Get billing summary (upcoming invoice preview) | Authenticated (Bearer JWT). |
| Create subscription (Checkout Session) | Authenticated (Bearer JWT). |
| Update subscription (in-place upgrade) | Authenticated (Bearer JWT). |
| Get subscription status | Authenticated (Bearer JWT). |
| Cancel subscription | Authenticated (Bearer JWT). |
| Get billing portal / invoices | Authenticated (Bearer JWT). |
| Apply discount code | Authenticated (Bearer JWT). |
| Remove discount code | Authenticated (Bearer JWT). |
| View Payment Success/Error pages | **No authentication** (public routes). |
| Stripe webhook endpoint | **No authentication** — verified by Stripe signature. |

---

## API Endpoints

---

### `GET /api/billing/pricing`

Get available Stripe plan prices. No authentication required.

**Auth:** None.

**Response:**

```json
{
  "success": true,
  "data": {
    "prices": [
      {
        "id": "price_xxx",
        "nickname": "business_yearly_49_ppt",
        "amount": 19900,
        "currency": "eur",
        "interval": "year"
      }
    ]
  }
}
```

`amount` is in cents. Fetched from the Stripe product identified by the `STRIPE_PRODUCT_2026` environment variable.

---

### `GET /api/billing/rates`

Get current EUR-based exchange rates for display-only currency conversion.

**Auth:** None.

**Response:**

```json
{
  "success": true,
  "data": {
    "rates": {
      "EUR": 1,
      "USD": 1.08,
      "GBP": 0.86
    }
  }
}
```

Rates are fetched from `https://www.revyoos.com/ecbRates.json`. EUR is appended as `1`.

---

### `GET /api/users/pricing`

Get plan prices for the authenticated user. For existing subscribers on a legacy Stripe product, their current plan's prices are replaced with the legacy prices to preserve their grandfathered rate.

**Auth:** Bearer JWT (authenticated).

**Response:** Same structure as `GET /api/billing/pricing`.

---

### `GET /api/users/billing`

Get the upcoming invoice preview for a given price ID (used to populate the Billing Summary card).

**Auth:** Bearer JWT (authenticated).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `priceId` | string | Yes | Stripe price ID to preview. |

**Response:**

```json
{
  "success": true,
  "data": {
    "invoice": {
      "amount_due": 19900,
      "lines": {
        "data": [
          { "amount": 24900, "description": "Business yearly plan" },
          { "amount": -5000, "description": "Unused time on previous subscription" }
        ]
      },
      "total_tax_amounts": [],
      "total_discount_amounts": [],
      "discount": null
    }
  }
}
```

`amount_due` is in cents. If the user has an active subscription, proration lines appear in `lines.data`.

---

### `POST /api/users/subscription`

Create a Stripe Checkout Session for a new subscription.

**Auth:** Bearer JWT (authenticated).

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `priceId` | string | Yes | Stripe price ID for the selected plan/period/tier. |

**Server behaviour:**
- Creates a Stripe Checkout Session.
- `success_url`: `${BASE_URL}/clients/#/payment/success`.
- `cancel_url`: `${BASE_URL}/clients/#/payment/error`.
- `payment_method_types`: `['card', 'sepa_debit']`.
- `billing_address_collection`: `required`.
- Automatic tax enabled.
- Phone number collection enabled.

**Response (success):**

```json
{
  "success": true,
  "data": {
    "session": {
      "url": "https://checkout.stripe.com/pay/cs_xxx"
    }
  }
}
```

Frontend redirects the browser to `session.url`.

---

### `PUT /api/users/subscription`

Upgrade or change an existing active subscription in-place (no new checkout session).

**Auth:** Bearer JWT (authenticated).

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `priceId` | string | Yes | Stripe price ID for the new plan/period/tier. |

**Server behaviour:** Updates the Stripe subscription with `billing_cycle_anchor: 'now'` and `proration_behavior: 'create_prorations'`.

**Response (success):**

```json
{
  "success": true,
  "data": { "subscription": { /* Stripe subscription object */ } }
}
```

Frontend navigates to `/payment/success` on success.

---

### `GET /api/users/subscription`

Get the user's current Stripe subscription(s).

**Auth:** Bearer JWT (authenticated).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `statuses` | string | No | Comma-separated Stripe subscription statuses to filter (e.g. `active,past_due`). |

**Response:**

```json
{
  "success": true,
  "data": {
    "subscription": [
      {
        "id": "sub_xxx",
        "status": "active",
        "cancel_at_period_end": false,
        "current_period_end": 1780000000,
        "items": {
          "data": [
            {
              "price": {
                "nickname": "business_yearly_49_ppt",
                "amount": 19900
              }
            }
          ]
        },
        "discount": {
          "promotion_code": { "code": "WELCOME20" }
        }
      }
    ]
  }
}
```

---

### `POST /api/users/subscription/cancel`

Schedule cancellation of the active subscription at the end of the current billing period (`cancel_at_period_end: true`).

**Auth:** Bearer JWT (authenticated).

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `reason` | string | Yes | Enum: `service`, `widgets`, `difficult`, `expensive`, `errors`, `need`, `other`. |
| `text` | string | Yes | Min 2 characters. Additional cancellation detail. |

**Server behaviour:**
1. Calls Stripe `cancelSubscription(subscription.id)` (sets `cancel_at_period_end`).
2. Saves `cancellationReason: { reason, text, date }` to user document.
3. Sends admin email titled **"Subscription Canceled"** with user details + reason.
4. Sends cancellation confirmation email to user.

**Response (success):**

```json
{
  "success": true,
  "message": "Subscription cancelled successfully"
}
```

---

### `GET /api/users/subscription/invoices`

Get a Stripe Billing Portal session URL so the user can view/download past invoices.

**Auth:** Bearer JWT (authenticated).

**Response:**

```json
{
  "success": true,
  "data": {
    "url": "https://billing.stripe.com/session/xxx"
  }
}
```

---

### `POST /api/users/discount-code`

Apply a promotion/coupon code to the user's Stripe customer.

**Auth:** Bearer JWT (authenticated).

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `code` | string | Yes | Promotion code string. |

**Server behaviour:** Validates promotion code via Stripe API, then applies it to the Stripe customer.

**Response (success):**

```json
{
  "success": true
}
```

On error (invalid code): error message from Stripe.

---

### `DELETE /api/users/discount-code`

Remove the active coupon/discount from the user's Stripe subscription and customer.

**Auth:** Bearer JWT (authenticated).

**Response (success):**

```json
{
  "success": true
}
```

---

### Stripe Webhook (legacy endpoint)

Handles Stripe lifecycle events. Endpoint verifies the Stripe webhook signature via `stripeHelper.constructWebhookEvent()`.

**Auth:** None — Stripe signature verification only.

Handled event types:

| Event | Behaviour |
|---|---|
| `customer.subscription.created` | Creates or updates a `BillingsM` record (status `active`). Updates user: `o_plan`, `date_plan`, `b_active_subscription: true`, clears `stripeError` and `unpaid`. Syncs to Zoho. |
| `customer.subscription.updated` | Same as created. If `cancel_at_period_end` is true, sets `canceledSubscriptionEnd` on user. If plan changed, marks old billing record `cancelled` and creates a new one. |
| `customer.subscription.deleted` | Marks billing record `cancelled`. Sets user `b_active_subscription: false`, clears `date_plan`. Syncs to Zoho. |
| `invoice.payment_succeeded` | If user has an affiliate (`o_affiliate_complete.id`) and invoice is paid and amount > 0: posts a Tapfiliate conversion with `external_id = invoice.id` and `amount = invoice.amount_paid / 100`. |
| `invoice.payment_failed` | Sets `stripeError: { errorMessage: 'Payment failed' }` and `unpaid: true` on user. Syncs to Zoho with note `"Payment failed"`. |
| `checkout.session.completed` | Extracts billing address and phone from `customer_details`. Updates user `o_company` fields (address, city, country, province, zip), `taxCountry`, `phoneNumber`, `phoneNumberCountry`. |

Nickname format parsed by webhook: `{planType}_{planPeriod}_{planPropertiesCount}_{planPpt}` — split on `_`.

---

## Smart Pricing for Existing Subscribers

When `GET /api/users/pricing` is called for a user who has an active subscription on a **legacy Stripe product** (not `STRIPE_PRODUCT_2026`), the billing service replaces the prices for that user's current plan with their legacy prices. This preserves grandfathered rates: the user sees their actual price for their current plan, while new plan options show the current 2026 prices.

---

## Components

| File | Route | Purpose |
|---|---|---|
| `nimad_vue3/src/revamp/pages/ManageSubscription.vue` | `/account/subscription` | Main subscription page shell — loads pricing, rates, subscription data; orchestrates plan/period/tier/currency selection; debounced billing summary fetch on selection change. |
| `nimad_vue3/src/revamp/pages/subscription/PlanCards.vue` | (sub-component) | Plan selector — 3 plan cards, period toggle (Monthly / Yearly with "Save 25%" badge), currency toggle (EUR / USD / GBP), feature list for selected plan. |
| `nimad_vue3/src/revamp/pages/subscription/BillingInfoForm.vue` | (sub-component) | Billing information form — Business Name, Tax Country, VAT / National ID (EU logic), "I don't have a VAT number" checkbox. Saves via `PUT /api/users`. |
| `nimad_vue3/src/revamp/pages/subscription/BillingSummary.vue` | (sub-component) | Sticky right-column card — invoice breakdown (proration, coupon, tax), "Total due today", checkout/update button, coupon remove link. |
| `nimad_vue3/src/revamp/pages/PaymentStatus.vue` | `/payment/success`, `/payment/error` | Post-checkout status page — success: "Plan updated!" + "Back to My Account"; error/cancel: "Checkout cancelled" + error message from `?message=` param. |
| `nimad_vue3/src/revamp/helpers/pricing.js` | (shared helper) | Plan metadata (labels, descriptions, features, max tiers), property tier key/label maps, `parsePlanId`, `findPrice`, `convertCurrency`, `CURRENCY_SYMBOLS`. |
| `plugins_api/StripewebhookApiPlugin.js` | (webhook handler) | Stripe webhook listener — handles subscription created/updated/deleted, invoice payment succeeded/failed, and checkout session completed events. |
