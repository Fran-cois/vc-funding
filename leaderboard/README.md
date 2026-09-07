# vc-funding-leaderboard

Cloudflare Worker + D1 backend for vc-funding's opt-in weekly leaderboard (see the main [README](../README.md#weekly-leaderboard)).

No authentication: `handle` is whatever the client sends, so treat scores as for-fun, not verified. A best-effort per-IP rate limit (20 submits/hour) guards `/submit`.

## Endpoints

- `POST /submit` — body `{ "handle": string, "maxedCounts": { [agent]: number }, "costsUSD": { [agent]: number } }`. The server computes its own ISO week id from server time (never trusts a client-supplied week) and upserts one row per `(week, handle)`.
- `GET /leaderboard?weekId=&limit=` — returns the top entries (default current week, default 10, max 50) for both prize categories.

## Deploy

```sh
npm install
npx wrangler d1 create vc-funding-leaderboard   # then paste the database_id into wrangler.jsonc
npm run db:init                                  # applies schema.sql to the remote D1 database
npm run deploy
```

## Local development

```sh
npm run dev
```

Uses local D1 simulation by default (no `--remote`), so it won't touch production data.
