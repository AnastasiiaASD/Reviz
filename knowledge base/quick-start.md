# Quick Start — Airbnb Property Import

## Overview

Quick Start is an onboarding wizard that lets users bulk-import all their Airbnb properties into Revyoos in a single step by providing their Airbnb host profile URL. It is available as a first-run onboarding step and as a persistent section in the sidebar.

---

## User Flow

### Step 1 — Add Profile

The user lands here either during account creation (first-run) or by navigating to Quick Start.

1. Enter the URL of their Airbnb host profile.
   - Must match: `airbnb.com/users/show/<id>` or `airbnb.com/users/profile/<id>`
   - Any invalid URL shows: *"This URL is not valid."*
2. Give the profile a name (required).
3. Click **Add profile** — the profile is staged locally (multiple can be queued).
4. Click **Import profiles** to submit all staged profiles to the API.
5. On success, a green confirmation banner appears: *"The properties are being imported. You'll receive an email when done."*
6. Users can skip this step during onboarding via *"Skip for now."*

> **Finding the profile URL** — a help modal triggered by *"Where to find the link to my Airbnb profile?"* shows a GIF and 5-step instructions:
> 1. Open any of your listings on Airbnb.
> 2. Scroll down to the host information card.
> 3. Click on the host card.
> 4. Your Host profile page will open.
> 5. Copy the URL from your browser's address bar.

---

### Step 2 — Profile Dashboard

After profiles are submitted, users are redirected to the dashboard which shows:

| Column | Description |
|--------|-------------|
| Profile name | Name the user gave the profile |
| Profile URL | Link to the Airbnb profile |
| Status | `In process` (spinner, polls every 5 sec) / `Imported <date>` / `Import error` |
| Properties | Count of imported properties (shown when status = Imported) |
| View properties | Expands property list below the table |

Clicking **View properties** shows a paginated table (100 per page) of property names and URLs for that profile.

---

## Access Control

| Action | Requirement |
|--------|-------------|
| View Quick Start / profiles list | Authenticated |
| Add a new profile (import) | Active subscription or trial |
| Export properties | Active subscription or trial + business plan |

- If the user has no active plan and clicks **Import profile**, a *No Plan* modal is shown.
- If the user has exceeded their property limit, an *Exceeding Import* modal is shown with the remaining slots.
- The **Import profile** button is only shown if all existing holdings came from a profile import (i.e. the user has no manually-added properties).

---

## API Endpoints

### `GET /api/profiles`

Returns the list of Airbnb profiles for the authenticated user.

**Auth:** `Bearer <token>`

**Response:**
```json
{
  "payload": [
    {
      "_id": "string",
      "profileName": "string",
      "profileUrl": "string",
      "profileType": "airbnb",
      "status": 0,
      "propertiesList": [
        { "propertyName": "string", "propertyUrl": "string" }
      ],
      "createdAt": "ISO8601"
    }
  ]
}
```

**Status values:**

| Value | Meaning |
|-------|---------|
| `0` | Import in progress |
| `1` | Import complete |
| `-1` | Import error |

---

### `POST /api/profiles`

Creates one or more Airbnb profiles to import.

**Auth:** `Bearer <token>`  
**Plan:** Any active subscription or trial

**Request body:**
```json
[
  {
    "profileName": "My Airbnb",
    "profileUrl": "https://www.airbnb.com/users/show/12345678",
    "profileType": "airbnb"
  }
]
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `profileName` | string (min 1, trimmed) | Yes | Display name for the profile |
| `profileUrl` | string (valid URL) | Yes | Airbnb host profile URL |
| `profileType` | `"airbnb"` | Yes | Profile source type |

---

### `GET /api/profiles/export`

Exports all profile properties to CSV or Excel.

**Auth:** `Bearer <token>`  
**Plan:** Any active subscription or trial

**Query parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `format` | `csv` \| `xlsx` | `csv` | Export file format |

---

## Components

| File | Route | Purpose |
|------|-------|---------|
| `res/src/components/quickStartAirbnb/AddProfilePage.vue` | `/create-profile` | Profile URL input form |
| `res/src/components/quickStartAirbnb/QuickStartPage.vue` | `/quick-start` | Profile dashboard |
| `res/src/components/quickStartAirbnb/FindLinkModal.vue` | (modal) | Help modal for finding Airbnb profile URL |
