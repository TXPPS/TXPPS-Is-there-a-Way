# Deploy

Every push to `main` or a `claude/**` branch builds and smoke-tests. **Only the
repository's default branch publishes.**

Both deploy jobs are gated on `needs.probe.outputs.is_default`, which the
`probe` job computes by asking the GitHub API what the default branch is **now**
and comparing it to `github.ref_name`.

The obvious expression — `github.ref_name == github.event.repository.default_branch`
— was there first, and it is a trap. The payload half is a *snapshot* taken when
the event was created, and it goes stale two ways, both of which happened here:

- **a re-run replays the original event's payload**, so a job re-run hours later
  is gated on what was true when the first attempt started;
- **the push event a branch rename produces can still carry the branch's old
  name** as `default_branch`.

Run #13 was a genuine `push` (not a `workflow_dispatch`) with
`head_branch: main`, re-run as attempt 2 after Pages was switched on. Its
`github.ref_name` was `main` and its payload disagreed, so both deploy jobs
skipped and the build went green with nothing published. An API call cannot be
stale, so that is what the gate reads now.

Every run prints a **Deploy gate** table into the `probe` job's summary: the
event and attempt, `ref_name`, the live default branch, the payload's version of
it, and the decision. A deploy that does not happen always says why.

The gate is deliberately independent of event type, so a `workflow_dispatch` on
the default branch publishes exactly like a push — which is the only way to
trigger a deploy by hand from a phone without editing a file.

---

## Current state

| | |
|---|---|
| GitHub Pages | **not switched on.** The build is green and the artifact is uploaded; the site has nowhere to go. One switch, below. |
| Cloudflare Pages | **no credentials.** The `probe` job reports this and the deploy job skips. Two secrets, below. |

Until one of those is done there is no URL. Neither can be automated from here —
`GITHUB_TOKEN` is not permitted to create a Pages site whatever permissions the
workflow requests, and a Cloudflare token can only be minted by its owner.

---

## Target 1 — GitHub Pages (fewest taps, no account needed)

Free, because the repo is public. One manual switch, once:

1. `github.com/TXPPS/TXPPS-Is-there-a-Way` → **Settings** → **Pages**
2. Under *Build and deployment*, set **Source** to **GitHub Actions**
3. **Actions** → the latest run → **Re-run all jobs**

URL once enabled: `https://txpps.github.io/TXPPS-Is-there-a-Way/`

If it is not switched on, `deploy-pages` prints these instructions into the run
summary and **fails**. It used to be `continue-on-error`, which meant a build
could go green having published nothing — the exact failure this pipeline exists
to prevent.

Caveats versus Cloudflare:

- **`web/_headers` is ignored.** GitHub applies its own caching, which is
  weaker than the contract in that file. In practice this costs repeat-load
  time, not correctness: the service worker holds the payload, and the update
  path does not depend on the headers (`index.html` is fetched
  `cache: 'reload'` with a cache-busting query, and navigation through the
  worker is network-first).
- The site is served from a subpath. Everything in the export uses relative
  paths, so this works — keep it that way.

## Target 2 — Cloudflare Pages (better caching, needs a token)

**If the goal is a URL today, GitHub Pages is fewer taps.** Cloudflare is worth
doing because it is the only target that honours `web/_headers`, which is where
the caching contract lives: `application/wasm` for the engine, one-year
`immutable` for the content-hashed payload, `no-cache` for `index.html`, the
manifest and the service worker.

### Minting the token

`dash.cloudflare.com` → profile menu → **API Tokens** → **Create Token** →
**Create Custom Token**:

| Field | Value |
|---|---|
| Permissions | **Account** · **Cloudflare Pages** · **Edit** |
| Account Resources | **Include** · your account |
| TTL / IP filtering | leave empty |

That single permission is the whole requirement — it covers both
`wrangler pages project create` and `wrangler pages deploy`. The **Edit
Cloudflare Workers** template also works but grants far more than this needs.
Copy the token; Cloudflare shows it exactly once.

The account ID is on the right-hand side of any domain's overview page, and in
the dashboard URL itself: `dash.cloudflare.com/<account-id>/...`

### Storing it

Repo → **Settings** → **Secrets and variables** → **Actions** → **New
repository secret**, twice:

| Name | Value |
|---|---|
| `CLOUDFLARE_API_TOKEN` | the token |
| `CLOUDFLARE_ACCOUNT_ID` | the account ID |

Then **Actions** → the latest run → **Re-run all jobs**.

The workflow creates the project on first run and deploys to it thereafter. The
Cloudflare "branch" is pinned to the constant `production`, not the git branch
name: this job only runs on the default branch so every deploy here *is*
production, and a git branch name containing a slash would otherwise land as a
preview deploy at an unpredictable URL. The live URL is printed in the job
summary.

---

## The update path

The service worker is generated by Godot and then reworked by
`tools/ci/service_worker.py`, which asserts every edit it makes — if Godot's
template changes shape, the build fails loudly instead of shipping an unpatched
worker. Four changes, and every one of them is tested by
`tools/web/smoke_pwa.js` (see `docs/TESTING.md`):

1. **The cache is named after the build.** `CACHE_VERSION` is a hash of every
   file the worker caches, so a rebuild is a different cache and the old one is
   deleted on activation.
