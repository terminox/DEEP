# deep-api

Backend for the Deep app — auth (email/password), onboarding, and Deep Sound content. Fastify + Prisma + Postgres (TypeScript).

## Requirements
- Node 22+
- Docker (for local Postgres)

## First-time setup

```bash
npm install
cp .env.example .env          # already present for local dev
npm run db:up                 # start Postgres (docker, host port 5434)
npm run db:migrate            # apply schema
npm run db:seed               # seed 5 categories / 20 collections / 67 tracks + onboarding config
npm run dev                   # start on http://localhost:8080 (watch mode)
```

The first run bootstraps an admin from `ADMIN_BOOTSTRAP_EMAIL` / `ADMIN_BOOTSTRAP_PASSWORD`
(default `admin@deep.local` / `deepadmin123`).

Optional: set `MAXMIND_LICENSE_KEY` and run `npm run geoip:update` to enable real IP-based
locations for Global Pause participants; without it, participants fall back to locale-country
presence only. To exercise the globe without real participants, use
`scripts/pause-fake-location.sh` (`off` / `fixed` / `scatter` / `drip`) against a server running
with `ALLOW_TIME_OVERRIDE=true`.

> Ports: Postgres is on **5434** (5432/5433 are used by the sibling caregiver/heartlog
> projects). The API is on **8080**.

## API surface

Auth (public): `POST /auth/signup`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`, `GET /me`
Onboarding: `GET /onboarding/config`, `GET /me/onboarding`, `PUT /me/onboarding`
Deep Sound (public): `GET /sound/home`, `GET /sound/collections/:id`, `GET /sound/tracks/:id/lyrics?lang=`
Media: `GET /media/audio/:file` (supports HTTP range → streaming)
Admin (role=ADMIN): `POST /admin/auth/login`; CRUD + `/reorder` for `/admin/categories`,
`/admin/collections`, `/admin/tracks`; `POST /admin/tracks/:id/audio` (multipart);
`GET|PUT|DELETE /admin/tracks/:id/lyrics[/:lang]`; `GET /admin/users`.

Auth is JWT access token + rotating refresh session (reuse detection revokes the session).

## Scripts
`dev` · `start` · `build` · `typecheck` · `test` · `db:up` · `db:down` · `db:migrate` · `db:reset` · `db:seed` · `geoip:update`
