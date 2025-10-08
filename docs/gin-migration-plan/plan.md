# Go Backend Migration to Gin Task Breakdown

## Objective
Provide a structured sequence of engineering tasks required to replace the current `net/http` + custom mux stack with the Gin web framework while maintaining existing API behavior, worker pool integration, and WebSocket capabilities.

## Context Snapshot
- Entry point: `cmd/server/main.go` wires services from `internal/service` into `internal/http.Server`.
- HTTP layer: `internal/http/server.go` exposes handlers via `http.ServeMux` and enforces methods manually.
- Real-time updates: `internal/realtime` hub handles WebSocket clients, with upgrades triggered from `/ws` handler.
- Services: Auth, catalog, and reports services expose pool-backed APIs consumed by handlers.

Understanding these touchpoints ensures the migration keeps service contracts intact and preserves concurrent processing semantics.

## Migration Phases & Tasks

### Phase 1 – Preparation
1. **Baseline validation**
   - Run `go test ./...` to capture current green state and document output for regression comparison.
   - Note any flaky or long-running tests to monitor during migration.
2. **Dependency planning**
   - Add `github.com/gin-gonic/gin` to a feature branch and inspect transitive dependencies for license or size concerns.
   - Decide on Gin mode (`Release` vs `Debug`) for production and development builds.
3. **Configuration audit**
   - Review environment variable usage (`PORT`, timeouts) to ensure parity once Gin replaces the `http.Server` handler stack.

### Phase 2 – Introduce Gin Router (Feature-flagged)
1. **Create Gin-specific server package**
   - New module (e.g., `internal/httpgin`) that mirrors `internal/http.Server` constructor but returns a Gin `*Engine`.
   - Implement route registration matching existing endpoints and HTTP verbs.
2. **Request/response translation**
   - Refactor handlers to operate on `*gin.Context`, ensuring JSON binding/validation replicates current error responses and status codes.
   - Centralize common response helpers (JSON, error handling) in the new package to keep logic consistent.
3. **Middleware & recovery**
   - Configure Gin middleware for logging, panic recovery, and request timeouts; confirm compatibility with existing context timeouts inside services.
   - Implement method enforcement via Gin route definitions instead of custom wrapper.
4. **WebSocket endpoint**
   - Use `gin.WrapH` or `engine.Handle` to integrate the existing Gorilla WebSocket upgrader without rewriting the realtime hub.
5. **Feature toggle in main**
   - Update `cmd/server/main.go` to initialize Gin engine alongside the existing mux behind an environment flag (e.g., `USE_GIN`), allowing side-by-side testing.

### Phase 3 – Testing & Parity Verification
1. **Unit test updates**
   - Adapt existing handler tests (or create new ones) to exercise Gin routes using `httptest`.
   - Ensure JSON payloads, status codes, and error messages remain unchanged.
2. **Integration smoke tests**
   - Add end-to-end test covering the most critical flow: `/reports` submission followed by `/folios/{id}` lookup and WebSocket broadcast observation.
   - Verify worker pools still respect timeouts through context propagation.
3. **Performance benchmarking**
   - Use `hey` or `wrk` locally to compare latency/throughput between mux and Gin paths for `/reports` and `/auth` under concurrent load.

### Phase 4 – Complete Cut-over
1. **Remove legacy mux**
   - Once parity is confirmed, delete or archive `internal/http` in favor of the Gin implementation, ensuring no unused helpers remain.
2. **Configuration cleanup**
   - Replace feature flag with permanent Gin initialization and update configuration docs/README sections accordingly.
3. **Dependency & tooling updates**
   - Run `go mod tidy` to prune unused packages.
   - Update linting or formatting rules if Gin introduces new patterns (e.g., JSON binding tags).
4. **Documentation refresh**
   - Document the new routing stack in `backend/go/README.md`, including Gin-specific development tips.

### Phase 5 – Deployment Readiness
1. **Container/build updates**
   - Verify Dockerfiles or deployment manifests expose any new environment variables or binary flags.
2. **Observability checks**
   - Confirm logging, metrics, and tracing continue to function or enhance with Gin middleware as needed.
3. **Rollout plan**
   - Define staged rollout (canary, blue/green) with rollback strategy in case Gin-specific issues arise.

## Deliverables Checklist
- [ ] Gin-backed server package mirroring existing endpoints.
- [ ] Updated main entry point using Gin by default.
- [ ] Automated test suite demonstrating request/response parity (unit + integration).
- [ ] Updated documentation and deployment artifacts reflecting Gin usage.
- [ ] Performance report comparing mux vs Gin behavior under load.

## Risks & Mitigations
- **Behavioral drift in responses**: Mitigate with comprehensive handler tests comparing legacy vs Gin outputs.
- **Timeout handling differences**: Explicitly manage `Context` deadlines within Gin handlers to avoid losing worker pool safeguards.
- **Middleware ordering issues**: Document and test middleware stack to prevent recovery/logging gaps.

By following these phases, the team can migrate incrementally, validate parity, and adopt Gin with minimal service disruption.
