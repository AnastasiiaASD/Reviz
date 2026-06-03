<!-- Sources read:
  nimad_vue3/src/revamp/pages/Widgets.vue
  nimad_vue3/src/revamp/pages/PropertyWidgets.vue
  nimad_vue3/src/revamp/pages/WidgetCustomize.vue
  nimad_vue3/src/revamp/pages/widgetCustomize/constants.js
  nimad_vue3/src/revamp/pages/widgetCustomize/TemplateTab.vue
  nimad_vue3/src/revamp/pages/widgetCustomize/InstallTab.vue
  api/client/widgets/widgets.routes.js
  api/client/widgets/widgets.validation.js
  api/client/widgets/urls/urls.routes.js
  api/client/widgets/urls/urls.validation.js
  api/client/widgets/embed/embed.routes.js
  api/client/widgets/embed/embed.validation.js
  nimad_vue3/src/revamp/router/index.js
-->

# Widgets

## Overview

Widgets are embeddable review displays for customer websites. There are three widget types: **Global** (one per account, shows reviews from all properties), **Property** (one shared design applied per-property, each property gets its own embed code), and **Custom** (user-created, each targets a custom selection of properties). The `/widgets` dashboard manages Global and Custom widgets; `/widgets/property` manages Property Widgets and their URL assignments. The `WidgetCustomize` page is shared by all three types for design, reviews configuration, and embed code generation.

---

## User Flow

### Widgets Dashboard (`/widgets`)

1. User navigates to `/widgets`.
2. Page title: **"Widgets"**. Subtitle: **"Manage your review widgets"**.
3. Two sections are shown:

**Global Widget section:**
- Section heading: **"Global Widget"**. Description: **"Your account widget to display reviews from ALL properties."**
- Shows the current template thumbnail, template name and display mode (e.g. `"Horizontal Tab (Floating)"`), title (from `widgetV2.global.widgetTitle` or company name), and source channel icons.
- Two action buttons:
  - **"Configure Design"** — navigates to `/widgets/global/customize`.
  - **"Install"** — navigates to `/widgets/global/customize?tab=install`.

**Custom Widgets section:**
- Section heading: **"Custom Widgets"**. Description: **"Create individual widgets to combine reviews from specific properties or groups."**
- A **"New Widget"** button opens the **"Create Custom Widget"** dialog.
  - Field: **Widget Name** (required, max 255 characters). Error shown inline if save fails.
  - Buttons: **"Cancel"** / **"Create and Edit"** — on success, navigates directly to `/widgets/custom/:id/customize`. On failure: inline error message.
- Empty state: **"No custom widgets yet"** + description.
- Custom widgets are displayed in a card grid. Each card shows: template thumbnail, template name, display mode, widget name, title, property scope label (e.g. `"All"`, `"All (12)"`, or property count), and source channel icons.
- Card actions (bottom row):
  - **Configure Design** (palette icon) — navigates to `/widgets/custom/:id/customize`.
  - **Get Code** (code tags icon) — navigates to `/widgets/custom/:id/customize?tab=install`.
  - ⋮ dropdown menu:
    - **"Edit name"** — opens **"Edit Name"** dialog. Field: **Widget Name** (required). Button: **"Save Changes"** (disabled if name unchanged). On success: `toast.success('Widget renamed')`. On error: inline error message.
    - **"Delete"** — opens **"Delete Widget"** dialog. Text: _"Are you sure you want to delete "[name]"? This action will remove the widget from all websites where it is currently installed. This cannot be undone."_ Buttons: **"Cancel"** / **"Delete Widget"** (destructive). On success: `toast.success('Widget deleted')`. On error: `toast.error(...)`.

---

### Property Widgets (`/widgets/property`)

1. User navigates to `/widgets/property`.
2. Page title: **"Property Widgets"**. Parent breadcrumb: **"Widgets"** → `/widgets`.
3. Section heading: **"Property Widgets"**. Description: **"One shared widget for all properties."**
4. A shared settings card shows the current template and display mode with:
   - **"Configure Shared Design"** button → navigates to `/widgets/property/customize`.
   - **"Get Codes"** button → triggers CSV export of widget embed codes.
