# SpendArc

SpendArc is a Flutter personal finance tracker built for the Candidate Test assessment. It demonstrates clean architecture, custom animations, BLoC state management, offline-first behavior, and automated tests in one cohesive app.

## Project Overview

The app opens to a dashboard with seeded demo transactions. Users can view their balance, income, expenses, daily spend trend, sync status, and transaction history. New transactions can be added from the bottom sheet, and existing transactions can be removed with swipe-to-delete.

## Assessment Coverage

- Module 1 - Clean Architecture: domain/data/presentation layers, repository contract, `get_it` dependency injection, use case abstraction, and `Either<Failure, T>` error handling.
- Module 2 - Custom Animations: custom arc meter, custom line chart, spring-like swipe delete interaction, and particle burst delete feedback.
- Module 3 - BLoC: transaction, summary, and sync BLoCs with optimistic updates, rollback, inter-BLoC stream communication, and proper disposal.
- Module 4 - Offline-First: instant local cache load, pending write queue, background sync with diffing, and isolate JSON decoding for larger local payloads.
- Module 5 - Testing: 5 unit tests and 2 widget tests.

## Folder Structure

```text
lib/
  main.dart
  app/
    core/           shared errors, use case contracts, dependency injection
    data/           models, local/remote data sources, repository implementation
    domain/         entities, repository interfaces, use cases
    presentation/   BLoCs and UI pages
test/
  spendarc_test.dart
```

## Run The App

```bash
flutter pub get
flutter run
```

## Verify The Project

```bash
flutter analyze
flutter test
```

Both commands should complete successfully.

## Notes

The remote data source uses an in-memory demo backend fallback so the app remains usable without a real API server. Local persistence uses `SharedPreferences` for assessment simplicity while still showing offline-first cache, write queue, and sync flow patterns.
