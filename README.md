# Movie Tracker Project

This repository contains both project models in separate top-level directories:

- [`normal_app/`](normal_app/README.md): Flutter mobile application for the normal model
- [`backend/`](backend/README.md): Node.js backend for the advanced model

The mobile application can currently run in normal mode and communicate directly with OMDb. The backend remains independently deployable for advanced client-server integration.

## Structure

```text
backend/      Advanced API, database and server-side logic
normal_app/   Normal Flutter application and local persistence
```

Each part has its own setup instructions and dependencies.
