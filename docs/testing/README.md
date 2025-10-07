# Testing Overview

## Purpose
Testing artifacts verify the most critical business flows—report submission validation, repository caching behavior, and widget wiring—without requiring a live backend.

## Key Entry Points
- [`test/domain/usecases/submit_report_use_case_test.dart`](../../test/domain/usecases/submit_report_use_case_test.dart): Exercises validation and submission logic of the `SubmitReport` use case.
- [`test/data/reports_repository_impl_test.dart`](../../test/data/reports_repository_impl_test.dart): Covers caching, API fallback, and offline recovery for `ReportsRepositoryImpl`.
- [`test/widget_test.dart`](../../test/widget_test.dart): Smoke-tests the home screen actions using fake authentication tokens.

## Major Flows
### Report Validation Guarantees
1. The submit report use case test stubs the repository, asserts the request payload, and verifies the returned `Report` mirrors domain expectations.
2. Error scenarios ensure validation exceptions are surfaced when required fields are missing or malformed.

### Repository Offline Strategy
1. Repository tests seed the in-memory cache, simulate API calls, and ensure remote responses update the cache when successful.
2. When the API throws, the implementation returns cached data to maintain continuity—mirroring the super-commented fallback steps.

### Widget Entry Points
1. The widget smoke test bootstraps the app with a known token so `CitizenReportsApp` renders the admin dashboard.
2. It validates that key public actions remain discoverable through rendered buttons, preserving user journeys described in presentation docs.

## Super-Comment Map
- `test/data/reports_repository_impl_test.dart`: Highlights cache seeding, remote calls, and fallback assertions (`//1.-`–`//2.-`).
- `test/domain/usecases/submit_report_use_case_test.dart`: Marks payload verification and fake responses (`//1.-`, `//2.-`).
- `test/widget_test.dart`: Annotates token setup and widget discovery steps (`//1.-`).