5. Below the shared card:
   - Count line: **"N Properties Widgets"**.
   - **"Import Links"** button → opens the **"Import Links"** dialog (see below).
   - **"Export Links"** button → opens the **"Export Links"** dialog.
6. A search field (`placeholder="Search properties..."`) filters the list client-side by property name.
7. An **"Exact Matching"** toggle: when enabled, the widget matches page URLs including query parameters. Toggling saves immediately via `PUT /api/widgets/settings`. On success: `toast.success('Exact matching enabled'|'Exact matching disabled')`.
8. Property list table shows columns: **Property** (name + review count) and **Website URL**.
   - If a URL is set: displayed as read-only text with extra URL count badge (e.g. `+2`). **"Edit"** button opens the **"Manage URLs"** dialog.
   - If no URL is set: **"No URL configured"** placeholder and **"Add"** button.
9. Paginated at 20 items per page.

**Manage URLs dialog** (title: **"Manage URLs"**):
- Description: _"Where should this widget appear on [Property Name]?"_
- Uses `ManageUrls` component with `widget-type="property"`. Saves URLs via `POST /api/widgets/urls`.

**Import Links dialog** (title: **"Import Links"**):
- Three-step instructions:
  1. _"Download the import template"_ — links to `/templates/import-url-template.xlsx` and `/templates/import-url-template.csv`.
  2. _"Complete the file"_ — columns: **Property name**, **URL 1**, **URL 2**, … Note: _"The property names in your file must match the names of properties in your account exactly. Rows with unmatched names will be skipped."_
  3. _"Upload the completed file"_ — file input (accepts `.csv`, `.xlsx`, `.xls`). File is read as base64 and sent to `POST /api/widgets/urls/import`. On success: `toast.success('URLs imported successfully')`. On error: inline error message.
- Buttons: **"Cancel"** / **"Import"** (disabled until a file is selected).

---

### Widget Customize (`/widgets/global/customize`, `/widgets/property/customize`, `/widgets/custom/:id/customize`)

All three widget types use the same `WidgetCustomize` page. The page title is `"Editing: [Global | Property | Custom] Widget"`.

The left panel contains four tabs:

**Template tab:**
- **Layout** section — 5 template options (radio-style cards):

| Template key | Label | Mode |
|---|---|---|
| `htab` | Horizontal Tab | Floating |
| `vtab` | Vertical Tab | Floating |
| `circle` | Circle | Floating |
| `embed` | Wall | Embedded |
| `slider` | Slider | Embedded |

- **Position** section (floating templates only) — 4 screen position options: `Center Left`, `Center Right`, `Bottom Left`, `Bottom Right`.
- **Jump Button** section (embedded templates only) — toggle to show a floating button that scrolls to the widget's position. When enabled: floating position picker with 4 options (`Center Left`, `Center Right`, `Bottom Left`, `Bottom Right`).

**Reviews tab:**
- Channel (OTA) filter — 8 checkboxes:

| Key | Label |
|---|---|
| `airbnb` | Airbnb |
| `booking` | Booking |
| `expedia` | Expedia |
| `tripadvisor` | Tripadvisor |
| `google` | Google |
| `trustpilot` | Trustpilot |
| `vrbo` | VRBO |
| `revyoos` | Other (Direct + Imported) |

- For **Custom** widgets: a property picker allowing include/exclude selection of specific properties.

**Design tab:**
- Widget title text input.
- Visibility toggles (show/hide per element):
  - Widget title, Global rating, Booking channels (header), Booking channel (review), Property name, Guest picture, Review date, Responses.

**Install tab:**
- Two installation methods:
  - **Universal** (Recommended) — _"Best for automatic updates and managing all your widget URLs directly from this dashboard."_
  - **Standalone** (Workaround) — _"Best for quick, independent installations that don't require the master script or URL rules."_
- The right panel switches to an `InstallStepsPanel` showing embed code/script instructions.
- **Match Query Params** toggle available on the install tab.

The right panel (non-install tabs) shows a live **"Preview [Global|Property|Custom] Widget"** that fetches data from `GET /api/widgets/data`.

