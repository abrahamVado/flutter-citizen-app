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
