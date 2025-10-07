# Presentation Module Overview

## Purpose
The presentation layer renders UI for public citizens and administrators. It relies on Riverpod controllers from the app layer and domain entities to drive interactive flows such as reporting incidents, checking folios, and managing admin dashboards.

## Key Entry Points
- [`public/public_shell.dart`](../../lib/src/presentation/public/public_shell.dart): Hosts the public navigation stack.
- [`public/home/citizen_home_screen.dart`](../../lib/src/presentation/public/home/citizen_home_screen.dart): Landing page exposing primary citizen actions.
- [`public/map/citizen_map_screen.dart`](../../lib/src/presentation/public/map/citizen_map_screen.dart): Placeholder for geolocation selection before submitting a report.
- [`public/report/report_form_controller.dart`](../../lib/src/presentation/public/report/report_form_controller.dart) & [`report_form_sheet.dart`](../../lib/src/presentation/public/report/report_form_sheet.dart): Manage the report submission form state and UI surface.
- [`public/folio_lookup_screen.dart`](../../lib/src/presentation/public/folio_lookup_screen.dart): Enables status lookups for existing folios.
- [`admin/admin_shell.dart`](../../lib/src/presentation/admin/admin_shell.dart) & [`dashboard/admin_dashboard_screen.dart`](../../lib/src/presentation/admin/dashboard/admin_dashboard_screen.dart): Provide authenticated navigation and dashboard stubs for staff.
- [`widgets/primary_button.dart`](../../lib/src/presentation/widgets/primary_button.dart): Shared visual component for prominent actions.

## Major Flows
### Public Incident Reporting
1. `CitizenHomeScreen` surfaces entry points to start a report or browse other flows.
2. `CitizenMapScreen` collects a location and triggers the `ReportFormSheet` bottom sheet.
3. `ReportFormController` loads catalog data, tracks field updates, validates input, and submits via `SubmitReport`.
4. On success, the controller exposes the created report so UI can confirm the folio back to the citizen.

### Folio Tracking
1. `FolioLookupScreen` resets local state on each submission, then calls the `LookupFolio` use case through Riverpod providers.
2. Results or errors are displayed in-line, allowing users to retry with cleaned state when needed.

### Session-Aware Navigation
1. `CitizenReportsApp` swaps between `PublicShell` and `AdminShell` based on `SessionState`.
2. Within `PublicShell`, a nested navigator drives map, folio, and home routes without affecting the admin stack.
3. `AdminShell` offers a scaffold with sign-out actions and quick navigation to `AdminDashboardScreen` summaries.

## Super-Comment Map
Refer to the following files to align documentation with code annotations:
- `public/public_shell.dart`: route resolution and nested navigation (`//1.-`).
- `public/home/citizen_home_screen.dart`: home layout and action prompts (`//1.-`).
- `public/map/citizen_map_screen.dart`: map container and sheet launch (`//1.-`).
- `public/report/report_form_controller.dart`: form lifecycle steps (`//1.-`–`//6.-`).
- `public/report/report_form_sheet.dart`: bottom sheet reactions (`//1.-`, `//2.-`).
- `public/folio_lookup_screen.dart`: lookup workflow (`//1.-`–`//4.-`).
- `admin/admin_shell.dart`: admin scaffold and sign-out wiring (`//1.-`).
- `admin/dashboard/admin_dashboard_screen.dart`: dashboard placeholders (`//1.-`).
- `widgets/primary_button.dart`: shared button styling (`//1.-`).
