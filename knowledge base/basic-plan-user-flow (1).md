# Basic Plan — User Flow

## Overview

The Basic plan is the entry-level paid subscription. It covers automatic review collection, direct review requests, and widget display for up to 19 properties. AI features, bulk imports, analytics, and data exports are not included and require an upgrade to Business or Business AI.

---

## Plan Limits

| Limit | Value |
|-------|-------|
| Maximum properties | 19 |
| Review history | Unlimited (stored forever) |
| AI response generation | Not included |
| Sentiment analytics | Not included |
| Bulk property / review import | Not included |
| Data export (CSV / Excel) | Not included |

---

## Pricing

| Properties | Monthly | Yearly |
|------------|---------|--------|
| 1 | €5 / mo | €45 / yr |
| 2–4 | €7 / mo | €63 / yr |
| 5–9 | €11 / mo | €99 / yr |
| 10–19 | €19 / mo | €171 / yr |

Yearly plans include a 25% discount. Supported currencies: EUR, USD, GBP.

---

## Registration & Trial

1. User registers with email and password.
2. A **trial period** begins automatically — during the trial the user has access to all features regardless of plan.
3. When the trial expires the user must select and pay for a plan to retain access.
4. Selecting Basic unlocks the features listed below.

---

## Full User Journey

### Step 1 — Onboarding

After registration the user is prompted to go through Quick Start:

- **Quick Start with Airbnb** — enter an Airbnb host profile URL to bulk-import all properties in one step. The user can skip this and add properties manually instead.

See [Quick Start documentation](./quick-start.md) for the full flow.

---

### Step 2 — Adding Properties

- Navigate to **Properties → New property**.
- Enter a property name and optionally add review source URLs (Airbnb, Booking, TripAdvisor, VRBO, Expedia, Google, Trustpilot).
- Each source URL is scraped periodically and new reviews are pulled automatically.
- The Basic plan allows up to **19 properties**.

**At the 20th property:** an upgrade modal is shown and the account is automatically moved to the Business plan before the property is created.

---

### Step 3 — Collecting Reviews

Reviews are collected automatically from connected sources. No manual action is needed after a source URL is added. The user can also:

- **Request reviews directly** — share a property-specific review request link with guests. Guests fill in a form (name, email, title, content, star rating, date of stay) and the review is stored in Revyoos.
- **View all reviews** — filter by property, source, date range, rating, or answered/unanswered status.
- **Export reviews** — not available on Basic. Requires Business plan with yearly billing.

---

### Step 4 — Review Management

Basic plan users can read and manage reviews but have limited response tooling:

| Action | Available |
|--------|-----------|
| View reviews | Yes |
| Filter reviews | Yes |
| Manually write a response | Yes |
| AI-generated response | No — Business plan required |
| Translate review | No — Business plan required |
| Export reviews to CSV / Excel | No — Business plan + yearly required |

When a Basic user attempts to use AI response generation or translation, an upgrade prompt is shown redirecting to `/account/subscription`.

---

### Step 5 — Widgets

Basic plan users can embed review widgets on their website:

| Widget type | Available |
|-------------|-----------|
| Property widget — displays reviews for a single property | Yes |
| Global widget — displays all reviews across all properties | Yes |
| Custom widget | Yes |
| Widget colour customisation | Yes |
| Sort by date or rating | Yes |
| Rich snippets (star ratings in Google search results) | No — Business plan required |

Widget embed codes and URLs are managed under **Widgets** in the sidebar.

---

### Step 6 — SEO Pages

Each user gets a public SEO profile page hosted on the Revyoos domain. Basic plan users get the standard page. Customisation (custom domain, branding, description) is available on all plans via **SEO Pages** in the sidebar.

---

### Step 7 — Account & Billing

- **Account information** — update name, email, company details, phone, website.
- **Password change** — available at any time.
- **Subscription management** — view current plan, upgrade, cancel, apply discount codes, and access billing portal for invoices.
- **PMS connection** — connect a Property Management System (Hostaway, Guesty, Hostfully) to sync properties automatically.
- **Delete account** — permanently removes all data.

---

## What Is Locked on Basic

The following features show an upgrade prompt when accessed:

| Feature | Minimum plan required |
|---------|-----------------------|
| AI response generation | Business |
| AI review translation | Business |
| Bulk property import (CSV / Excel) | Business |
| Bulk review import | Business |
| Review & property export (CSV / Excel) | Business (yearly billing) |
| Owner Reviews (NPS tool) | Business |
| Rich snippets for widgets | Business |
| Sentiment analytics | Business AI |
| Property quarterly summaries | Business AI |
| Company AI summary | Business AI |

---

## Upgrade Triggers

The following actions prompt the user to upgrade:

| Trigger | Behaviour |
|---------|-----------|
| Adding a 20th property | Auto-upgrade modal shown; account moved to Business |
| Restoring recycled properties beyond limit | Upgrade plan confirmation modal |
| Clicking AI response / translate | Redirect to subscription page |
| Clicking bulk import | Upgrade modal |
| Trial expiry with no paid plan | Trial expired modal blocks access until plan is selected |

---

## Sidebar Navigation (Basic Plan)

| Section | Items visible |
|---------|--------------|
| Dashboard | Sentiment analytics overview (view only, no filters) |
| Properties | My properties, New property, Import properties (locked) |
| Reviews | All reviews, Import reviews (locked), Request form |
| Widgets | Global widget, Property widget, Custom widget |
| SEO Pages | SEO profile settings |
| My Account | Account info, Subscription, PMS connection, Affiliate |

---

## Plan Detection Logic

The plan type is extracted from the Stripe plan nickname using the format:

```
{plan}_{interval}_{properties}
```

Example: `basic_monthly_10` → Basic plan, monthly billing, up to 10 properties.

The `subscribed()` middleware on the server splits the nickname on `_` and checks the first segment against the required plan list. Trial users bypass all plan checks until `date_end_trial` passes.
