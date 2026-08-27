# Deploy

Every push to `main` or a `claude/**` branch builds, smoke-tests, and publishes.
Two targets, both configured in `.github/workflows/build-and-deploy.yml`.

---

## Target 1 — Cloudflare Pages (primary)

Deploys automatically **once two repository secrets exist**. Until then the
workflow says so in its log and skips the job. Nothing else needs changing.

### Setting it up from a phone (about three minutes)

1. **Create the API token.**
   Go to `dash.cloudflare.com` → profile menu → **API Tokens** → **Create Token**
   → use the **"Edit Cloudflare Workers"** template, or create a custom token
   with just:
   - Permission: **Account · Cloudflare Pages · Edit**
   - Account resources: **Include · your account**

   Copy the token. Cloudflare shows it exactly once.

2. **Find the account ID.** It is on the right-hand side of any domain's
   overview page in the dashboard, and in the URL of the dashboard itself:
   `dash.cloudflare.com/<account-id>/...`

3. **Add both to GitHub.** Repo → **Settings** → **Secrets and variables** →
   **Actions** → **New repository secret**, twice:

   | Name | Value |
   |---|---|
   | `CLOUDFLARE_API_TOKEN` | the token from step 1 |
   | `CLOUDFLARE_ACCOUNT_ID` | the ID from step 2 |

4. Re-run the latest workflow (**Actions** → the run → **Re-run all jobs**), or
   just push again.

The workflow creates the Pages project on first run
(`wrangler pages project create is-there-a-way`) and deploys to it thereafter.
The live URL is printed in the job summary and appears as the deployment URL on
the run page.

### Why Cloudflare is the primary target

`web/_headers` is a Cloudflare Pages feature, and it is where the caching
contract lives: `application/wasm` for the engine, one-year `immutable` for the
content-hashed payload, `no-cache` for `index.html` and the service worker.
GitHub Pages ignores `_headers` and applies its own, weaker, caching.

---

## Target 2 — GitHub Pages (fallback, always on)

Runs on every push regardless of Cloudflare, on the free tier because the repo
is public. The workflow enables Pages itself via `actions/configure-pages`
(`enablement: true`), so there is nothing to click.

URL: `https://txpps.github.io/TXPPS-Is-there-a-Way/`

The job is marked `continue-on-error`, so if an environment branch policy
refuses a deployment from a non-default branch, the build still passes and
Cloudflare (once configured) is unaffected. If that happens, either merge to
`main` or add the branch under **Settings → Environments → github-pages →
Deployment branches**.

Caveats versus Cloudflare:
- `_headers` is ignored; caching is GitHub's default.
- The site is served from a subpath. Everything in the export uses relative
  paths, so this works — but keep it that way.

---

## Deploying by hand

```sh
# Build exactly what CI builds
GODOT=/path/to/godot bash tools/ci/build_web.sh

# Smoke-test it in a headless browser
npm --prefix tools/web ci
node tools/web/smoke_web.js build build-smoke

# Push it
cd tools/web && npx wrangler pages deploy ../../build --project-name is-there-a-way
```

`wrangler` will open a browser to authenticate if `CLOUDFLARE_API_TOKEN` is not
set in the environment.

## Serving the build locally

```sh
python3 -m http.server 8000 --directory build
```

Any static server works: the export needs no COOP/COEP headers, which is the
entire point of the single-threaded variant. Note that a service worker will not
install over plain `http://` except on `localhost`.

## If a build goes wrong on the phone

The corner stamp shows `v<version> <commit>`. If it does not match the commit you
expect:

1. The service worker is serving a cached build. Force it: Safari → **Settings →
   Safari → Clear History and Website Data**, or delete and re-add the home-screen
   app. (`index.html` and the service worker are `no-cache`, so this should
   resolve itself on a reload — but the PWA is aggressive by design.)
2. The deploy job did not run. Check the workflow run's job list.
