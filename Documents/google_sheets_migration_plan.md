# Implementation Plan - Migrating from Supabase to Google Sheets

We are switching the backend from Supabase to Google Sheets. Since Google Sheets doesn't have a native Flutter real-time SDK, we will use **Google Apps Script** as a middleware API.

## Phase 1: Google Sheets & Apps Script Setup
You need to create a Google Sheet and deploy an Apps Script.

### 1. Google Sheets Structure
Create a new Google Sheet with the following sheet names (tabs):
- **Users**: `id`, `email`, `display_name`, `is_sharing`, `last_location_lat`, `last_location_lng`, `updated_at`
- **Groups**: `id`, `name`, `owner_id`, `invite_code`, `created_at`
- **GroupMembers**: `group_id`, `user_id`, `role`, `joined_at`
- **Locations**: `user_id`, `group_id`, `lat`, `lng`, `status`, `timestamp`

### 2. Google Apps Script
Go to **Extensions > Apps Script** in your Google Sheet and use the script provided in the next steps. This script will handle `doPost` and `doGet` requests from the Flutter app.

## Phase 2: Flutter App Refactoring

### 1. Dependency Changes
- **Remove**: `supabase_flutter`
- **Add**: `http` (for API calls), `shared_preferences` (for local session persistence)
- Keep: `google_sign_in`, `geolocator`, `google_maps_flutter`

### 2. Service Refactoring
- **`AuthService` (New)**: Handle Google Sign-In and communicate with the Apps Script to "register" the user in the sheet.
- **`GroupService`**: Rewrite to use `http` calls to the Apps Script URL instead of Supabase client.
- **`LocationService`**: Rewrite to use `http` POST for updates and periodic `http` GET for "real-time" updates (polling).

### 3. UI Updates
- **`AuthGate`**: Update to check local `shared_preferences` or `GoogleSignIn.instance.currentUser` instead of `Supabase.instance.client.auth.onAuthStateChange`.
- **`LoginScreen`**: Simplify to predominantly use Google Sign-In (recommended for security with Google Sheets).

## Phase 3: Cleanup
- Delete `supabase_schema.sql`.
- Delete `supabase_constants.dart` (Replace with `google_sheets_constants.dart`).
