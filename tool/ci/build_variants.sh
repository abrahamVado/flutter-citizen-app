#!/usr/bin/env bash
set -euo pipefail

#1.- Construimos la variante ciudadana apuntando al nuevo entrypoint sin autenticación.
flutter build apk --flavor citizen -t lib/main_citizen.dart "$@"
#2.- Construimos la variante administrativa que exige sesión autenticada.
flutter build apk --flavor admin -t lib/main_admin.dart "$@"
#3.- Generamos los artefactos de iOS sin firmar para ambas experiencias.
flutter build ios --flavor citizen --no-codesign -t lib/main_citizen.dart "$@"
#4.- Repetimos el build de iOS para la variante administrativa utilizando el entrypoint protegido.
flutter build ios --flavor admin --no-codesign -t lib/main_admin.dart "$@"
