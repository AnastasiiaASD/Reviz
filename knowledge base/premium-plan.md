# Premium Plan

## Overview

The Premium plan is a **legacy subscription tier** available only to users who registered before November 24, 2022 and have an active Premium subscription. It is not offered to new users. In terms of included features it is equivalent to the Basic plan but supports up to 99 properties instead of 19.

Users on Premium are encouraged to upgrade to Business to unlock advanced features, or to stay on Premium if their property count and feature needs are met.

---

## Eligibility

| Condition | Premium available |
|-----------|------------------|
| Registered before November 24, 2022 with active Premium subscription | Yes |
| Registered after November 24, 2022 | No — Basic is the entry plan |
| Active subscription cancelled | No |
| More than 99 properties | No — must upgrade to Business |

---

## Plan Limits

| Limit | Value |
|-------|-------|
| Maximum properties | 99 |
| Review history | Unlimited (stored forever) |
| AI response generation | Not included |
| Sentiment analytics | Not included |
| Bulk property / review import | Not included |
| Data export (CSV / Excel) | Yearly billing only |

---

## Pricing

| Properties | Monthly | Yearly |
|------------|---------|--------|
| 1 | €5 / mo | €45 / yr |
| 2–4 | €7 / mo | €63 / yr |
| 5–9 | €11 / mo | €99 / yr |
| 10–19 | €19 / mo | €171 / yr |
| 20–29 | €25 / mo | €225 / yr |
| 30–49 | €39 / mo | €351 / yr |
| 50–69 | €49 / mo | €441 / yr |
| 70–99 | €55 / mo | €495 / yr |

Yearly plans include a 25% discount. Supported currencies: EUR, USD, GBP.

---

## Included Features

| Feature | Included |
|---------|----------|
| Automatic review collection (Airbnb, Booking, VRBO, Expedia, TripAdvisor, Google) | Yes |
| Direct review request form (multilingual) | Yes |
| Property review widget | Yes |
| Global review widget (all properties) | Yes |
| Custom widget | Yes |
| Widget colour customisation and sorting | Yes |
| Dashboard with permanent review storage | Yes |
| Basic SEO profile page | Yes |
| Data export to CSV / Excel | Yearly billing only |
| API connection for custom reports | Yearly billing only |

---

## Locked Features

The following require an upgrade to Business or Business AI:

| Feature | Minimum plan required |
|---------|-----------------------|
| AI response generation (ChatGPT) | Business |
| AI review translation | Business |
| Bulk property import (CSV / Excel) | Business |
| Bulk review import | Business |
| Owner Reviews (NPS tool) | Business |
| Rich snippets for widgets (Google star ratings) | Business |
| Customisable SEO pages | Business |
| Sentiment analytics | Business AI |
| Property quarterly summaries | Business AI |
| Company AI summary | Business AI |

---

## How Premium Differs from Basic and Business

| | Basic | Premium | Business |
|--|-------|---------|----------|
| Max properties | 19 | 99 | Unlimited tiers |
| Availability | All users | Legacy only (pre Nov 2022) | All users |
| AI responses | No | No | Yes |
| Bulk import | No | No | Yes |
| Owner Reviews | No | No | Yes |
| Rich snippets | No | No | Yes |
| Sentiment analytics | No | No | Business AI only |
| Included features | Same as Premium | Same as Basic | All above |

Premium sits between Basic and Business in property capacity but shares the same feature set as Basic — it does not unlock any additional features compared to Basic.

---

## Upgrade & Downgrade Paths

### Upgrading from Premium

Premium users who need more properties or advanced features can upgrade to Business or Business AI at any time. Charges are prorated for mid-cycle upgrades.

An upgrade prompt is shown on the subscription page:

> *"Upgrade to the Business Plan for just €X more per year and unlock all the advanced features."*

### Forced upgrade

If a Premium user's property count reaches 100, the Premium plan is disabled and they must move to Business.

### Cancellation

Cancelling a Premium subscription ends access at the end of the current billing period. The plan cannot be reactivated after cancellation if the user was registered after November 24, 2022.

---

## Plan Detection

The plan type is extracted from the Stripe plan nickname using the format:

```
{plan}_{interval}_{properties}_ppt
```

Example: `premium_monthly_99_ppt` → Premium plan, monthly billing, up to 99 properties.

The server middleware splits the nickname on `_` and reads the first segment. Trial users bypass all plan checks until `date_end_trial` passes.
