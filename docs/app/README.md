# App Module Overview

## Purpose
The app layer wires together dependencies, bootstraps shared services, and exposes the top-level widgets that drive navigation and session state for the Citizen Reports experience.

## Key Entry Points
- [`lib/main.dart`](../../lib/main.dart): Initializes Flutter bindings, builds Riverpod overrides, and launches the `CitizenReportsApp` widget tree.
- [`lib/src/app/bootstrap.dart`](../../lib/src/app/bootstrap.dart): Creates the in-memory cache, API client, and repository overrides consumed across the app.
- [`lib/src/app/providers.dart`](../../lib/src/app/providers.dart): Declares the global providers that expose infrastructure and domain use cases.
- [`lib/src/app/state/session_controller.dart`](../../lib/src/app/state/session_controller.dart): Manages authentication state transitions through a `StateNotifier`.
- [`lib/src/app/citizen_reports_app.dart`](../../lib/src/app/citizen_reports_app.dart): Selects the proper navigation shell (public, admin, or loading/error screens) based on the current `SessionState`.

## Major Flows
### Application Bootstrap
1. `main.dart` ensures bindings are initialized, builds the overrides via `buildAppOverrides`, and wraps the root widget in `ProviderScope`.
2. `buildAppOverrides` assembles the infrastructure stack (cache, API client, repositories) that satisfy the provider contracts.
3. `CitizenReportsApp` consumes providers to render either the admin or public navigation graphs.

### Session Management
1. `sessionControllerProvider` constructs `SessionController` with the `AuthenticateUser` use case.
2. `SessionController.signIn` transitions through initializing, authenticated, and error states while persisting the returned token.
3. `SessionController.signOut` resets the state so navigation routes fall back to the public experience.

### Navigation Shell Selection
1. `CitizenReportsApp` listens to `SessionState` updates to switch between `AdminShell`, `_FullScreenLoader`, `_SessionError`, and `PublicShell`.
2. `PublicShell` hosts a nested navigator for public routes, while admin flows remain scoped to `AdminShell`.

## Super-Comment Map
Use the numbered `//1.-`, `//2.-`, … comments in code to trace documented steps:
- `main.dart`: startup lifecycle (`//1.-` through `//3.-`).
- `lib/src/app/bootstrap.dart`: dependency assembly (`//1.-`–`//3.-`).
- `lib/src/app/providers.dart`: provider contracts and use case wiring (`//1.-`).
- `lib/src/app/state/session_controller.dart`: session transitions (`//1.-`–`//4.-`).
- `lib/src/app/citizen_reports_app.dart`: navigation switching and UI feedback (`//1.-`).
