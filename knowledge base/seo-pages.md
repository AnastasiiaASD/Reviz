# SEO Pages

## Overview

SEO Pages is a publicly accessible company profile page automatically generated for each Revyoos user. It aggregates all reviews, ratings, and property information into a single branded page hosted on the Revyoos domain. The page is server-side rendered and includes Schema.org structured data for Google rich snippets. Users configure the page content via **SEO Pages** in the sidebar.

---

## Public URL Structure

| Page | URL | Description |
|------|-----|-------------|
| Company overview | `https://revyoos.com/reviews/{customUrl}` | Main profile — reviews, rating, company info |
| Properties list | `https://revyoos.com/reviews/{customUrl}/property-list` | All properties with per-property ratings |
| Property detail | `https://revyoos.com/reviews/{customUrl}/{propertyId}` | Reviews for a single property |

`{customUrl}` is the slug the user sets in SEO settings. It can only contain letters, numbers, and hyphens (max 100 characters).

---

## Plan Access

| Feature | Trial | Basic / Premium | Business / Business AI |
|---------|-------|-----------------|------------------------|
| Publish SEO page | Yes | Yes | Yes |
| Custom URL slug | Yes | Yes | Yes |
| Company name (custom) | No | No | Yes |
| Description (250 chars) | No | No | Yes |
| Logo upload | No | No | Yes |
| Address (custom / visible) | No | No | Yes |
| Email (custom / visible) | No | No | Yes |
| Phone | Yes | Yes | Yes |
| Website | Yes | Yes | Yes |
| Social media links | Yes | Yes | Yes |
| Rich snippets (Google star ratings) | No | No | Yes |

Users registered before June 2022 automatically receive Business-level SEO features.

---

## Configurable Fields

### Publishing

| Field | Type | Description |
|-------|------|-------------|
| `isProfilePublished` | boolean | Toggles the page live. Requires active trial or paid subscription. |
| `url` | string (max 100, alphanumeric + hyphens) | Custom URL slug. Must be unique across all users. |

### Company Identity

| Field | Type | Constraints | Plan |
|-------|------|------------|------|
| `companyName` | string | max 100 chars | Business |
| `isDifferentName` | boolean | Use a different name from billing | Business |
| `description` | string | max 250 chars | Business |
| `imageUrl` | string | Logo filename (set via logo upload endpoint) | Business |

### Contact Information

| Field | Type | Constraints | Plan |
|-------|------|-------------|------|
| `website` | string | max 200 chars | All |
| `phone` | string | max 30 chars | All |
| `email` | string (email or empty) | — | Business |
| `isDifferentEmail` | boolean | Use a different email from account | Business |
| `emailVisible` | boolean | Show email on public page | Business |
| `address` | string | max 200 chars | Business |
| `city` | string | max 100 chars | Business |
| `zipCode` | string | max 20 chars | Business |
| `country` | string | max 100 chars | Business |
| `isDifferentAddress` | boolean | Use a different address from billing | Business |
| `addressVisible` | boolean | Show address on public page | Business |

### Social Media

| Field | Type | Validation | Plan |
|-------|------|------------|------|
| `linkedIn` | string (URL or empty) | Must start with `http://` or `https://` | All |
| `twitter` | string (URL or empty) | Must start with `http://` or `https://` | All |
| `facebook` | string (URL or empty) | Must start with `http://` or `https://` | All |
| `instagram` | string (URL or empty) | Must start with `http://` or `https://` | All |
| `youtube` | string (URL or empty) | Must start with `http://` or `https://` | All |

---

## Logo Upload

| Property | Value |
|----------|-------|
| Accepted formats | PNG, JPG |
| Max file size | 2 MB (server) / 1 MB (client-side validation) |
| Min dimensions | 512 × 512 px |
| Storage path | `/images/{public_key}.{ext}` |

The client validates image dimensions before uploading. Only one logo is stored per user — uploading a new one replaces the previous file.

---

## What Appears on the Public Page

### Company overview page (`/reviews/{url}`)

- Company logo (if uploaded and on Business plan)
- Company name
- Overall star rating and total review count
- Description
- Contact information (website, phone, email, address) — only fields marked visible
- Social media links
- 5 most recent reviews (paginated), each showing:
  - Source platform with icon
  - Reviewer name and date
  - Star rating
  - Review title and content
  - Owner response (if saved)
  - Link to source platform or property

