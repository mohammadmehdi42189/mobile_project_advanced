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
cp .env.example .env
npm install
npm run db:generate
npm run db:push
npm run db:seed
npm run dev
```

Set `OMDB_API_KEY` in `.env`. The backend uses cached media when the external service is temporarily unavailable. Configure the SMTP variables for password recovery.

Default seeded administrator:

- Email: `admin@example.com`
- Password: `Admin123!`

Change these credentials before deployment.

## Mobile integration

Configure one base URL in the mobile project:

```text
http://10.0.2.2:3000/api/v1
```

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
