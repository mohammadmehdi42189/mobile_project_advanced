# Normal Mobile Application

This directory contains the Flutter client for both project models.

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

Advanced mode routes movie requests and authenticated mutations through the backend:

```bash
flutter run \
  --dart-define=ADVANCED_MODE=true \
  --dart-define=BACKEND_BASE_URL=https://example.com/api/v1 \
  --dart-define=BACKEND_CERT_SHA256=SERVER_CERTIFICATE_SHA256
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
- Popular, new, highly rated and suggested media sections
- Per-season episode tracking and color-coded progress
- Rating distribution, watch time and favorite-genre statistics
- Full add/remove/delete management for custom lists
- Normal direct-OMDb mode and advanced backend mode
- Secure backend token storage and certificate pinning support

The backend is available in the repository's `backend/` directory.
