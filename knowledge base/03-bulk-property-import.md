<!-- Sources read:
  nimad_vue3/src/revamp/pages/PropertiesBulkImport.vue
  nimad_vue3/src/revamp/pages/properties/ImportProperties.vue
  nimad_vue3/src/revamp/pages/properties/ImportPropertiesHistory.vue
  api/client/holdings/import/holdingsImport.routes.js
  api/client/holdings/import/holdingsImport.controller.js
  api/client/holdings/import/holdingsImport.service.js
  api/client/holdings/import/holdingsImport.validation.js
  helpers/FileImportHelper.js
-->

# Bulk Property Import

## Overview

Bulk Property Import lets users upload a CSV or XLSX file to create multiple properties at once. Each file row becomes one property with optional booking channel URLs and group tags. The feature is gated to `business` and `businessAi` plan holders. An Import History tab tracks every previously uploaded file and allows re-download or deletion (which cascades to all properties, sources, and reviews from that file).

---

## User Flow

### Import Properties tab

1. User navigates to `/properties/import`.
2. If the user's plan is not `business` or `businessAi`, a **PayWall** component is shown and the rest of the page is hidden.
3. Two tabs are displayed: **"Import Properties"** and **"Import History"**.
4. The **"Import Properties"** tab is selected by default.
5. An accordion **"How to import properties"** is shown (expanded by default) with these instructions:
   - _"Download the CSV or XLSX template below."_
   - _"Each row must represent one property and include at least one booking channel link (e.g., Airbnb, Vrbo)."_
   - _"Property Groups (Optional): Locate the 'Groups' header to assign tags. Use the pipe symbol (|) as the internal delimiter. Example: Luxury|pet-friendly|pool"_
   - _"Upload the completed file and click 'Import'."_
6. Template download links for `import_properties_template.xlsx` and `import_properties_template.csv` are shown.
7. A file uploader component (`FileUploader`) accepts the file.
8. For non-trial users, after a file is selected, a **"Plan Capacity"** info banner may appear showing how many more properties the current plan allows and a **"View Pricing Plans"** button (links to `/account/subscription`). The banner text reads: _"With your current plan, you can import **N more propert[y/ies]** to your account. By proceeding with the import, you agree that your subscription will automatically scale to the next tier."_
9. User clicks **"Import"** (`data-testid="file-upload"`). Button shows **"Importing..."** while in progress.
10. The client reads the file using `FileReader.readAsDataURL()` and sends the resulting base64 string as `fileContent` along with the `fileName` to `POST /api/holdings/import`.
11. On response, the result summary is displayed inline (see Result States below).
12. On catch: an error block with title **"Import failed"** and the API error message is shown.

### Result States (inline, after import)

| Condition | Title shown | Notes |
|---|---|---|
| All rows imported, no errors, no skipped | `"N propert[y/ies] imported successfully."` | |
| All rows skipped (all duplicates), no errors | `"No new properties added."` | Description lists skipped property names. |
| Some imported, some skipped | `"Import complete with some issues."` | Description shows imported count; detail shows skipped count and names. |
| Some/all imported, some errors | `"N propert[y/ies] imported successfully."` or `"Import completed with errors."` | Per-property error messages shown. |

### Import History tab

1. User clicks **"Import History"** tab.
2. A yellow warning banner always displays: **"By removing a file, you will remove all the imported properties as well."**
3. A table **"Imported Files"** shows past uploads with columns: **#**, **Imported File**, **Date Imported**, **Properties**, **Actions**.
4. Empty state: **"No files found."**
5. Each row shows the file name, date, property count, and two action buttons: **Download** and **Delete**.
6. **Download**: calls `GET /api/holdings/import/:fileId/download` — returns the original uploaded file. File is saved locally as `import_properties.<ext>`.
7. **Delete**: a confirmation dialog opens with: **"Are you sure you want to delete this file? All of the properties imported from this file will be deleted. Also all the reviews of those properties."**
   - On confirm: `DELETE /api/holdings/import/:fileId` is called.
   - On success: `toast.success('Successfully deleted N propert[y/ies].')` and list refreshes.
   - On error: `toast.error(getApiError(err, 'Failed to delete file.'))`.
8. Paginated at 10 items per page.

---

## Access Control

