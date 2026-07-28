# Advanced Backend

This directory contains the independent backend required by the advanced project model. The Flutter application is kept in `normal_app/` and communicates with this service through `/api/v1` when advanced mode is enabled.

## Features

- Registration and login with hashed passwords and JWT
- User and administrator access levels
- Movie and series search through OMDb
- Normalized media details and database cache
- Personal watchlist and watch status
- Ratings, comments and activity statistics
- Personal lists and comment reporting
- Seasons and episode details
- Rating distribution and complete activity statistics
- Email-based password recovery
- Profile bio and avatar metadata
- Administrator user, comment and system management
- Request validation, rate limiting and standard JSON errors
- Swagger UI at `/docs`

## Run locally

```bash
npm install
npm run setup
npm run config:check
npm run db:generate
npm run db:push
npm run db:seed
npm run dev
```

`npm run setup` creates the ignored `.env` file, generates a strong JWT secret and securely asks for the OMDb and SMTP settings. Existing values are preserved when the setup is run again. `npm run config:check` validates the OMDb key and SMTP connection without printing secrets.

For CI or a hosting service, configure the variables from `.env.example` in the platform secret manager. Production startup rejects a missing OMDb key, incomplete SMTP credentials, a weak JWT secret or unrestricted CORS.

Default seeded administrator:

- Email: `admin@example.com`
- Password: `Admin123!`

Change these credentials before deployment.

## Mobile integration

For local development, configure the emulator URL:

```text
http://10.0.2.2:3000/api/v1
```

For a deployed HTTPS backend, create the ignored Flutter configuration and certificate pin directly from the live server:

```bash
npm run certificate:fingerprint -- \
  https://api.example.com/api/v1 \
  ../normal_app/config/advanced.json
```

Regenerate this file whenever the server certificate is renewed.

For protected routes, send:

```text
Authorization: Bearer <token>
```

The API response format is JSON. Errors use this stable shape:

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid request",
    "details": {}
  }
}
```

Swagger UI is available at `/docs`.

## Tests

Use a separate SQLite database:

```bash
DATABASE_URL="file:./test.db" npm run db:push
DATABASE_URL="file:./test.db" npm test
```
