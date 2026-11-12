# Hisab Pro

Hisab Pro is a premium, offline-first personal finance manager for Android and iOS.

## Current implementation status

This repository is in Phase 1: architecture and foundation setup.

The project has been structured to follow the specification in `PROJECT_SPEC.md` and the supporting analysis documents in `docs/`.

## Required setup

Before building the app, install the Flutter SDK and ensure the Flutter tool is available on PATH.

The project is designed for:

- Flutter stable SDK
- Dart SDK compatible with the project environment
- Android and iOS build targets
- SQLCipher-backed local encryption
- Riverpod + GoRouter + Drift architecture

## Phase 1 scope

This phase includes:

- project structure and Clean Architecture scaffolding
- database foundation with SQLCipher and migration hooks
- secure storage and key derivation abstraction
- theme and router foundation
- initial tests and validation scaffolding
- documentation updates

## Important note

This workspace does not include an installed Flutter SDK. To build or run the app, install Flutter in a standard environment and run:

```bash
flutter pub get
flutter test
flutter analyze
```

## Project layout

```text
lib/
  app.dart
  main.dart
  core/
  features/
  shared/
``` 
"# Hisab-Pro" 
