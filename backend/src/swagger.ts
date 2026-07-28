const errorResponse = {
  description: "Request failed",
  content: {
    "application/json": {
      schema: { $ref: "#/components/schemas/Error" },
      example: {
        error: {
          code: "VALIDATION_ERROR",
          message: "Invalid request",
          details: {}
        }
      }
    }
  }
};

const secured = [{ bearerAuth: [] }];

export const swaggerDocument = {
  openapi: "3.0.3",
  info: {
    title: "Movie Tracker Backend API",
    version: "1.1.0",
    description: "Complete API contract for the advanced mobile project"
  },
  servers: [{ url: "/api/v1", description: "Current server" }],
  components: {
    securitySchemes: {
      bearerAuth: { type: "http", scheme: "bearer", bearerFormat: "JWT" }
    },
    schemas: {
      Credentials: {
        type: "object",
        required: ["email", "password"],
        properties: {
          email: { type: "string", format: "email", example: "user@example.com" },
          password: { type: "string", minLength: 8, example: "StrongPass123!" }
        }
      },
      User: {
        type: "object",
        properties: {
          id: { type: "string" },
          name: { type: "string" },
          email: { type: "string", format: "email" },
          bio: { type: "string" },
          avatarUrl: { type: "string", format: "uri", nullable: true },
          role: { type: "string", enum: ["USER", "ADMIN"] }
        }
      },
      Media: {
        type: "object",
        properties: {
          id: { type: "string", example: "tt0133093" },
          type: { type: "string", enum: ["movie", "series"] },
          title: { type: "string", example: "The Matrix" },
          year: { type: "integer", nullable: true },
          plot: { type: "string", nullable: true },
          posterUrl: { type: "string", format: "uri", nullable: true },
          genres: { type: "string", nullable: true },
          cast: { type: "string", nullable: true },
          director: { type: "string", nullable: true },
          country: { type: "string", nullable: true },
          runtimeMinutes: { type: "integer", nullable: true },
          imdbRating: { type: "number", nullable: true },
          totalSeasons: { type: "integer", nullable: true }
        }
      },
      Error: {
        type: "object",
        properties: {
          error: {
            type: "object",
            required: ["code", "message"],
            properties: {
              code: { type: "string" },
              message: { type: "string" },
              details: { nullable: true }
            }
          }
        }
      }
    }
  },
  paths: {
    "/auth/register": {
      post: {
        summary: "Register a user",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                allOf: [
                  { $ref: "#/components/schemas/Credentials" },
                  {
                    type: "object",
                    required: ["name"],
                    properties: { name: { type: "string", example: "Alex" } }
                  }
                ]
              }
            }
          }
        },
        responses: {
          "201": { description: "User and JWT created" },
          "400": errorResponse,
          "409": errorResponse
        }
      }
    },
    "/auth/login": {
      post: {
        summary: "Log in",
        requestBody: {
          required: true,
          content: {
            "application/json": { schema: { $ref: "#/components/schemas/Credentials" } }
          }
        },
        responses: {
          "200": { description: "User and JWT" },
          "401": errorResponse
        }
      }
    },
    "/auth/password-reset/request": {
      post: {
        summary: "Email a password reset code",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["email"],
                properties: { email: { type: "string", format: "email" } }
              }
            }
          }
        },
        responses: { "204": { description: "Request accepted" }, "503": errorResponse }
      }
    },
    "/auth/password-reset/confirm": {
      post: {
        summary: "Confirm password reset",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["email", "token", "password"],
                properties: {
                  email: { type: "string", format: "email" },
                  token: { type: "string", minLength: 8, maxLength: 8 },
                  password: { type: "string", minLength: 8 }
                }
              }
            }
          }
        },
        responses: { "204": { description: "Password changed" }, "400": errorResponse }
      }
    },
    "/profile": {
      get: {
        summary: "Get profile",
        security: secured,
        responses: {
          "200": {
            description: "Current profile",
            content: {
              "application/json": { schema: { $ref: "#/components/schemas/User" } }
            }
          },
          "401": errorResponse
        }
      },
      patch: {
        summary: "Update profile",
        security: secured,
        requestBody: {
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  name: { type: "string" },
                  bio: { type: "string", maxLength: 300 },
                  avatarUrl: { type: "string", format: "uri", nullable: true }
                }
              }
            }
          }
        },
        responses: { "200": { description: "Updated profile" }, "400": errorResponse }
      }
    },
    "/media/search": {
      get: {
        summary: "Search movies and series",
        parameters: [
          { name: "q", in: "query", required: true, schema: { type: "string" } },
          { name: "page", in: "query", schema: { type: "integer", minimum: 1, default: 1 } },
          { name: "type", in: "query", schema: { type: "string", enum: ["movie", "series"] } },
          { name: "year", in: "query", schema: { type: "integer", minimum: 1888 } }
        ],
        responses: { "200": { description: "Paginated search results" }, "502": errorResponse }
      }
    },
    "/media/{id}": {
      get: {
        summary: "Get normalized media details",
        parameters: [
          { name: "id", in: "path", required: true, schema: { type: "string", pattern: "^tt\\d+$" } }
        ],
        responses: {
          "200": {
            description: "Media details",
            content: {
              "application/json": { schema: { $ref: "#/components/schemas/Media" } }
            }
          },
          "404": errorResponse
        }
      }
    },
    "/media/{id}/seasons/{season}": {
      get: {
        summary: "Get season episodes",
        parameters: [
          { name: "id", in: "path", required: true, schema: { type: "string" } },
          { name: "season", in: "path", required: true, schema: { type: "integer", minimum: 1 } }
        ],
        responses: { "200": { description: "Season and episode details" }, "404": errorResponse }
      }
    },
    "/watchlist": {
      get: {
        summary: "Get personal watchlist",
        security: secured,
        responses: { "200": { description: "Watchlist items" }, "401": errorResponse }
      }
    },
    "/watchlist/{mediaId}": {
      put: {
        summary: "Create or update watch state",
        security: secured,
        parameters: [
          { name: "mediaId", in: "path", required: true, schema: { type: "string" } }
        ],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["status"],
                properties: {
                  status: {
                    type: "string",
                    enum: ["PLANNED", "WATCHING", "COMPLETED", "DROPPED", "FAVORITE"]
                  },
                  watchedEpisodes: { type: "integer", minimum: 0 }
                }
              }
            }
          }
        },
        responses: { "200": { description: "Updated item" }, "401": errorResponse }
      },
      delete: {
        summary: "Remove a watchlist item",
        security: secured,
        responses: { "204": { description: "Removed" }, "401": errorResponse }
      }
    },
    "/ratings/{mediaId}": {
      put: {
        summary: "Create or update a rating",
        security: secured,
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["value"],
                properties: { value: { type: "integer", minimum: 1, maximum: 10 } }
              }
            }
          }
        },
        responses: { "200": { description: "Saved rating" }, "400": errorResponse }
      }
    },
    "/comments/{mediaId}": {
      post: {
        summary: "Create a comment",
        security: secured,
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["text"],
                properties: {
                  text: { type: "string", maxLength: 1000 },
                  spoiler: { type: "boolean", default: false }
                }
              }
            }
          }
        },
        responses: { "201": { description: "Created comment" }, "400": errorResponse }
      },
      patch: {
        summary: "Update the current user's comment",
        security: secured,
        responses: { "200": { description: "Updated comment" }, "404": errorResponse }
      },
      delete: {
        summary: "Delete the current user's comment",
        security: secured,
        responses: { "204": { description: "Deleted comment" }, "404": errorResponse }
      }
    },
    "/media/{mediaId}/comments": {
      get: {
        summary: "Get public comments for media",
        responses: { "200": { description: "Comments with author metadata" } }
      }
    },
    "/comments": {
      get: {
        summary: "Get the current user's comments",
        security: secured,
        responses: { "200": { description: "Comments and media details" } }
      }
    },
    "/media/{mediaId}/ratings": {
      get: {
        summary: "Get rating distribution",
        responses: { "200": { description: "Percentages for ratings 1 through 10" } }
      }
    },
    "/ratings": {
      get: {
        summary: "Get the current user's ratings",
        security: secured,
        responses: { "200": { description: "Ratings and media details" } }
      }
    },
    "/episodes/progress": {
      get: {
        summary: "Get watched episodes",
        security: secured,
        responses: { "200": { description: "Per-season episode progress" } }
      }
    },
    "/episodes/{mediaId}/{season}/{episode}": {
      put: {
        summary: "Mark an episode as watched",
        security: secured,
        responses: { "200": { description: "Saved progress" }, "400": errorResponse }
      },
      delete: {
        summary: "Mark an episode as unwatched",
        security: secured,
        responses: { "204": { description: "Removed progress" } }
      }
    },
    "/lists": {
      get: {
        summary: "Get personal lists and items",
        security: secured,
        responses: { "200": { description: "Personal lists" } }
      },
      post: {
        summary: "Create a personal list",
        security: secured,
        requestBody: {
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["name"],
                properties: { name: { type: "string", maxLength: 80 } }
              }
            }
          }
        },
        responses: { "201": { description: "Created list" }, "400": errorResponse }
      }
    },
    "/lists/{listId}": {
      delete: {
        summary: "Delete a personal list",
        security: secured,
        responses: { "204": { description: "Deleted list" }, "404": errorResponse }
      }
    },
    "/lists/{listId}/items/{mediaId}": {
      put: {
        summary: "Add media to a personal list",
        security: secured,
        responses: { "200": { description: "Added item" }, "404": errorResponse }
      },
      delete: {
        summary: "Remove media from a personal list",
        security: secured,
        responses: { "204": { description: "Removed item" }, "404": errorResponse }
      }
    },
    "/reports/comments/{commentId}": {
      post: {
        summary: "Report a comment",
        security: secured,
        responses: { "201": { description: "Created report" }, "400": errorResponse }
      }
    },
    "/activities": {
      get: {
        summary: "Get user activity statistics",
        security: secured,
        responses: { "200": { description: "Complete activity statistics" } }
      }
    },
    "/admin/users": {
      get: {
        summary: "List users",
        security: secured,
        responses: { "200": { description: "Users" }, "403": errorResponse }
      }
    },
    "/admin/users/{id}": {
      patch: {
        summary: "Update a user's role or active state",
        security: secured,
        responses: { "200": { description: "Updated user" }, "403": errorResponse }
      }
    },
    "/admin/comments/{id}": {
      delete: {
        summary: "Delete an inappropriate comment",
        security: secured,
        responses: { "204": { description: "Deleted comment" }, "403": errorResponse }
      }
    },
    "/admin/reports": {
      get: {
        summary: "Review comment reports",
        security: secured,
        responses: { "200": { description: "Reports" }, "403": errorResponse }
      }
    },
    "/admin/reports/{id}": {
      patch: {
        summary: "Resolve or reopen a report",
        security: secured,
        responses: { "200": { description: "Updated report" }, "403": errorResponse }
      }
    },
    "/admin/stats": {
      get: {
        summary: "Get system statistics",
        security: secured,
        responses: { "200": { description: "System statistics" }, "403": errorResponse }
      }
    }
  }
};