| Action | Requirement |
|---|---|
| View the import page | Authenticated. |
| Import properties (upload file) | Authenticated + plan is `business` or `businessAi`. `subscribed('business', 'businessAi')` middleware. Premium/starter plan users see the PayWall. |
| View import history | Authenticated. |
| Download an import file | Authenticated, owner of the file. |
| Delete an import file | Authenticated, owner of the file (`fk_id_user_fho` must match). |
| Plan auto-upgrade on import | After a successful import, if `holdingsCount > planProperties`, the Stripe subscription is automatically upgraded to the next tier. |

---

## File Format and Validation

### Accepted file types

| Type | Detection method |
|---|---|
| CSV | Base64 MIME contains `text/csv`. Parsed with `csv-parse`; delimiter `,`, quoted fields supported. |
| XLSX | Base64 MIME contains `spreadsheetml`, `xlsx`, or `excel`. Parsed with `read-excel-file`. |

Any other format returns: `"Invalid file format. Please upload a CSV or XLSX file."` (HTTP 422).

CSV parse error on column count mismatch returns: `"Problem with the file. In line N, X elements are written, although Y are necessary because there are Y headers. Make corrections in the file. Where necessary, make empty columns."` (HTTP 422).

General parse failure: `"File parsing failed. Make sure the file uses ',' as a separator for CSV."` (HTTP 422).

### Required and allowed columns

Column names are lowercased before matching.

| Column | Required | Description |
|---|---|---|
| `property` | **Yes** | Property name. Max 200 characters. |
| `groups` | No | Pipe-separated group tags. Example: `Luxury\|pet-friendly\|pool`. Groups deduplicated case-insensitively. Max 50 chars per group name. |
| `airbnb` | No | Airbnb listing URL. |
| `booking` | No | Booking.com listing URL. |
| `vrbo` | No | Vrbo listing URL. |
| `homeaway` | No | HomeAway URL (normalised to `vrbo` source type). |
| `fewo-direkt` | No | Fewo-Direkt URL (normalised to `vrbo`). |
| `abritel` | No | Abritel URL (normalised to `vrbo`). |
| `aluguetemporada` | No | Aluguetemporada URL (normalised to `vrbo`). |
| `stayz` | No | Stayz URL (normalised to `vrbo`). |
| `homelidays` | No | Homelidays URL (normalised to `vrbo`). |
| `tripadvisor` | No | TripAdvisor listing URL. |
| `expedia` | No | Expedia listing URL. |
| `google` | No | Google listing URL. |
| `trustpilot` | No | Trustpilot listing URL. |

Any column name not in this list causes HTTP 422: `"Invalid column(s): [names]"`.

### Row-level validation rules

| Rule | Error |
|---|---|
| `property` column missing from file | HTTP 422: `"Missing required column: property"` |
| Row has no source URL columns filled | Row is silently skipped (not imported, not counted as error). |
| Property name > 200 chars | HTTP 422: `"Property name(s) too long (max 200 chars): '[name]'"` |
| Group name > 50 chars | HTTP 422: `"Group name(s) too long (max 50 chars): '[name]'"` |
| URL does not match channel domain | HTTP 422: `"URL '[url]' does not match source type '[source]'"` |
| Property name already exists (by slug) | Property added to `skipped` list; import continues for remaining rows. |
| Holding DB insert fails | Property added to `errors` map with `"Failed to create property"`; import continues. |
| Sources DB insert fails (after holding created) | Property added to `errors` map with `"Property created but sources failed to save"`; import continues. |

### Duplicate detection

Duplicates are matched by `slug_holding` (URL-slug derived from the property name), not by exact name string. This means minor case or punctuation differences that produce the same slug are also treated as duplicates.

### Partial import behaviour

The import processes rows one by one. A validation error at the header level (missing `property` column, invalid columns, name/group length violations, URL mismatch) aborts the entire import before any records are written. Row-level failures (duplicate, holding insert error, sources insert error) are non-fatal: the import continues and the failure is recorded in the response.

### Import file record status

| `status_fho` | Meaning |
|---|---|
| `0` | Import in progress / file just created. |
| `1` | Import completed successfully. |
| `-1` | File soft-deleted (hidden from history). |
| `-2` | Import completed with at least one row error. |

When all rows are duplicates (0 imported, 0 errors), the file record is deleted immediately and `fileId: null` is returned.

---

## API Endpoints

All import endpoints are mounted at `/api/holdings/import` and protected by `authenticate`.

---

### `GET /api/holdings/import`

Get the paginated list of import files for the authenticated user. Excludes soft-deleted files (`status_fho !== -1`).

