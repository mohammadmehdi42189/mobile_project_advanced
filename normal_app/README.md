# Normal Mobile Application

This branch contains only the normal project model. It is a Flutter application that communicates directly with OMDb and stores user activity locally.

## Run

1. Install Flutter 3.22 or newer.
2. Create the platform folders if needed:

```bash
flutter create --platforms=android .
```

3. Install packages and run with an OMDb key:

```bash
flutter pub get
flutter run --dart-define=OMDB_API_KEY=YOUR_KEY
```

## Included requirements

- Local registration, login, persistent session and profile editing
- Guest browsing and local password recovery
- Duplicate email prevention and hashed local passwords
- Debounced asynchronous movie and series search
- Movie, series, season and episode details
- Watch states, watched episodes and progress
- Favorites, ratings, spoiler-aware comments and custom lists
- User statistics
- Local persistence and cached search results
- Cached posters, loading states and network error messages
- Persian right-to-left Material 3 interface

The advanced backend remains on the `main` branch. This normal implementation is intentionally published on a separate branch and is not merged.
