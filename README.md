# Movie Tracker Project

This repository contains both project models in separate top-level directories:

- [`normal_app/`](normal_app/README.md): Flutter mobile application
- [`backend/`](backend/README.md): Node.js backend for the advanced model

The Flutter application supports two selectable data modes:

- Normal mode communicates directly with OMDb and stores personal data locally.
- Advanced mode communicates with the custom backend, stores its JWT securely and supports certificate pinning.

```text
backend/      Advanced API, database and server-side logic
normal_app/   Flutter application and local persistence
```
