# Citizen Reports Flutter

This repo hosts the Flutter client for the Citizen Reports initiative. Two entrypoints drive independent experiences:

- `lib/main_citizen.dart` – the public citizen dashboard that exposes reporting and folio lookups without authentication.
- `lib/main_admin.dart` – the administrative panel guarded by the Riverpod-powered session controller.

## Building Variants

Run `tool/ci/build_variants.sh` to produce Android and iOS binaries for both shells. The script wires the correct targets:

```bash
./tool/ci/build_variants.sh
```

Each command accepts additional Flutter arguments that are forwarded to `flutter build` for customization.