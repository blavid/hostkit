# worker/

Rocky owns the HostKit Cloudflare Worker API (`hostkit-api-preview`) and its tests.

KV binding: `HOSTKIT` (never the Eaglewood `GUEST` namespace). Preview uses `workers_dev = true` only — no routes on sunrivertownhome.com.

M1 CI will run `npm test` here when `worker/package.json` exists; until then the job skips. Deploy on push to `main` is similarly gated.
