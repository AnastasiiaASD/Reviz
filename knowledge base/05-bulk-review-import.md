<!-- Sources read:
  nimad_vue3/src/revamp/pages/ReviewsBulkImport.vue
  nimad_vue3/src/revamp/pages/reviews/ImportReviews.vue
  nimad_vue3/src/revamp/pages/reviews/ImportReviewsHistory.vue
  nimad_vue3/src/revamp/api/reviews.js
  api/client/reviews/reviews.routes.js
  api/client/reviews/import/reviewsImport.routes.js
  api/client/reviews/import/reviewsImport.controller.js
  api/client/reviews/import/reviewsImport.service.js
  api/client/reviews/import/reviewsImport.validation.js
  api/client/holdings/holdings.routes.js
-->

# Bulk Review Import

## Overview

Bulk Review Import lets users upload a CSV or XLSX file to create multiple reviews at once for a specific property. Each file row becomes one review. The feature is gated to `business` and `businessAi` plan holders. An Import History tab lists all previously uploaded files and allows re-download or deletion (which cascades to all reviews created by that file).

---

## User Flow

### Import Reviews tab

1. User navigates to `/reviews/import`.
2. If the user's plan is not `business` or `businessAi`, a **PayWall** component is shown and the rest of the page is hidden.
3. Two tabs are displayed: **"Import Reviews"** and **"Import History"**.
4. The **"Import Reviews"** tab is selected by default.
5. An accordion **"How to import reviews"** is shown (expanded by default) with these instructions:
   - _"Download the CSV or XLSX template below."_
   - _"Fill in your guest reviews following the template format."_
   - _"Select the property you want to import reviews for."_
   - _"Upload the completed file and click 'Import'."_
6. Template download links for `import_reviews_template.xlsx` and `import_reviews_template.csv` are shown.
7. A **"Search for a property to import reviews"** field (`placeholder="Select a property..."`) is shown. Typing 3+ characters triggers a debounced search via `searchHoldings`. Selecting a property from the dropdown sets the target holding.
8. A file uploader component (`FileUploader`) accepts the file.
9. The **"Import"** button (`data-testid="import-btn"`) is disabled until both a file and a property are selected. Button shows **"Importing..."** while in progress.
10. On submit, the client reads the file using `FileReader.readAsDataURL()` and sends the resulting base64 string as `fileContent` along with the `fileName` to `POST /api/holdings/:holdingId/reviews/import`.
11. On response, the result summary is displayed inline (see Result States below).
12. On error: a block with title **"Import failed"** and the API error message is shown.
13. After the import completes (success or failure), the property selection and file are cleared.

### Result States (inline, after import)

| Condition | Title shown | Notes |
|---|---|---|
| All rows imported, no duplicates | `"N review[s] imported successfully."` | |
| Some imported, some duplicates | `"Import complete with some issues."` | Detail shows how many were skipped: `"N review[s] were skipped because they already exist"`. Description shows `"N review[s] imported successfully."` if any were imported. |
| All rows duplicates (0 imported) | HTTP 422 from server → shown as error: `"0 reviews have been imported from attached file. To avoid duplicates, reviews from the Booking Channels you already have registered have been omitted."` | |

### Import History tab

1. User clicks **"Import History"** tab.
2. A yellow warning banner always displays: **"By removing a file, you will remove all the imported reviews as well."**
3. A table **"Imported Files"** shows past uploads with columns: **#**, **Imported File**, **Date Imported**, **Reviews**, **Actions**.
4. Empty state: **"No files found."**
5. Each row shows the file name, date, review count, and two action buttons: **Download** and **Delete**.
6. **Download**: calls `GET /api/reviews/import/:fileId/download` — returns the original uploaded file (or regenerates it from stored review data for old records). File is saved locally as `import_reviews.<ext>`.
7. **Delete**: a confirmation dialog opens with: **"Are you sure you want to delete this file? All of the reviews imported from this file will be also deleted."**
   - On confirm: `DELETE /api/reviews/import/:fileId` is called.
   - On success: `toast.success('Successfully deleted file.')` and list refreshes.
   - On error: `toast.error(getApiError(err, 'Failed to delete file.'))`.
8. Paginated at 10 items per page.

---

## Access Control

| Action | Requirement |
|---|---|
| View the import page | Authenticated. |
| Import reviews (upload file) | Authenticated + plan `business` or `businessAi`. `subscribed('business', 'businessAi')` middleware. Other plan users see the PayWall. |
| View import history (global) | Authenticated. |
| Download an import file | Authenticated, owner of the file (`fk_id_user_frw` must match). |
| Delete an import file | Authenticated, owner of the file (`fk_id_user_frw` must match). |

