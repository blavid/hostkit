# hostkit

HostKit turns a short-term rental's guest guide into a Roku channel, a Cloudflare Worker API, and a host wizard + marketing site. One JSON document (schema v1) drives TV and web.

## Folders

| Path | Owner | Purpose |
|------|-------|---------|
| `roku/` | Rocky | SceneGraph channel |
| `worker/` | Rocky | Cloudflare Worker API + KV (`HOSTKIT`) |
| `web/` | Web | Host wizard + marketing (static export, base `/hostkit-preview`) |
| `schema/` | Shared | `hostkit.v1.schema.json` + fixtures |

## Rules

- **No secrets in git.** Use `{{PLACEHOLDER}}` tokens (see SPEC Appendix B). Real Wi-Fi, door codes, phones, and API tokens live in Worker secrets / vault only.
- **Branches and PRs only.** Nothing merges to production without Blake.
- **Do not touch** the live Eaglewood site (`sunriver-web`), the `eaglewood-tv` Worker, or `/tv/*`.
- Preview deploys go to a **new** Cloudflare Pages project `hostkit-preview` (pages.dev URL for now). Path routing on `sunrivertownhome.com/hostkit-preview/*` is not set up yet.
- The Worker preview uses `workers_dev = true` only — no custom routes on sunrivertownhome.com.

## Scripts

```bash
npm install
npm run validate   # AJV against schema fixtures
npm run scan       # fail on likely secrets in committed files
npm test           # secrets-scan tests (+ worker tests when present)
npm run build:web  # static export to web/dist
```

See `/workspace/product/SPEC.md` for the Phase 0 / M1 spec (or `docs/SPEC.md` once copied into this repo).