2. **A new worker takes over immediately** — `skipWaiting()` plus
   `clients.claim()` — instead of waiting for every tab to close. On an
   installed iOS PWA, "every tab closed" can be never.
3. **Navigation is network-first**, falling back to the cached document and then
   to the offline page. `index.html` names the content-hashed payload, so
   serving it from cache would pin you to whichever build you first loaded.
   Engine assets stay cache-first, which is what makes the game work offline.
4. **`?fresh=1` bypasses the worker entirely** — see below.

5. **Navigation preload is switched back off**, because nothing reads it.

The navigate branch deliberately ignores `event.preloadResponse`. Godot's
`fetchAndCache` awaits it, and a navigation preload that rejects sends the
request down the cache fallback — serving the previous build's `index.html`,
whose payload the deploy you are trying to pick up has already deleted. That
failure is a dead page that reloading cannot fix. Since nothing reads the
preload, leaving it enabled would just mean a second discarded request for
`index.html` on every navigation, so the worker turns it off after Godot's own
handler turns it on.

### The "New version — tap to reload" banner

The shell asks the server for `index.html` and compares it to what is running:
the content-hashed payload name, and the commit in `window.ITAW_BUILD`. Two
signals because they catch different things — the payload name misses a change
that only touched the shell, and there is no payload rename for a shell-only
fix. Checks run on becoming visible, on focus, on a service-worker
`controllerchange`, and every five minutes, throttled to one check per twenty
seconds.

**Detection runs at any time; the banner does not appear at any time.** It waits
for a moment the player is already out of the fiction:

- the tap gate, before the game has started;
- a menu, when the game calls `window.__itaw_setUpdateGate(true)`;
- the first moment after coming back from the home screen.

An update found mid-corridor is held until one of those happens.

### `?fresh=1` — the escape hatch

Append it to the URL: `https://…/index.html?fresh=1`

It deletes every Cache Storage entry and unregisters every service worker for
the origin, waits for both to finish, and only then reloads onto the clean URL.
**Saves are not touched** — this clears the code, not the player. If the purge
somehow hangs, it reloads anyway after six seconds.

The bypass is what makes it work when everything else is broken. The worker
refuses to answer any request whose URL *or whose referrer* carries `fresh=1`,
returning without calling `respondWith()` so the browser fetches as though no
worker existed. The referrer half is the half that matters: the document carries
`fresh=1` but the scripts it then loads do not, and a poisoned engine payload
would otherwise break the page before the escape hatch ever ran.

Use it when the corner build stamp does not match the commit you expect, or when
the game will not start at all. It is faster and far less destructive than
Safari → Settings → Clear History and Website Data, which nukes every site you
have ever visited.

### You should rarely need to type it

The page climbs the ladder for you. If the engine payload will not load — the
signature of a cached document from a previous build naming files the current
deploy has removed — the shell purges and reloads through `?fresh=1` on its own,
once per tab, and shows "Recovering" while it does. If that clean load fails
too, it stops trying and shows the fault with a **Reload cleanly** button rather
than looping. Typing `?fresh=1` by hand is the third rung, for when the page
never got far enough to run any of this.

---

## The build is not green until the site answers

A `verify` job runs after every deploy and asserts two things no other job can:

1. **On the default branch, `deploy-pages` must have run and succeeded.** A
   skipped deploy job is a failure, not a neutral outcome. This is what makes a
   silently ungated deploy impossible to mistake for a green build.
2. **The published URL must actually serve this build.** `tools/ci/verify_live.sh`
   fetches the live document, checks it is our shell, reads `window.ITAW_BUILD`
   out of it and requires the commit to match the one that just deployed — a
   stale site fails — then pulls every file `index.html` names and checks each
   for a 200, for a content type that is not a 404 page wearing a 200, and, for
   the wasm, for `application/wasm` specifically. Without that type the engine
   cannot stream-compile and buffers the whole 37 MB first.

## Deploying by hand

```sh
# Build exactly what CI builds
GODOT=/path/to/godot bash tools/ci/build_web.sh

# Smoke-test it in a headless browser
npm --prefix tools/web ci
node tools/web/smoke_web.js build build-smoke
node tools/web/smoke_pwa.js build

# Push it
cd tools/web && npx wrangler pages deploy ../../build --project-name is-there-a-way
```

`wrangler` opens a browser to authenticate if `CLOUDFLARE_API_TOKEN` is not set.

## Serving the build locally

```sh
python3 -m http.server 8000 --directory build
```

Any static server works: the export needs no COOP/COEP headers, which is the
entire point of the single-threaded variant. A service worker will not install
over plain `http://` except on `localhost`.

## If a build looks wrong on the phone

The corner stamp shows `v<version> <commit>`. Tap it to copy the full report —
branch, build time, payload hash, storage health, worker state, viewport, safe
area and user agent — which is what to paste into a bug report.

1. Stamp does not match the commit you expect → reload. `index.html` and the
   worker are `no-cache` and navigation is network-first, so one reload should
   do it. If not, `?fresh=1`.
2. Game will not start, or starts wrong → `?fresh=1`.
3. Neither works → the deploy did not run. Check the workflow run's job list.
