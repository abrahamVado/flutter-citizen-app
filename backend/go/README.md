# Citizen App Go Backend

## Overview
This module provides a lightweight HTTP API used by the Flutter Citizen application. All handlers use worker pools to keep request processing concurrent and responsive.

## Requirements
- Go 1.20+

## Installation
```bash
cd backend/go
go mod tidy
```

## Running the service
```bash
cd backend/go
export DATABASE_URL="postgres://..."
export JWT_SECRET="replace-with-long-random-value"
go run ./cmd/server
```

The server listens on `http://127.0.0.1:8080` by default. Configure an alternate port with the `PORT` environment variable before starting the process. A non-empty `JWT_SECRET` is required to sign and validate access tokens.

## API surface
| Endpoint | Method | Description |
| --- | --- | --- |
| `/auth` | `POST` | Validates credentials and returns an access token with an expiration timestamp. |
| `/catalog` | `GET` | Retrieves the list of incident types available for reporting. |
| `/reports` | `POST` | Accepts a report payload and generates a folio. |
| `/folios/{id}` | `GET` | Returns the latest status and history for an existing folio. |

## Request validation constraints
The Gin handlers enforce the same limits expected by the mobile client before delegating to services.

| Endpoint | Field | Rules |
| --- | --- | --- |
| `POST /api/v1/auth/login` / `POST /api/v1/auth/register` | `email` | Required, valid email format. |
|  | `password` | Required, minimum 8 characters. |
| `POST /api/v1/auth/recover` | `email` | Required, valid email format. |
| `POST /api/v1/reports` | `incidentTypeId` | Required, non-empty string. |
|  | `description` | Required, max 2000 characters. |
|  | `contactEmail` | Required, valid email format. |
|  | `contactPhone` | Required, 10–15 digits with optional leading `+`. |
|  | `latitude` | Required, numeric range -90 to 90. |
|  | `longitude` | Required, numeric range -180 to 180. |
|  | `address` | Required, 1–250 characters. |
|  | `evidenceUrls` | Optional, each entry must be a valid URL. |
| `PATCH /api/v1/reports/{id}` | `status` | Required, allowed values: `en_revision`, `en_proceso`, `resuelto`, `critico`. |

## Flutter configuration
Update the Flutter environment variables to point to the local Go service when testing:

```dart
const apiBaseUrl = 'http://127.0.0.1:8080';
```

The `ApiClient` already defaults to this base URL for local development.

## Testing
Use Go's tooling to validate the build:

```bash
cd backend/go
go test ./...
```

Integration tests for the Flutter client automatically spin up the Go binary with `go run ./cmd/server`.
