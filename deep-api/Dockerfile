# Production image for the Deep backend.
#
# Debian slim (not alpine): Prisma's query engine links OpenSSL and is unreliable
# on musl. We run the app directly with `tsx` — matching the repo's own `start`
# script — so the prisma CLI + tsx that ship as devDeps also serve the migrate
# Job (`npx prisma migrate deploy`) and the one-off seed (`npx tsx prisma/seed.ts`).

FROM node:22-slim

# Prisma's engine needs OpenSSL + CA certs present at runtime.
RUN apt-get update \
  && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Full dependency tree (tsx + prisma CLI are devDeps but needed at runtime here,
# so NODE_ENV=production must NOT be set yet — it would make npm omit devDeps).
# Layer-cached on the lockfile.
COPY package.json package-lock.json ./
RUN npm ci --ignore-scripts

ENV NODE_ENV=production

# Generate the Prisma client AFTER copying the schema: with --ignore-scripts the
# @prisma/client postinstall never ran, so this explicit generate is required.
# Migrations ship in the image too, for the migrate Job.
COPY prisma ./prisma
RUN npx prisma generate

# Application source (ESM, executed directly by tsx — no build output).
COPY src ./src

# The three committed tracks: prisma/seed.ts requires media/audio/*.mp3 relative
# to cwd, and the first deploy copies these same files into the media bucket.
COPY media ./media

# Drop privileges: the official node image ships an unprivileged `node` user.
USER node

# Cloud Run injects PORT=8080; src/env.ts already reads process.env.PORT.
EXPOSE 8080
CMD ["npx", "tsx", "src/server.ts"]
