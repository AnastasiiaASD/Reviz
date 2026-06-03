<!-- Sources read:
  nimad_vue3/src/revamp/pages/Account.vue
  nimad_vue3/src/revamp/pages/account/AccountInfoCard.vue
  nimad_vue3/src/revamp/pages/account/ChangePasswordCard.vue
  nimad_vue3/src/revamp/pages/account/DangerZoneCard.vue
  nimad_vue3/src/revamp/pages/account/SubscriptionCard.vue
  nimad_vue3/src/revamp/pages/Preferences.vue
  nimad_vue3/src/revamp/helpers/validation.js (accountSchema, accountChangePasswordSchema, PASSWORD_RULES)
  api/client/users/users.routes.js
  api/client/users/users.validation.js
-->

# Account Settings

## Overview

The Account section (`/account`) lets authenticated users manage their personal and billing information, change their password, view their subscription status, and permanently delete their account. The Preferences page (`/preferences`) manages AI response defaults and notification opt-ins. Both pages save to the user record via `PUT /api/users`.

---

## User Flow

### Account (`/account`)

Page title: **"Account"**. Subtitle: **"Manage your account information and subscription."**

The page loads the current user via `GET /api/users/me` on mount. A right-hand sticky nav links to four sections: **Subscription**, **Account Info**, **Change Password**, **Delete Account**.

---

#### Subscription card

Displays the current subscription state in one of three modes:

**Trial** (`status === 'Trial'`):
- Section heading: **"Free Trial"**.
- Description: _"You have access to all Business AI plan features during your trial."_
- Badge: days remaining (green ≥8 days, amber ≤7 days, red ≤3 days): `"N day[s] left"`.
- Progress bar showing elapsed trial period (trial start → trial end dates).
- Property count: `"N propert[y|ies]"`.
- Urgency banner when ≤5 days left: _"Your trial ends on [date]. Subscribe now to keep your SEO page, widgets, and review management active."_
- Button: **"Upgrade Now"** → navigates to `/account/subscription`.

**Active** (`status === 'active'`):
- Section heading: **"[Plan Name] Plan"** (plan names: `Basic`, `Business`, `Business AI`).
- Billing label: `"[Yearly|Monthly] · [€/$/£ amount][/yr|/mo]"`.
- Status badge: **"Active"** (green) or **"Ending Soon"** (amber) when `cancel_at_period_end` is true.
- Optional discount badge: `"N% off"` (purple).
- Line: `"Since: [date] · Next invoice: [date]"` (or `"Expires:"` when canceling).
- Auto-renewal indicator: **"Auto-renewal on"** (green pulse) / **"Auto-renewal off"** (amber pulse).
- Property Usage progress bar: `"N / M (K left)"`.
- Buttons: **"Manage"** → `/account/subscription`; **"Invoices"** → opens Stripe billing portal in a new tab via `GET /api/users/subscription/invoices`.
- **"Cancel Subscription"** link — opens a two-step dialog (see below). Hidden when subscription is already canceling.
- Canceling warning banner: _"Your plan expires on [date]. Reactivate to continue enjoying premium features."_

**Inactive / Expired**:
- Section heading: **"No Active Plan"**.
- Status badge: e.g. `"Inactive"`, `"canceled"`.
- Description: _"Subscribe to unlock all premium features and start managing your properties"_.
- Button: **"Choose Plan"** → `/account/subscription`.

**Cancel Subscription dialog** (two-step):

Step 1 — **"We're sorry to see you go..."** — reason survey (checkboxes, same options as Delete Account):
- **"I found a better service"** (with free-text input if selected)
- **"I could not manage to install the widgets"**
- **"Too difficult to setup"**
- **"Too expensive"**
- **"Too many errors"**
- **"I don't need it anymore, I've sold the business."**
- **"Other"** (with textarea if selected)
- Buttons: **"I've changed my mind"** (closes) / **"Continue to Cancel"** (→ step 2).

Step 2 — **"Are you sure?"**:
- _"You will continue to have access to all features until [renewalDate]."_
- _"After this date, your subscription will end and your account will be limited: your widgets will stop displaying, reviews will no longer sync, and property updates will be disabled."_
- Buttons: **"Keep my Plan"** (closes) / **"Confirm Cancellation"** (destructive). While canceling: **"Cancelling..."**. On success: `toast.success('Your subscription has been cancelled.')`.