---

## File Format and Validation

### Accepted file types

| Type | Detection method |
|---|---|
| CSV | Base64 MIME contains `text/csv`. Parsed with `csv-parse`. |
| XLSX | Base64 MIME contains `spreadsheetml`, `xlsx`, or `excel`. Parsed with `read-excel-file`. |

Empty file (0 rows): HTTP 422 — `"No reviews found in file"`.

### Required columns

Column names are lowercased and trailing `*` characters are stripped before matching.

| Column | Required | Description |
|---|---|---|
| `Date*` / `date (yyyy-mm-dd)` | **Yes** | Review date. Must be a valid ISO date (`YYYY-MM-DD`). Accepts Date objects (from XLSX) or string. |
| `Name*` / `name` | **Yes** | Reviewer name. |
| `Rating*` / `rating` | **Yes** | Numeric rating. Must be ≤ 5. Accepts comma as decimal separator. |
| `URL*` / `url` | **Yes** | Source listing URL. Used for duplicate detection and source type inference. |
| `Listing Site Name*` / `listing site name` | **Yes** | Name of the source site (free text, stored as `source_site_name`). |
| `Review Comment*` / `review comment` | Conditional | Review text body. At least one of `review comment` or `review title` must be non-empty. |
| `Review Title` / `review title` | Conditional | Review title. Optional if `review comment` is present. |
| `Owner Response` / `owner response` | No | Optional pre-filled owner response text. |

If any required column is missing or both `review comment` and `review title` are empty for a row, HTTP 422 is returned:
`"The imported file does not match the required template. Please ensure you are using the correct template for importing."`

If any rating value exceeds 5: `"Incorrect ratings format. Please check that all ratings are based on 5 stars."`

If any date is not valid `YYYY-MM-DD`: `"Incorrect date format. Please use YYYY-MM-DD (e.g. 2024-03-15)."`

### Duplicate detection

Two-layer duplicate check per row (both cause the row to be skipped silently):
1. **URL match**: the normalized URL (scheme/`www.` stripped, trailing slash removed) matches an existing source URL for that holding.
2. **Checksum match**: the review's computed checksum (`checksum_reviews`) matches an existing review record for that holding.

### Source type inference

The `url` column value is passed to `SourcesM.get_type_by_url()` to determine the booking channel type (e.g. `airbnb`, `booking`, `vrbo`). If no match, the type defaults to `revyoos`.

**Only reviews with `type_source_reviews === 'revyoos'` are saved to the `ReviewsModel` collection.** Reviews with a recognized channel type (e.g. from an Airbnb URL) are stored in the import file record (`a_reviews`) but not inserted as review documents.

### Auto-source creation

For each unique channel type inferred from the imported reviews that does not already have a source registered for the holding, a new `SourcesModel` record is created automatically with `status_source: 0` (PENDING).

### Import file record (`ReviewsImportModel`) status

| `status_frw` | Meaning |
|---|---|
| `0` | Import in progress / file just created. |
| `1` | Import completed successfully. |
| `-1` | File soft-deleted. Hidden from history. |
| `-2` | Import completed with error (`ReviewsModel.insertMany` failed). |

Files with `status_frw` of `-1` or `-2` are excluded from the import history list.

---

## API Endpoints

---

### `POST /api/holdings/:holdingId/reviews/import`

Import reviews from a base64-encoded CSV or XLSX file into a specific property.

**Auth:** Bearer JWT + plan `business` or `businessAi` (`subscribed('business', 'businessAi')` middleware).

**Path parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `holdingId` | string | Yes | The holding's `_id`. Validated by `validateHolding` middleware. |

**Request body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `fileContent` | string | Yes | Base64 data URL of the file (e.g. `data:text/csv;base64,...`). Minimum 1 character. |
| `fileName` | string | No | Original file name; stored for display in history. |

**Processing order (server):**
1. Parse and detect file type from MIME in `fileContent`.
2. Normalize column names (lowercase, strip trailing `*`).
3. Validate all rows (required columns, rating ≤ 5, date format `YYYY-MM-DD`).
4. Fetch existing source URLs and review checksums for the holding.
5. Build reviews list, skipping duplicates (by URL or checksum). Track `haveDuplicateUrl` flag.
6. If 0 reviews remain and at least one was skipped: return HTTP 422 (all-duplicates error).
7. Auto-create `SourcesModel` records for new channel types not yet registered on the holding.
8. Create `ReviewsImportModel` record with `status_frw: 0`.
9. Insert only `type_source_reviews === 'revyoos'` reviews into `ReviewsModel` (`ordered: false` for partial-success tolerance).
10. Update `ReviewsImportModel` to `status_frw: 1`; store all reviews (including non-revyoos) in `a_reviews` for download reconstruction.
11. Recalculate user data totals.