Footer: unsaved-changes indicator dot + **"Discard"** / **"Publish Changes"** buttons.
- **"Discard"** resets settings to the last saved snapshot.
- **"Publish Changes"** calls `PUT /api/widgets/settings` (global/property) or `PUT /api/widgets/custom/:id/settings` (custom). On success: `toast.success('Widget saved')`. On failure: `toast.error(...)`.

Info banners (on template/reviews/design tabs):
- Global: _"This widget displays reviews from all your properties. Configure channels, template and design below."_
- Property: _"Template, design and channels configured here apply to all property widgets."_
- Custom: no banner.

---

## Access Control

| Action | Requirement |
|---|---|
| View widgets dashboard | Authenticated. |
| Create / rename / delete custom widget | Authenticated. |
| Save widget settings | Authenticated. |
| Manage widget URLs | Authenticated. |
| Import / export widget URLs | Authenticated. |
| Export property widget codes | Authenticated. |
| Serve widget embed script (`GET /api/widgets/embed`) | **No authentication** — public. |
| Fetch widget review data (`GET /api/widgets/data`) | **No authentication** — public. |

---

## API Endpoints

---

### `GET /api/widgets/custom`

Get all custom widgets for the authenticated user.

**Auth:** Bearer JWT (authenticated).

**Response:**

```json
{
  "success": true,
  "data": {
    "widgets": [
      {
        "_id": "wid123",
        "name": "Luxury Collection",
        "settings": { "template": "slider", "otas": [".ota-airbnb", ".ota-booking"] },
        "widgetTitle": "Our Guest Reviews",
        "selectedHoldings": ["hold1", "hold2"],
        "shouldExclude": "include",
        "holdingCount": 2,
        "isPublished": true
      }
    ]
  }
}
```

---

### `POST /api/widgets/custom`

Create a new custom widget.

**Auth:** Bearer JWT (authenticated).

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | Widget name. Min 1, max 255 characters. |
| `settings` | object | No | Initial settings object. |
| `isPublished` | boolean | No | Default: `true`. |
| `widgetTitle` | string | No | Display title. Max 255 characters. |
| `selectedHoldings` | array of strings | No | Property IDs. |
| `shouldExclude` | string | No | `include` or `exclude`. |

**Response (success):** HTTP 201. Returns the created widget object.

---

### `PUT /api/widgets/custom/:id`

Rename a custom widget.

**Auth:** Bearer JWT (authenticated).

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | Yes | New widget name. Min 1, max 255 characters. |

---

### `PUT /api/widgets/custom/:id/settings`

Save design/reviews/template settings for a custom widget.

**Auth:** Bearer JWT (authenticated).

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `settings` | object | Yes | Settings key-value map (template, otas, theme, visibility toggles, etc.). |
| `selectedHoldings` | array of strings | No | Property IDs to include/exclude. |
| `shouldExclude` | string | No | `include` or `exclude`. |
| `widgetTitle` | string | No | Display title. Max 255 characters. |

---

### `DELETE /api/widgets/custom/:id`

Delete a custom widget.

**Auth:** Bearer JWT (authenticated).

**Response (success):** `{ "success": true }`.

---

### `PUT /api/widgets/settings`

Save settings for the global or property widget (stored on the user document).

**Auth:** Bearer JWT (authenticated).

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | string | Yes | `global` or `property`. |
| `settings` | object | Yes | Settings key-value map. |

---

### `GET /api/widgets/property/export`

Export property widget embed codes as a downloadable file.

**Auth:** Bearer JWT (authenticated).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `format` | string | No | `csv` or `xls`. Default: `csv`. |
| `codeFormat` | string | No | `standalone` or `embed`. Default: `standalone`. |

**Response:** Binary file stream.

---

### `GET /api/widgets/urls`

Get the widget URL assignments for the authenticated user.

