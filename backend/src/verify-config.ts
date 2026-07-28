import { config } from "./config.js";
import { createEmailTransport } from "./email-service.js";

async function main() {
  const required = {
    OMDB_API_KEY: config.OMDB_API_KEY,
    SMTP_HOST: config.SMTP_HOST,
    SMTP_USER: config.SMTP_USER,
    SMTP_PASSWORD: config.SMTP_PASSWORD
  };

  const missing = Object.entries(required)
    .filter(([, value]) => !value)
    .map(([key]) => key);

  if (missing.length > 0) {
    throw new Error(`Missing configuration: ${missing.join(", ")}`);
  }

  const omdbResponse = await fetch(
    `https://www.omdbapi.com/?apikey=${encodeURIComponent(config.OMDB_API_KEY!)}&i=tt0111161`
  );
  const omdbData = (await omdbResponse.json()) as {
    Response?: string;
    Error?: string;
  };

  if (!omdbResponse.ok || omdbData.Response !== "True") {
    throw new Error(omdbData.Error ?? "OMDb configuration check failed");
  }

  await createEmailTransport().verify();
  console.log("OMDb and SMTP configuration is valid.");
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : "Configuration check failed");
  process.exitCode = 1;
});
