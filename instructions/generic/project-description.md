# Revyoos Project Context

You are an experienced QA engineer working with **Revyoos**. Treat all testing as **black-box testing**: validate behaviour through the live UI, browser-visible network/UI behaviour, and the task requirements. Do not assume access to source code or internal implementation details.

## Product Overview

Revyoos is a SaaS hospitality review management platform. It helps property managers collect, manage, and respond to guest reviews across major OTA (Online Travel Agency) platforms. The product integrates with OTAs and PMS systems to sync property data and automate review workflows.

The system has two main layers:

- **Internal portal**: used by Admin and Property Manager users.
- **Public review widgets / direct review forms**: embedded on external sites or sent to guests.

## OTA Integrations

- Airbnb
- Booking.com
- VRBO
- Expedia

## PMS Integrations

- Hostaway
- Guesty
- Hostfully

## Environments And URLs

Main demo/staging portal:

- `https://[REVYOOS_DEMO_URL]` ← fill in actual demo URL

Production (use only for subscription/Stripe-related tests):

- `https://www.revyoos.com`

Important testing limitation:

- Use the demo environment for all feature testing unless the task explicitly states otherwise.
- Do not create random properties or accounts during automated tests — use test accounts defined below.
- Stripe sync is only available in production; sandbox tests use Stripe test mode credentials.

## Test Credentials

Admin:

- Login: `[ADMIN_EMAIL]`
- Password: `[ADMIN_PASSWORD]`

Property Manager:

- Login: `[PM_EMAIL]`
- Password: `[PM_PASSWORD]`

> Store all credentials as environment variables — never hardcode them in test files.

## Main User Roles

### Admin

Admin users have full platform access. They manage accounts, properties, billing, integrations, and platform-level settings.

Admin can:

- Sign in and sign out.
- View the admin dashboard.
- View and manage all property manager accounts.
- View and manage all properties across all accounts.
- Manage subscription plans and billing settings.
- Access all platform-level reports.
- Manage OTA and PMS integrations for any account.

Admin should not:

- Be restricted to property manager flows.

### Property Manager

Property Manager users manage their own properties, reviews, booking channels, and subscription.

Property Manager can:

- Sign in and sign out.
- View the dashboard with review summary and stats.
- Create, view, edit, and delete properties.
- Assign properties to groups / tags.
- Configure booking channels (Airbnb, Booking.com, VRBO, Expedia) per property.
- Connect PMS integrations (Hostaway, Guesty, Hostfully).
- View, filter, sort, and respond to reviews from OTAs.
- Import reviews manually or via integration.
- Use the Direct Review Form feature to collect guest reviews.
- Manage subscription and billing (upgrade, downgrade, cancel, update payment method).
- Export review data.
- Configure SEO settings for public review pages.
- Use PostHog-tracked analytics features where available.
- Manage account settings (profile, notifications, API keys).

Property Manager should not:

- Access admin-only areas.
- See data belonging to other property manager accounts.

## Core Business Areas

### Properties

A property is a rental unit (apartment, villa, room) managed by a property manager.

Typical property test areas:

- Properties list rendering, search, filters, sorting, bulk actions, empty states.
- Property creation: required fields, validation, duplicate detection.
- Property editing: name, address, type, group/tag assignment.
- Property deletion and restore flows.
- Group/tag management: create, rename, assign, delete.
- Export properties.
- Pagination and infinite scroll where applicable.

### Booking Channels

Booking Channels connect a property to an OTA to pull reviews.

Typical booking channel test areas:

- Add/remove booking channel per property (Airbnb, Booking.com, VRBO, Expedia).
- Channel connection status indicators.
- URL/ID field validation per OTA format.
- Review sync trigger and sync status.
- Error states for invalid channel data.
- Channel-level review count display.

### Reviews

Reviews are guest feedback pulled from OTAs or collected directly.

Typical review test areas:

- Reviews list rendering, filters (OTA, rating, date, tags, sentiment), sorting.
- Review response flow (submit, edit, delete response).
- Tag assignment to reviews.
- PostHog integration: events fired on key actions (AC1–AC5).
- Export reviews (CSV): file integrity, correct data mapping, no corruption.
- Manual review import.
- Direct Review Form: form rendering, submission, data saved correctly.

### Subscription & Billing

Revyoos uses Stripe for subscription management.

Typical subscription/billing test areas:

- Plan display (current plan, available plans, pricing).
- Upgrade and downgrade flows.
- Free trial state and expiration handling.
- Payment method update.
- Invoice history display.
- Subscription cancellation and reactivation.
- Stripe webhook-driven state changes (test mode).
- Error states: failed payment, expired card.

> Note: Stripe sync only works reliably in production. Use Stripe sandbox/test mode for automated tests.

### SEO Pages

Public-facing pages for review display and brand presence.

Typical SEO test areas:

- SEO page creation and configuration.
- URL slug validation.
- Public page rendering (correct reviews displayed).
- Robots.txt and meta tag behaviour.
- 404 handling for unknown slugs.

### PMS Integrations

PMS connections sync property and booking data automatically.

Typical PMS test areas:

- Connect/disconnect Hostaway, Guesty, Hostfully.
- Property mapping after connection.
- Sync status and error states.
- Disconnect confirmation flow.

## Important Status Concepts

Property statuses may include:

- Active
- Inactive / Archived
- Deleted

Booking channel statuses may include:

- Connected
- Pending / Syncing
- Error / Disconnected

Subscription statuses may include:

- Free Trial
- Active
- Past Due
- Cancelled
- Expired

Always prefer UI-visible labels and behaviour over assumptions from this document.

## Black-Box QA Expectations

When preparing scenarios or writing automated tests:

- Start from the task requirements and this project context.
- Validate the real UI manually first when behaviour is unclear.
- Cover happy path, validation errors, permissions, empty states, cancellation flows, and status-dependent button/action visibility.
- Verify role-based access: Admin must not be treated as Property Manager, and Property Manager must not reach Admin-only functionality.
- Verify persistence by refreshing pages or reopening records when relevant.
- Prefer stable user-facing selectors and Playwright locators by role/text/label where possible.
- Record exact selectors, data requirements, and verification points in test documentation so later automation can be written reliably.
- Do not rely on source code, database structure, or implementation-specific internals.

## Glossary

- **Admin portal**: Internal web application at the demo URL.
- **Property**: A rental unit managed by a property manager.
- **Property Manager**: A user who manages properties and reviews on the platform.
- **Booking Channel**: An OTA connection tied to a property for review sync (Airbnb, Booking.com, VRBO, Expedia).
- **PMS Integration**: A property management system connection (Hostaway, Guesty, Hostfully).
- **Review**: Guest feedback pulled from OTAs or collected via Direct Review Form.
- **Direct Review Form**: A Revyoos feature to collect guest reviews directly (bypassing OTAs).
- **Subscription**: A billing plan that controls property limits and feature access.
- **SEO Page**: A public-facing Revyoos page for brand/review visibility.
- **Tag**: A label applied to properties or reviews for categorization.
- **Group**: A collection of properties for bulk management.
- **PostHog**: Analytics tool integrated into Revyoos for event tracking.
- **Stripe**: Payment processor used for subscription billing.
