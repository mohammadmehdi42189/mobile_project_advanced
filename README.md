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

## Secure configuration

From `backend/`, run `npm run setup` to generate an ignored `.env` file with a random JWT secret and the supplied OMDb and SMTP credentials. Run `npm run config:check` to verify both external services.

After deploying the backend with HTTPS, run:

```bash
npm run certificate:fingerprint -- \
  https://api.example.com/api/v1 \
  ../normal_app/config/advanced.json
```

The command reads the live certificate and writes the ignored Flutter configuration used with `--dart-define-from-file`. Secrets and deployment-specific values are never stored in the repository.
