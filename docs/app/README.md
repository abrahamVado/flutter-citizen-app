# App Module Overview

## Purpose
The app layer wires together dependencies, bootstraps shared services, and exposes the top-level widgets that drive navigation and session state for the Citizen Reports experience.

## Key Entry Points
- [`lib/main.dart`](../../lib/main.dart) / [`lib/main_citizen.dart`](../../lib/main_citizen.dart): Bootstrap the shared providers and launch the public `CitizenApp` shell.
- [`lib/main_admin.dart`](../../lib/main_admin.dart): Bootstraps dependencies and mounts the secured `AdminApp` experience.
- [`lib/src/app/app_bootstrap.dart`](../../lib/src/app/app_bootstrap.dart): Centralizes the Flutter binding initialization and ProviderScope wiring reused by each entrypoint.
- [`lib/src/app/bootstrap.dart`](../../lib/src/app/bootstrap.dart): Creates the in-memory cache, API client, and repository overrides consumed across the app.
- [`lib/src/app/providers.dart`](../../lib/src/app/providers.dart): Declares the global providers that expose infrastructure and domain use cases.
- [`lib/src/app/state/session_controller.dart`](../../lib/src/app/state/session_controller.dart): Manages authentication state transitions through a `StateNotifier`.
- [`lib/src/app/citizen_app.dart`](../../lib/src/app/citizen_app.dart) / [`lib/src/app/admin_app.dart`](../../lib/src/app/admin_app.dart): Render the public and administrative MaterialApp roots respectively.

## Major Flows
### Application Bootstrap
1. `main.dart` and its flavor-specific counterparts delegate to `bootstrapApplication` to initialize Flutter bindings and inject overrides.
2. `buildAppOverrides` assembles the infrastructure stack (cache, API client, repositories) that satisfy the provider contracts.
3. `CitizenApp` renders the public navigation graph directly, while `AdminApp` listens to session updates to gate administrative routes.

### Session Management
1. `sessionControllerProvider` constructs `SessionController` with the `AuthenticateUser` use case.
2. `SessionController.signIn` transitions through initializing, authenticated, and error states while persisting the returned token.
3. `SessionController.signOut` resets the state so navigation routes fall back to the public experience.

### Navigation Shell Selection
1. `AdminApp` listens to `SessionState` updates to switch between `AdminShell`, `_FullScreenLoader`, `_SessionError`, and the `AuthScreen` gate.
2. `CitizenApp` always renders `PublicShell`, while admin flows remain scoped to `AdminShell` once authenticated.

## Super-Comment Map
Use the numbered `//1.-`, `//2.-`, … comments in code to trace documented steps:
- `main.dart`, `main_citizen.dart`, `main_admin.dart`: startup lifecycle (`//1.-`).
- `lib/src/app/app_bootstrap.dart`: shared bootstrap steps (`//1.-`–`//3.-`).
- `lib/src/app/bootstrap.dart`: dependency assembly (`//1.-`–`//3.-`).
- `lib/src/app/providers.dart`: provider contracts and use case wiring (`//1.-`).
- `lib/src/app/state/session_controller.dart`: session transitions (`//1.-`–`//4.-`).
- `lib/src/app/citizen_app.dart` / `lib/src/app/admin_app.dart`: navigation selection (`//1.-`–`//3.-`).