**Response (success):** HTTP 201.

```json
{
  "success": true,
  "data": {
    "fileId": "abc123",
    "imported": 10,
    "total": 12,
    "haveDuplicateUrl": true
  }
}
```

- `imported`: number of reviews saved to `ReviewsModel` (only `revyoos` type).
- `total`: total non-duplicate rows processed.
- `haveDuplicateUrl`: `true` if any rows were skipped due to duplicate detection.

**Response (validation error):** HTTP 422.

```json
{
  "success": false,
  "errors": [{ "message": "Incorrect date format. Please use YYYY-MM-DD (e.g. 2024-03-15)." }]
}
```

---

### `GET /api/reviews/import`

Get a paginated list of all review import files for the authenticated user (across all properties).

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
        "type_frw": "xlsx",
        "status_frw": 1,
        "fileName": "my_reviews.xlsx",
        "name_holding_frw": "Beach Villa",
        "reviewsCount": 42,
        "createdAt": "2026-05-01T10:00:00.000Z"
      }
    ],
    "pagination": {
      "currentPage": 1,
      "totalPages": 3,
      "totalItems": 25,
      "itemsPerPage": 20,
      "hasNext": true,
      "hasPrev": false
    }
  }
}
```

`s_file_content` and `a_reviews` are excluded from the projection. Old `type_frw: 'excel'` values are normalised to `'xlsx'`. `fileName` falls back to `import_<date>.<ext>` if `name_file_frw` is absent. Files with `status_frw: -1` (soft-deleted) or `-2` (errored) are excluded.

---

### `GET /api/holdings/:holdingId/reviews/import`

Get a paginated list of review import files scoped to a single property.

**Auth:** Bearer JWT (authenticated).

**Path parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `holdingId` | string | Yes | The holding's `_id`. |

**Query parameters:** Same as `GET /api/reviews/import`.

**Response:** Same structure as `GET /api/reviews/import`.

---

### `DELETE /api/reviews/import/:fileId`

Delete a review import file record and permanently remove all reviews that were created by that import.

**Auth:** Bearer JWT (authenticated).

**Path parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `fileId` | string | Yes | The import file's `_id`. |

**Side effects:**
- Import file record: soft-deleted (`status_frw: -1`).
- All `ReviewsModel` records with `fk_id_file_reviews === fileId`: permanently deleted.
- Any `SourcesModel` records that were auto-created by this import and have no remaining reviews after deletion: permanently deleted.
- User data totals recalculated.

**Response (success):**

```json
{
  "success": true,
  "data": { "success": true }
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

### `GET /api/reviews/import/:fileId/download`

Download the original uploaded review import file.

**Auth:** Bearer JWT (authenticated).

**Path parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `fileId` | string | Yes | The import file's `_id`. |

**Response:** Binary file stream.

```
Content-Type: text/csv  (or application/vnd.openxmlformats-officedocument.spreadsheetml.sheet)
Content-Disposition: attachment; filename="<original-filename>.<ext>"
```

If `s_file_content` (raw base64 data URL) is present, it is decoded and returned directly. If absent (old records), the file is regenerated from `a_reviews` using TEMPLATE_HEADERS: `['Date*', 'Name*', 'Rating*', 'URL*', 'Listing Site Name*', 'Review Comment*', 'Review Title', 'Owner Response']`.

Returns HTTP 404 if the file is not found, belongs to another user, has been soft-deleted or errored, or if no stored content or reviews exist for regeneration.

---

## Components

| File | Route | Purpose |
|---|---|---|
| `nimad_vue3/src/revamp/pages/ReviewsBulkImport.vue` | `/reviews/import` | Shell page — plan gate (PayWall), two-tab layout (Import Reviews / Import History). |
| `nimad_vue3/src/revamp/pages/reviews/ImportReviews.vue` | (tab) | Property search, file upload form, instructions accordion, template download links, result summary display. |
| `nimad_vue3/src/revamp/pages/reviews/ImportReviewsHistory.vue` | (tab) | Paginated table of past review import files; download and delete actions. |