**Auth:** Bearer JWT (authenticated).

**Query parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `page` | integer | No | Default: `1`. |
| `limit` | integer | No | Default: `20`. Max: `100`. |

**Response:**

```json
{
  "success": true,
  "data": {
    "files": [
      {
        "_id": "abc123",
        "type_fho": "xlsx",
        "status_fho": 1,
        "fileName": "import_properties.xlsx",
        "propertiesCount": 15,
        "createdAt": "2026-05-01T10:00:00.000Z"
      }
    ],
    "pagination": {
      "currentPage": 1,
      "totalPages": 3,
      "totalItems": 25,
      "itemsPerPage": 10,
      "hasNext": true,
      "hasPrev": false
    }
  }
}
```

`s_file_content` and `a_holdings` are excluded from the projection. Old `type_fho: 'excel'` values are normalised to `'xlsx'` in the response.

---

### `POST /api/holdings/import`

Import properties from a base64-encoded CSV or XLSX file.

**Auth:** Bearer JWT + plan `business` or `businessAi` (`subscribed('business', 'businessAi')` middleware).

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `fileContent` | string | Yes | Base64 data URL of the file (e.g. `data:text/csv;base64,...`). Minimum 1 character. |
| `fileName` | string | No | Original file name; stored for display in history. |

**Processing order (server):**
1. Detect file type from MIME in `fileContent`.
2. Decode and parse rows.
3. Validate headers (required `property` column, no unknown columns).
4. Build holdings list from rows (skip rows with no source URLs).
5. Validate name/group lengths and URL-to-channel matching.
6. Create `HoldingsImportModel` record with `status_fho: 0`.
7. For each holding: check duplicate by slug → if duplicate, add to `skipped`; otherwise create `HoldingsModel` + `SourcesModel` records.
8. Update `HoldingsImportModel` status to `1` (success) or `-2` (errors).
9. Recalculate user data; auto-upgrade Stripe plan if needed.

**Response (success):** HTTP 201.

```json
{
  "success": true,
  "data": {
    "fileId": "abc123",
    "imported": 12,
    "skipped": ["Beach House", "City Flat"],
    "errors": {
      "Broken Property": { "message": "Failed to create property" }
    }
  }
}
```

`fileId` is `null` when all rows were duplicates (no file record saved).

**Response (validation error):** HTTP 422.

```json
{
  "success": false,
  "errors": [{ "message": "Missing required column: property" }]
}
```

---

### `DELETE /api/holdings/import/:fileId`

Delete an import file record and cascade-delete all holdings, sources, and reviews that were created by that import.

**Auth:** Bearer JWT (authenticated).

**Path parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `fileId` | string | Yes | The import file's `_id`. |

**Side effects:**
- Import file record: soft-deleted (`status_fho: -1`).
- All `HoldingsModel` records with `fk_id_file_holding === fileId` and `fk_id_user_holding === userId`: hard-deleted.
- All `SourcesModel` records for those holdings: hard-deleted.
- All `ReviewsModel` records for those holdings: hard-deleted.
- User data totals recalculated.

**Response (success):**

```json
{
  "success": true,
  "data": { "deletedProperties": 12 }
}
```

**Response (not found):** HTTP 404.

```json
{
  "success": false,
  "errors": [{ "message": "Import file not found" }]
}
```

---

### `GET /api/holdings/import/:fileId/download`

Download the original uploaded file.

**Auth:** Bearer JWT (authenticated).

**Path parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `fileId` | string | Yes | The import file's `_id`. |

**Response:** Binary file stream.

```
Content-Type: text/csv  (or application/vnd.openxmlformats-officedocument.spreadsheetml.sheet)
Content-Disposition: attachment; filename="import_properties.csv"
```

Returns HTTP 404 if the file is not found, belongs to another user, has been soft-deleted, or if `s_file_content` is not a valid base64 data URL.

---

## Components

| File | Route | Purpose |
|---|---|---|
| `nimad_vue3/src/revamp/pages/PropertiesBulkImport.vue` | `/properties/import` | Shell page — plan gate (PayWall), two-tab layout (Import Properties / Import History). |
| `nimad_vue3/src/revamp/pages/properties/ImportProperties.vue` | (tab) | File upload form, instructions accordion, template download links, plan capacity banner, result summary display. |
| `nimad_vue3/src/revamp/pages/properties/ImportPropertiesHistory.vue` | (tab) | Paginated table of past import files; download and delete actions. |
