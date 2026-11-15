
## QR decode test dependency

`tests/qr.test.js` decodes the pairing QR PNG back to its URL with Python
(`zxing-cpp`, `pillow`, `opencv-python-headless`). Point `HOSTKIT_QR_PYTHON` at a
Python that has them; otherwise the test creates `/tmp/hostkit-qrvenv`, which
needs `python3 -m venv` (Debian/Ubuntu: the `python3-venv` package). CI installs
the decoder explicitly in the Worker tests job.

## Production settings (host-kit.com)

The Worker answers on `https://api.host-kit.com` (custom domain) and on
`https://hostkit-api-preview.blakeclough.workers.dev`. No code change is
needed for the domain; set these vars and keep `KV`, `HOST_TOKEN` and
`PREVIEW_SIGNUP` as they are:

| Var | Value | Effect |
|---|---|---|
| `PUBLIC_BASE` | `https://api.host-kit.com` | `shortUrl` = `https://api.host-kit.com/pair/CODE`; `qrUrl` on the same host |
| `WIZARD_URL` | `https://host-kit.com/` | `GET /pair/CODE` 302s to `https://host-kit.com/?code=CODE` (code is added with `searchParams.set`) |

Keep `PUBLIC_BASE` on the API host: it also builds `qrUrl` (`/v1/pair/qr`), which only the Worker serves.