---

#### Account Info card — section heading: **"Personal Information"** + **"Billing Information"**

**Personal Information:**

| Field | Required | Validation |
|---|---|---|
| **Name** | Yes | Min 2 characters (`name_user`). |
| **Email** | — | Read-only display. Cannot be changed from this form. |
| **Website** | Yes | Valid URL pattern. Min 5 characters. |

**Billing Information:**

| Field | Required | Notes |
|---|---|---|
| **Business name** | Yes | Min 2 characters (`o_company.name_com`). |
| **Tax Country** | No | Dropdown from country list (`taxCountry`). |
| **Tax ID / VAT** | No | Disabled when "I don't have a VAT number" is checked (`o_company.cif_com`). Min 9 characters on server. |
| **National ID** | No | Enabled only when "I don't have a VAT number" is checked (`nationalTaxNumber`). |
| **"I don't have a VAT number"** checkbox | — | Toggles VAT/National ID fields. Sets `usingNationalTaxNumber`. |
| **Address** | No | Min 5 characters on server (`o_company.address_com`). |
| **Country** | No | Dropdown from country list (`o_company.country_com`). |
| **ZIP / Postal Code** | No | Min 5 characters on server (`o_company.zip_com`). |
| **Province** | No | Min 2 characters on server (`o_company.province_com`). |
| **City** | No | Min 2 characters on server (`o_company.city_com`). |
| **Phone** | No | `PhoneInput` component: country-code prefix dropdown + number field. Number min 6 digits if provided; prefix required if number provided. |

Buttons: **"Save Changes"** (disabled when unchanged or saving) / **"Discard"**.
- On save success: `toast.success('Account information saved.')`.
- On save error: `toast.error(getApiError(err, 'Failed to save account information.'))`.

---

#### Change Password card — section heading: **"Change Password"**

Description: _"Update your password to keep your account secure"_.

Three password fields (each with a show/hide toggle):
- **Current Password**
- **New Password**
- **Confirm New Password**

Password requirements (shown inline with green/red per-rule indicators):
- 8 characters
- 1 lowercase
- 1 uppercase
- 1 number
- 1 special character

Button: **"Update Password"**. While sending: **"Updating..."**. On success: `toast.success('Password updated successfully!')`. On error: `toast.error(getApiError(err, 'Failed to update password. Please try again.'))`.

---

#### Danger Zone card — section heading: **"Danger Zone"**

Description: _"Irreversible and destructive actions. Proceed with caution."_

Row: **"Delete Account"** — _"Permanently delete your account and all associated data. This action cannot be undone."_

Button: **"Delete Account"** (destructive) — opens a two-step dialog:

Step 1 — **"We're sorry to see you go..."** — reason survey (checkboxes):
- **"I found a better service"** (with free-text input on selection)
- **"I could not manage to install the widgets"**
- **"Too difficult to setup"**
- **"Too expensive"**
- **"Too many errors"**
- **"I don't need it anymore, I've sold the business."**
- **"Other"** (with textarea on selection)
- Buttons: **"I've changed my mind"** (closes dialog) / **"Continue to Cancel"** (→ step 2).

Step 2 — **"Wait! This is a permanent action."** with three warnings:
- **"Subscription & Billing:"** _"Your subscription will be cancelled immediately. Please note we cannot provide refunds for any remaining unused time."_
- **"Data Erasure:"** _"All your configurations and historical data will be permanently wiped."_
- **"Zero Access:"** _"You will be instantly logged out and lose all ability to recover your account or its information."_
- Buttons: **"Cancel"** (→ step 1) / **"Permanently Delete Account"** (destructive). While deleting: **"Deleting..."**.
- On success: `toast.success('Your account has been deleted.')` → user store cleared → redirect to `/login`.
- On error: inline error message in the dialog.

Backend reason mapping from frontend key to API enum:

| UI label | Backend enum value |
|---|---|
| I found a better service | `service` |
| I could not manage to install the widgets | `widgets` |
| Too difficult to setup | `difficult` |
| Too expensive | `expensive` |
| Too many errors | `errors` |
| I don't need it anymore, I've sold the business. | `need` |
| Other | `other` |

---

### Preferences (`/preferences`)