**Auth:** Bearer JWT (authenticated).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `type` | string | Yes | `global`, `property`, or `custom`. |
| `propertyId` | string | No | Filter to a single property. |

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "propertyId": "hold123",
      "urls": [
        { "url": "https://www.example.com/villa-1", "wholeSite": false },
        { "url": "https://www.example.com/villa-1-booking", "wholeSite": false }
      ]
    }
  ]
}
```

---

### `POST /api/widgets/urls`

Save URL assignments for a widget (replaces existing URLs for the given type/property).

**Auth:** Bearer JWT (authenticated).

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `type` | string | Yes | `global`, `property`, or `custom`. |
| `propertyId` | string | No | Target property `_id`. |
| `urls` | array of objects | No | Array of `{ url: string, wholeSite: boolean }`. |
| `url` | string | No | Single URL (alternative to `urls` array). |
| `id` | string | No | URL record ID for update. |

---

### `DELETE /api/widgets/urls/:id`

Delete a single widget URL record.

**Auth:** Bearer JWT (authenticated).

---

### `POST /api/widgets/urls/import`

Import widget URL assignments from a base64-encoded CSV or XLSX file.

**Auth:** Bearer JWT (authenticated).

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `fileData.fileContent` | string | Yes | Base64 data URL of the file. Min 1 character. |

File format: columns are **Property name**, **URL 1**, **URL 2**, … Rows with property names that do not exactly match existing properties are silently skipped.

---

### `GET /api/widgets/urls/export`

Export widget URL assignments as a downloadable file.

**Auth:** Bearer JWT (authenticated).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `format` | string | No | `csv` or `xlsx`. Default: `csv`. |

**Response:** Binary file stream.

---

### `GET /api/widgets/embed` (public)

Returns the widget JavaScript bundle or HTML snippet for embedding on customer websites. No authentication required.

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `token` | string | Yes | Base64-encoded JSON identifying the widget. Keys: `p` (holdingId), `u` (userId for universal), `g` (customWidgetId), `h` (userId for global). |
| `url` | string | Yes | The page URL where the widget is being loaded. Used for URL-matching. Max 2048 characters. |

---

### `GET /api/widgets/data` (public)

Returns review data for widget rendering. No authentication required. Used by the embed bundle and the in-app preview.

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `userId` | string | Yes | The account owner's user ID. |
| `holdingIds` | string | No | Comma-separated list of property IDs to filter reviews. |
| `source` | string | No | Comma-separated list of source channel types to filter. |
| `orderBy` | string | No | `date` or `rating`. |
| `page` | integer | No | Page number (positive integer). |
| `limit` | integer | No | Items per page. Max 50. |

---

## Widget Types Summary

| Type | Scope | Route | Shared design |
|---|---|---|---|
| Global | All user properties | `/widgets/global/customize` | Yes — one design for all properties |
| Property | Per-property | `/widgets/property/customize` | Yes — one shared design, separate embed code per property |
| Custom | User-defined selection | `/widgets/custom/:id/customize` | No — each custom widget has its own settings |

---

## Components

| File | Route | Purpose |
|---|---|---|
| `nimad_vue3/src/revamp/pages/Widgets.vue` | `/widgets` | Global Widget status + Custom Widgets grid; create/rename/delete custom widget dialogs. |
| `nimad_vue3/src/revamp/pages/PropertyWidgets.vue` | `/widgets/property` | Property Widget shared settings card; per-property URL management table; import/export URL dialogs; Exact Matching toggle. |
| `nimad_vue3/src/revamp/pages/WidgetCustomize.vue` | `/widgets/*/customize` | Shared customize shell for all three widget types — Template, Reviews, Design, Install tabs; live preview panel; Publish/Discard footer. |
| `nimad_vue3/src/revamp/pages/widgetCustomize/TemplateTab.vue` | (tab) | Layout picker (5 templates), floating position, jump button settings. |
| `nimad_vue3/src/revamp/pages/widgetCustomize/ReviewsTab.vue` | (tab) | Channel (OTA) checkboxes; property include/exclude picker for custom widgets. |
| `nimad_vue3/src/revamp/pages/widgetCustomize/DesignTab.vue` | (tab) | Widget title input and visibility toggles. |
| `nimad_vue3/src/revamp/pages/widgetCustomize/InstallTab.vue` | (tab) | Installation method selector (Universal / Standalone). |
| `nimad_vue3/src/revamp/pages/widgetCustomize/InstallStepsPanel.vue` | (panel) | Embed code/script display with Match Query Params toggle. |
