# Trial Period

## Overview

Every new user automatically receives a **15-day free trial** starting at the moment of registration. No credit card is required. During the trial the user has access to all features across all plan tiers. When the trial expires, access is restricted until the user subscribes to a paid plan.

---

## Trial Duration

| Field | Value |
|-------|-------|
| Length | 15 days |
| Start | Registration date (`date_start_trial`) |
| End | Registration date + 15 days (`date_end_trial`) |
| Extension | Admin can manually extend via the admin panel |

---

## Feature Access During Trial

Trial users bypass all subscription plan checks on the server. This means they have access to every feature regardless of what plan they would eventually purchase.

| Feature | Available during trial |
|---------|----------------------|
| Review collection (all channels) | Yes |
| Direct review request form | Yes |
| Property and global widgets | Yes |
| Widget customisation | Yes |
| SEO profile pages (full customisation) | Yes |
| Owner Reviews (NPS tool) | Yes |
| Bulk property import | Yes |
| Bulk review import | Yes |
| Data export (CSV / Excel) | Yes |
| AI response generation | Yes |
| AI review translation | Yes |
| Sentiment analytics | Yes |
| Property quarterly summaries | Yes |
| Company AI summary | Yes |
| PMS connection | Yes |
| API connection | Yes |

---

## Trial UI States

### Active trial — more than 7 days remaining

No alert is shown. The user works normally with full access.

### Active trial — fewer than 7 days remaining

A banner is shown in the header:

> *"Your trial will end in X days. Upgrade now to keep access."*

Two action buttons are shown: **Upgrade now** (goes to `/account/subscription`) and **Book a Demo**.

### Trial expired — no paid plan

A full-screen modal blocks the dashboard:

> *"Your trial has expired. Please upgrade to continue."*

The modal lists the features that will be restored on upgrade:
- Full Visibility — reactivate all Widgets and SEO Pages
- Automated Sync — restore PMS and booking channel connections
- Massive Management — keep using Bulk Import / Export

An **Upgrade now** button navigates to `/account/subscription`.

### Subscription cancelled (post-trial)

A separate header alert is shown when a paid subscription is cancelled but the billing period has not yet ended:

> *"Your subscription period is ending on [DATE]."*

This is distinct from trial expiry — the user retains access until the period end date.

---

## Trial Countdown

The header shows a countdown computed from `date_end_trial`:

| Days remaining | Message shown |
|----------------|---------------|
| > 1 day | "in X days" |
| Exactly 1 day | "in 1 day" |
| < 24 hours | "in less than 24 hours" |
| 0 / past | Trial expired state |

A progress indicator tracks how far through the 15-day period the user is (from 3% on day one to 100% on the last day).

---

## Trial Expiry Processing

A scheduled background job runs **daily** to find users whose trial ends that day. At the exact expiry time it syncs the user's status with the CRM (Zoho) and updates internal flags. No automated emails or access changes are triggered by the job itself — access gates are evaluated in real time on each request using `date_end_trial`.

---

## Server-Side Trial Check

In the authentication middleware, trial status is evaluated on every protected request:

```
if date_end_trial > now → bypass all subscription plan checks → allow access
```

This means a trial user is never blocked by plan-level guards (`subscribed()`) for the duration of the trial, regardless of which features they try to use.

---

## Trial vs Paid Subscription

| State | Access |
|-------|--------|
| Trial active, no subscription | Full access to all features |
| Trial active, subscription also active | Subscription takes precedence; access controlled by plan |
| Trial expired, no subscription | Blocked — upgrade modal shown |
| Trial expired, subscription active | Access controlled by subscription plan |
| Subscription cancelled, within billing period | Access retained until period end date |
| Subscription cancelled, past billing period | Blocked — same as expired trial |

---

## Admin Trial Management

Administrators can manually adjust `date_end_trial` on any user account via the admin panel (Nimad). This is used for:

- Customer support cases
- Extended evaluations or special promotions

There is no automated extension logic — all extensions are applied manually.

---

## Registration Flow

1. User submits email and password.
2. Account is created. `date_start_trial` is set to now; `date_end_trial` is set to now + 15 days.
3. User is directed through a multi-step onboarding (company info → PMS connection → Quick Start).
4. Trial begins immediately — no confirmation or credit card required.
