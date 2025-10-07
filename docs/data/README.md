# Data Module Overview

## Purpose
The data layer implements the repository contracts declared in the domain module. It provides concrete adapters for local caching, simulated REST interactions, and model mapping so higher layers can consume strongly typed entities without knowing about storage details.

## Key Entry Points
- [`cache/local_cache.dart`](../../lib/src/data/cache/local_cache.dart): In-memory persistence for tokens and report history.
- [`datasources/api_client.dart`](../../lib/src/data/datasources/api_client.dart): Simulated Dio-based client that fakes backend responses.
- [`models/mappers.dart`](../../lib/src/data/models/mappers.dart): Conversion helpers between raw maps and domain entities.
- [`repositories/auth_repository_impl.dart`](../../lib/src/data/repositories/auth_repository_impl.dart): Concrete auth repository handling token persistence and restoration.
- [`repositories/catalog_repository_impl.dart`](../../lib/src/data/repositories/catalog_repository_impl.dart): Supplies incident types from cache or network.
- [`repositories/reports_repository_impl.dart`](../../lib/src/data/repositories/reports_repository_impl.dart): Persists report submissions and fetches folio status with offline support.

## Major Flows
### Authentication Persistence
1. `AuthRepositoryImpl.authenticate` calls `ApiClient.authenticate`, serializes the token, and stores it under `_tokenKey` within `LocalCache`.
2. `AuthRepositoryImpl.restoreSession` rehydrates cached tokens, validating expiration before returning them to the domain layer.

### Incident Catalog Retrieval
1. `CatalogRepositoryImpl.getIncidentTypes` first reads cached entries through `LocalCache.read`.
2. If cache misses, the repository calls `ApiClient.fetchIncidentTypes`, maps results, and writes them back for offline use.

### Report Submission
1. `ReportsRepositoryImpl.submitReport` serializes a `ReportRequest`, delegates to `ApiClient.submitReport`, and appends the result to cached history.
2. The repository returns the mapped `Report` so controllers can surface confirmation details.

### Folio Lookup with Offline Fallback
1. `ReportsRepositoryImpl.lookupFolio` retrieves cached history to provide immediate feedback while `ApiClient.lookupFolio` executes.
2. On remote success, the cache updates with the newest status; on failure, the cached snapshot is returned as an offline fallback.

## Super-Comment Map
Numbered comments explain each repository and datasource step:
- `cache/local_cache.dart`: storage operations (`//1.-`).
- `datasources/api_client.dart`: simulated network calls and mappings (`//1.-`, `//2.-`).
- `repositories/auth_repository_impl.dart`: authentication flow (`//1.-`–`//3.-`).
- `repositories/catalog_repository_impl.dart`: cache-first catalog retrieval (`//1.-`–`//3.-`).
- `repositories/reports_repository_impl.dart`: submission, lookup, and caching strategy (`//1.-`–`//4.-`).
- `models/mappers.dart`: entity serialization/deserialization steps (`//1.-`, `//2.-`).