Page title: **"Preferences"**. Subtitle: **"Manage your account settings and configuration."**

Footer: unsaved-changes indicator dot + **"Discard"** / **"Save Changes"** buttons. Changes dirty state tracked against initial snapshot. On save success: `toast.success('Preferences saved.')`. On error: `toast.error(getApiError(err, 'Failed to save preferences.'))`.

**AI Response Settings card:**
- Section heading: **"AI Response Settings"**. Description: _"Configure how the AI generates responses for your guests."_

| Field | Type | Default | Description |
|---|---|---|---|
| **Output Language** | Dropdown (AI_LANGUAGES, 100+ options) | `English (USA)` | Language for AI response drafts and review translations. Mapped to `chatSettings.language`. |
| **Tone** | Dropdown | `Formal` | Options: `Formal`, `Informal`. Mapped to `chatSettings.tone`. |
| **Nuance** | Dropdown | `Neutral` | Options: `Neutral`, `Empathetic`, `Apologetic`, `Inviting`, `Solution Oriented`, `Reassuring`, `Enthusiastic`. Mapped to `chatSettings.nuance`. |
| **Include Guest Name** | Toggle | On (`true`) | Personalize responses with the guest's name. `chatSettings.isUsingGuestName`. |
| **Include Property Name** | Toggle | On (`true`) | Reference the property in AI responses. `chatSettings.isUsingPropertyName`. |
| **Include Signature** | Toggle | Off (`false`) | Append a custom signature to all responses. `chatSettings.isUsingSignature`. |
| **Signature** textarea | Text | `""` | `placeholder='Enter your signature, e.g. "Warm regards, The Grand Oak Team"'`. `chatSettings.signature`. |

**Notification Settings card:**
- Section heading: **"Notification Settings"**. Description: _"Choose which notifications you'd like to receive"_.

| Toggle | Default | Field | Description shown |
|---|---|---|---|
| **System Updates** | On | `system_notify` | _"Receive important system updates, successful property imports, action confirmations, and critical communications."_ |
| **New Reviews** | On | `new_reviews_notify` | _"Receive new updates for new reviews on your properties."_ |
| **Promotions** | On | `promotions_notify` | _"Occasional tips, offers and platform news"_ |

---

## Access Control

| Action | Requirement |
|---|---|
| View `/account` | Authenticated (`requiresAuth: true`). |
| View `/preferences` | Authenticated (`requiresAuth: true`). |
| Update account info | Authenticated (Bearer JWT). |
| Change password | Authenticated (Bearer JWT). |
| Delete account | Authenticated (Bearer JWT). |
| Get subscription | Authenticated (Bearer JWT). |
| Cancel subscription | Authenticated (Bearer JWT). |
| Open billing portal (invoices) | Authenticated (Bearer JWT). |

---

## API Endpoints

All endpoints are mounted at `/api/users`.

---

### `GET /api/users/me`

Fetch the authenticated user's full profile.

**Auth:** Bearer JWT (authenticated).

**Response (success):**

```json
{
  "success": true,
  "data": {
    "user": { "/* full user document */" }
  }
}
```

---

### `PUT /api/users`

Update user profile fields (account info, chat settings, notification preferences, PMS preference).

**Auth:** Bearer JWT (authenticated).

**Request body** (all fields optional):

| Field | Type | Validation | Description |
|---|---|---|---|
| `name_user` | string | Min 2 characters | Personal name. |
| `email_user` | string | Valid email | Email address. |
| `website` | string | Min 5 characters | Website URL. |
| `taxCountry` | string | — | Tax country. |
| `nationalTaxNumber` | string | — | National ID number. |
| `usingNationalTaxNumber` | boolean | — | Toggle VAT / national ID mode. |
| `phoneNumber` | string | Min 7 characters | Phone number digits. |
| `phoneNumberCountry` | string | Min 2 characters | Phone country code prefix. |
| `o_company.name_com` | string | Min 2 characters | Business name. |
| `o_company.address_com` | string | Min 5 characters | Business address. |
| `o_company.zip_com` | string | Min 5 characters | ZIP code. |
| `o_company.city_com` | string | Min 2 characters | City. |
| `o_company.province_com` | string | Min 2 characters | Province. |
| `o_company.country_com` | string | Min 2 characters | Country. |
| `o_company.cif_com` | string | Min 9 characters | Tax ID / VAT. |
| `chatSettings` | object | — | AI response defaults (any keys). |
| `system_notify` | boolean | — | System update emails. |
| `new_reviews_notify` | boolean | — | New review emails. |
| `promotions_notify` | boolean | — | Promotional emails. |
| `pmsData` | object | id min 2, otherPmsName min 2 | PMS preference. |
| `is_using_hostfully_website` | boolean | — | Hostfully website preference. |
| `registrationStep` | `0` or `1` | — | Registration flow step. |