### Properties list (`/reviews/{url}/property-list`)

- List of all properties (10 per page)
- Per-property average rating
- OTA (platform) distribution per property

### Property detail (`/reviews/{url}/{propertyId}`)

- Property name and rating
- Star distribution for that property
- OTA breakdown for that property
- All reviews for that property

---

## Schema.org Structured Data

All three pages include JSON-LD markup for:

- `Organization` — Revyoos
- `LocalBusiness` — Company profile
- `AggregateRating` — Overall star rating and review count
- `WebPage` — Page metadata
- `BreadcrumbList` — Navigation hierarchy
- `ImageObject` — Logo metadata

This structured data enables Google to show star ratings directly in search results (rich snippets). Rich snippets are only active on **Business and Business AI** plans.

---

## API Endpoints

All endpoints require `Bearer <token>` authentication.

---

### `GET /api/seo`

Retrieve the authenticated user's SEO page data.

**Response:**
```json
{
  "isProfilePublished": true,
  "url": "my-company",
  "companyName": "My Company",
  "description": "We manage vacation rentals across Spain.",
  "imageUrl": "abc123.png",
  "website": "https://mycompany.com",
  "phone": "+34 600 000 000",
  "email": "hello@mycompany.com",
  "emailVisible": true,
  "address": "Calle Mayor 1",
  "city": "Madrid",
  "zipCode": "28001",
  "country": "Spain",
  "addressVisible": false,
  "linkedIn": "",
  "twitter": "https://twitter.com/mycompany",
  "facebook": "",
  "instagram": "https://instagram.com/mycompany",
  "youtube": ""
}
```

---

### `PUT /api/seo`

Update SEO page settings. All fields are optional.

**Auth:** `Bearer <token>`

**Request body:**

| Field | Type | Constraints |
|-------|------|-------------|
| `isProfilePublished` | boolean | — |
| `url` | string | Alphanumeric + hyphens, max 100 |
| `isDifferentName` | boolean | — |
| `companyName` | string | max 100 |
| `description` | string | max 250 |
| `isDifferentAddress` | boolean | — |
| `addressVisible` | boolean | — |
| `address` | string | max 200 |
| `city` | string | max 100 |
| `country` | string | max 100 |
| `zipCode` | string | max 20 |
| `isDifferentEmail` | boolean | — |
| `emailVisible` | boolean | — |
| `email` | string (email or `""`) | — |
| `website` | string | max 200 |
| `phone` | string | max 30 |
| `linkedIn` | string (URL or `""`) | — |
| `twitter` | string (URL or `""`) | — |
| `facebook` | string (URL or `""`) | — |
| `instagram` | string (URL or `""`) | — |
| `youtube` | string (URL or `""`) | — |

**Response:**
```json
{ "success": true }
```

---

### `POST /api/seo/logo`

Upload a company logo. Sent as `multipart/form-data` with the file in the `image` field.

**Auth:** `Bearer <token>`  
**Plan:** Business or Business AI

**Constraints:** PNG or JPG, max 2 MB. Client enforces min 512 × 512 px before sending.

**Response:**
```json
{ "imageUrl": "abc123.png" }
```

---

### `DELETE /api/seo/logo`

Remove the company logo.

**Auth:** `Bearer <token>`

**Response:**
```json
{ "success": true }
```

---

## Components

| File | Purpose |
|------|---------|
| `res/src/components/seo/SeoSettings.vue` | Settings form with live preview (old Vue 2 dashboard) |
| `seo-vue3/src/pages/SeoPage.vue` | Public company overview page |
| `seo-vue3/src/pages/SeoPropertyList.vue` | Public properties list page |
| `seo-vue3/src/pages/SeoPropertyPage.vue` | Public individual property page |
| `seo-vue3/src/components/SeoLayout.vue` | Shared header and footer for public pages |
| `seo-vue3/src/components/ReviewCard.vue` | Review card used on public pages |
| `seo-vue3/renderers/SeoPageRenderer.cjs` | SSR renderer for company overview |
| `seo-vue3/renderers/SeoPropertyListRenderer.cjs` | SSR renderer for properties list |
| `seo-vue3/renderers/SeoPropertyPageRenderer.cjs` | SSR renderer for property detail |
