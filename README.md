# Mobile Project

The advanced server implementation is isolated in [`backend/`](backend/README.md). Add the normal mobile application later in a separate top-level directory such as `mobile/`.

Recommended repository layout:

```text
backend/   Advanced server
mobile/    Normal mobile application
docs/      Shared screenshots and reports
```

Keeping a versioned API contract between the two parts prevents merge conflicts and allows the normal project to be developed independently.
