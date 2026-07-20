import { buildApp } from "./app.js";
import { env } from "./env.js";
import { bootstrapAdmin } from "./bootstrap.js";
import { prisma } from "./prisma.js";

async function main() {
  const app = buildApp();

  await bootstrapAdmin(app.log);

  await app.listen({ host: env.HOST, port: env.PORT });
  app.log.info(`Deep API listening on ${env.PUBLIC_BASE_URL}`);

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
