export const swaggerDocument = {
  openapi: "3.0.3",
  info: {
    title: "Movie Tracker Backend API",
    version: "1.0.0",
    description: "Backend contract for the advanced mobile project"
  },
  servers: [{ url: "/api/v1" }],
  components: {
    securitySchemes: {
      bearerAuth: { type: "http", scheme: "bearer", bearerFormat: "JWT" }
    }
  },
  paths: {
    "/auth/register": { post: { summary: "Register a user", responses: { "201": { description: "Created" } } } },
    "/auth/login": { post: { summary: "Log in", responses: { "200": { description: "Authenticated" } } } },
    "/profile": { get: { summary: "Get profile", security: [{ bearerAuth: [] }], responses: { "200": { description: "Profile" } } } },
    "/media/search": { get: { summary: "Search movies and series", parameters: [
      { name: "q", in: "query", required: true, schema: { type: "string" } },
      { name: "page", in: "query", schema: { type: "integer", default: 1 } }
    ], responses: { "200": { description: "Search result" } } } },
    "/media/{id}": { get: { summary: "Get media details", parameters: [
      { name: "id", in: "path", required: true, schema: { type: "string" } }
    ], responses: { "200": { description: "Media details" } } } },
    "/watchlist": { get: { summary: "Get personal watchlist", security: [{ bearerAuth: [] }], responses: { "200": { description: "Watchlist" } } } },
    "/watchlist/{mediaId}": { put: { summary: "Set watch status", security: [{ bearerAuth: [] }], responses: { "200": { description: "Updated" } } } },
    "/ratings/{mediaId}": { put: { summary: "Rate media", security: [{ bearerAuth: [] }], responses: { "200": { description: "Updated" } } } },
    "/comments/{mediaId}": { post: { summary: "Add comment", security: [{ bearerAuth: [] }], responses: { "201": { description: "Created" } } } },
    "/activities": { get: { summary: "Get user activity summary", security: [{ bearerAuth: [] }], responses: { "200": { description: "Statistics" } } } },
    "/lists": {
      get: { summary: "Get personal lists", security: [{ bearerAuth: [] }], responses: { "200": { description: "Lists" } } },
      post: { summary: "Create a personal list", security: [{ bearerAuth: [] }], responses: { "201": { description: "Created" } } }
    },
    "/reports/comments/{commentId}": { post: { summary: "Report a comment", security: [{ bearerAuth: [] }], responses: { "201": { description: "Reported" } } } },
    "/admin/users": { get: { summary: "List users", security: [{ bearerAuth: [] }], responses: { "200": { description: "Users" } } } },
    "/admin/stats": { get: { summary: "Get system statistics", security: [{ bearerAuth: [] }], responses: { "200": { description: "Statistics" } } } },
    "/admin/reports": { get: { summary: "Review reports", security: [{ bearerAuth: [] }], responses: { "200": { description: "Reports" } } } }
  }
};
