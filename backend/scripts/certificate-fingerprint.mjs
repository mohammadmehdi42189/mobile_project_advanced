import { createHash } from "node:crypto";
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import process from "node:process";
import tls from "node:tls";

const [address, output] = process.argv.slice(2);

if (!address) {
  throw new Error(
    "Usage: npm run certificate:fingerprint -- https://api.example.com/api/v1 [output.json]"
  );
}

const url = new URL(address);
if (url.protocol !== "https:") {
  throw new Error("The backend URL must use HTTPS.");
}

const certificate = await new Promise((resolveCertificate, reject) => {
  const socket = tls.connect(
    {
      host: url.hostname,
      port: Number(url.port || 443),
      servername: url.hostname,
      rejectUnauthorized: true
    },
    () => {
      const peer = socket.getPeerCertificate();
      socket.end();
      if (!peer.raw) {
        reject(new Error("The server did not provide a certificate."));
        return;
      }
      resolveCertificate(peer.raw);
    }
  );
  socket.setTimeout(10_000, () => socket.destroy(new Error("Connection timed out.")));
  socket.on("error", reject);
});

const fingerprint = createHash("sha256")
  .update(certificate)
  .digest("hex")
  .toUpperCase();

if (!output) {
  console.log(fingerprint);
} else {
  const outputPath = resolve(output);
  mkdirSync(dirname(outputPath), { recursive: true });
  writeFileSync(
    outputPath,
    `${JSON.stringify(
      {
        ADVANCED_MODE: true,
        BACKEND_BASE_URL: address.replace(/\/$/, ""),
        BACKEND_CERT_SHA256: fingerprint
      },
      null,
      2
    )}\n`,
    { mode: 0o600 }
  );
  console.log(`Created ${outputPath}`);
}