**Response (success):**

```json
{
  "success": true,
  "data": {
    "user": { "/* updated user document */" }
  }
}
```

---

### `PUT /api/users/password-change`

Change the user's password.

**Auth:** Bearer JWT (authenticated).

**Request body:**

| Field | Type | Required | Validation |
|---|---|---|---|
| `oldPassword` | string | Yes | Any non-empty string. |
| `newPassword` | string | Yes | Min 8 chars, at least 1 uppercase, at least 1 digit. |

**Response (success):**

```json
{ "success": true }
```

---

### `POST /api/users/delete`

Permanently delete the authenticated user's account and all associated data.

**Auth:** Bearer JWT (authenticated).

**Request body:**

| Field | Type | Required | Validation |
|---|---|---|---|
| `reason` | string | No | Enum: `service`, `widgets`, `difficult`, `expensive`, `errors`, `need`, `other`. |
| `text` | string | No | Min 2 characters. Free-text elaboration. |

**Response (success):**

```json
{ "success": true }
```

---

### `GET /api/users/subscription`

Fetch the user's Stripe subscription(s).

**Auth:** Bearer JWT (authenticated).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `status` | string | No | Filter by subscription status. Allowed: `active`, `trialing`, `incomplete`, `incomplete_expired`, `past_due`, `canceled`, `unpaid`, `paused`, `all`. Default: `all`. |
| `limit` | integer | No | 1–100. |

**Response (success):**

```json
{
  "success": true,
  "data": {
    "subscription": [
      {
        "id": "sub_xxx",
        "status": "active",
        "current_period_end": 1750000000,
        "cancel_at_period_end": false,
        "plan": { "nickname": "business-monthly-25", "amount": 2900, "currency": "eur", "interval": "month" },
        "discount": { "coupon": { "name": "SUMMER20", "percent_off": 20 } }
      }
    ]
  }
}
```

---

### `POST /api/users/subscription/cancel`

Cancel the user's active Stripe subscription at the end of the current billing period.

**Auth:** Bearer JWT (authenticated).

**Request body:** Same schema as `POST /api/users/delete` (optional `reason` + `text`).

**Response (success):**

```json
{ "success": true }
```

---

### `GET /api/users/subscription/invoices`

Open a Stripe billing portal session to view invoices and payment history.

**Auth:** Bearer JWT (authenticated).

**Response (success):**

```json
{
  "success": true,
  "data": {
    "session": {
      "url": "https://billing.stripe.com/session/..."
    }
  }
}
```

---

## Components

| File | Route | Purpose |
|---|---|---|
| `nimad_vue3/src/revamp/pages/Account.vue` | `/account` | Shell — loads user, provides scroll navigation between four section cards. |
| `nimad_vue3/src/revamp/pages/account/SubscriptionCard.vue` | (section) | Subscription status display (Trial / Active / Inactive); cancel subscription two-step dialog; Invoices Stripe portal; navigate to `/account/subscription`. |
| `nimad_vue3/src/revamp/pages/account/AccountInfoCard.vue` | (section) | Personal info (name, website) + billing info (business name, address, VAT/national ID, phone) form; saves via `PUT /api/users`. |
| `nimad_vue3/src/revamp/pages/account/ChangePasswordCard.vue` | (section) | Current/new/confirm password fields with per-rule indicator; saves via `PUT /api/users/password-change`. |
| `nimad_vue3/src/revamp/pages/account/DangerZoneCard.vue` | (section) | Delete Account two-step dialog with reason survey; calls `POST /api/users/delete`; clears user store and redirects to `/login`. |
| `nimad_vue3/src/revamp/pages/Preferences.vue` | `/preferences` | AI Response Settings (language, tone, nuance, guest name, property name, signature) + Notification Settings toggles; saves all via `PUT /api/users`. |
