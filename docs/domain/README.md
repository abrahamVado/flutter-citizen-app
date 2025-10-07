# Domain Module Overview

## Purpose
The domain layer defines the platform-agnostic business rules for Citizen Reports. It expresses core entities, value objects, repositories, and use cases that orchestrate reporting, catalog discovery, authentication, and folio tracking.

## Key Entry Points
- [`entities/`](../../lib/src/domain/entities): Immutable models representing incidents, reports, folio status, and credentials consumed across the app.
- [`value_objects/`](../../lib/src/domain/value_objects): Types such as `AuthToken` that embed invariants like expiration checks.
- [`repositories/`](../../lib/src/domain/repositories): Abstract contracts consumed by use cases to request data or persist state.
- [`usecases/`](../../lib/src/domain/usecases): Application-specific actions that coordinate validation and repository delegation.
- [`exceptions/validation_exception.dart`](../../lib/src/domain/exceptions/validation_exception.dart): Domain-level error surfaced when business rules are violated.

## Major Flows
### User Authentication
1. `AuthenticateUser` delegates to `AuthRepository.authenticate` to validate credentials and receive a token.
2. The resulting `AuthToken` enforces expiration logic before the app exposes authenticated routes.

### Incident Reporting
1. `SubmitReport` validates request fields (email, phone length, description) before contacting the repository.
2. Upon success, the use case returns a strongly typed `Report` entity for presentation and caching layers.

### Catalog Retrieval
1. `GetIncidentTypes` calls `CatalogRepository.getIncidentTypes` to supply the form dropdown with offline-capable data.
2. Entities such as `IncidentType` capture requirement flags (evidence, metadata) consumed by controllers.

### Folio Lookup
1. `LookupFolio` normalizes the folio identifier, then queries `ReportsRepository.lookupFolio` for latest status updates.
2. The returned `FolioStatus` aggregates a progress history for UI components to display.

## Super-Comment Map
Super comments annotate validation and delegation steps within use cases:
- `usecases/authenticate_user.dart`: Provider handoff (`//1.-`).
- `usecases/submit_report.dart`: Validation and dispatch pipeline (`//1.-`–`//4.-`).
- `usecases/get_incident_types.dart`: Repository delegation (`//1.-`).
- `usecases/lookup_folio.dart`: Normalization and lookup (`//1.-`, `//2.-`).
