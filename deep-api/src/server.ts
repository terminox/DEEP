import { buildApp } from "./app.js";
import { env } from "./env.js";
import { bootstrapAdmin } from "./bootstrap.js";
import { prisma } from "./prisma.js";

async function main() {
  const app = buildApp();

  await bootstrapAdmin(app.log);

  await app.listen({ host: env.HOST, port: env.PORT });
  if (env.PUBLIC_BASE_URL) {
    app.log.info(
      `Deep API on ${env.HOST}:${env.PORT} - media URLs pinned to ${env.PUBLIC_BASE_URL}`,
    );
  } else {
    // Unset is the local-dev default: media URLs follow whatever host the client
    // used, so there is no single URL to print. Deliberately not guessing the
    // device-facing host here — scripts/dev-setup.sh is its one source of truth,
    // and echoing a DHCP IP would invite copying the value we just stopped needing.
    app.log.info(
      `Deep API on ${env.HOST}:${env.PORT} - http://localhost:${env.PORT} (simulator); device host comes from scripts/dev-setup.sh`,
    );
  }

  const shutdown = async () => {
    await app.close();
    await prisma.$disconnect();
    process.exit(0);
  };
  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
