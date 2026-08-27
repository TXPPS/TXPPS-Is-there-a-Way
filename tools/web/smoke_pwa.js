/**
 * The update path, exercised end to end against a real service worker.
 *
 * A cache-first PWA that goes wrong is unfixable from a phone, so every promise
 * docs/DEPLOY.md makes about getting out of a bad build is asserted here:
 *
 *   A  install    the worker takes over, keys its cache to the build, caches the
 *                 payload, and serves the game with the network switched off
 *   B  update     a rebuild is detected while the game is running, the banner is
 *                 withheld mid-scene and released on return from background, and
 *                 taking it swaps the live build and deletes the old cache
 *   C  gate       the same banner is also released by opening a menu
 *   D  recovery   a poisoned cache entry breaks the build, and ?fresh=1 still
 *                 loads: it bypasses the worker, purges, and reloads clean
 *
 *   npm --prefix tools/web run smoke:pwa
 *   node tools/web/smoke_pwa.js <build-dir>
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { serve, openBrowser, tally } = require('./harness');

const BUILD = path.resolve(process.argv[2] || 'build');
const FORGED = `${BUILD}-forged`;
const BROKEN = `${BUILD}-broken`;
const PORT = 8098;
const ORIGIN = `http://127.0.0.1:${PORT}`;
const GATE = '#begin:not([hidden])';

// What the next deploy looks like: a different payload hash and a different
// commit, because the shell checks both.
const FORGED_HASH = 'deadbeef01';
const FORGED_COMMIT = 'facade7000000000000000000000000000000000';
const FORGED_CACHE = 'facade0000feed01';
const FORGED_MARK = 'itaw-forged';
const REWRITTEN = new Set(['.html', '.js', '.json']);

const BOOT_MS = 180000;   // wasm compile under swiftshader is not quick
const SETTLE_MS = 15000;

let lastPage = null;

const t = tally('smoke:pwa');

// Kept for the crash dump. A hang in this suite always looks the same from the
// outside -- "the gate never appeared" -- and the useful detail is whichever
// request or exception caused it, which only the page knows.
const CONSOLE_TAIL = 40;
const seen = { console: [], errors: [], failed: [] };

function watch(page) {
	page.on('console', (m) => seen.console.push(`[${m.type()}] ${m.text()}`));
	page.on('pageerror', (e) => seen.errors.push(String(e)));
	page.on('requestfailed', (r) => seen.failed.push(
		`${r.url()} :: ${r.failure() && r.failure().errorText}`
	));
}

async function dump(page) {
	console.error('\n--- page errors ---\n' + (seen.errors.join('\n') || '(none)'));
	console.error('\n--- failed requests ---\n' + (seen.failed.join('\n') || '(none)'));
	console.error('\n--- console (last ' + CONSOLE_TAIL + ') ---\n'
		+ seen.console.slice(-CONSOLE_TAIL).join('\n'));
	try {
		const state = await page.evaluate(() => ({
			url: location.href,
			readyState: document.readyState,
			engine: typeof Engine,
			fault: (document.getElementById('fault') || {}).textContent || '',
			beginExists: !!document.getElementById('begin'),
			beginHidden: !!(document.getElementById('begin') || {}).hidden,
			readout: (document.getElementById('readout-label') || {}).textContent || '',
			toasts: [...document.querySelectorAll('.toast')].map((e) => e.textContent),
			exe: (window.GODOT_CONFIG || {}).executable,
			controller: !!(navigator.serviceWorker || {}).controller,
		}));
		console.error('\n--- page state ---\n' + JSON.stringify(state, null, 2));
	} catch (e) {
		console.error('\n--- page state unavailable: ' + e.message);
	}
}

function payloadHash(dir) {
	const wasm = fs.readdirSync(dir).find((n) => /^index\.[0-9a-f]{10}\.wasm$/.test(n));
	if (!wasm) { throw new Error(`no content-hashed payload in ${dir}`); }
	return /^index\.([0-9a-f]{10})\.wasm$/.exec(wasm)[1];
}

function forgeRebuild(from, to) {
	const hash = payloadHash(from);
	fs.rmSync(to, { recursive: true, force: true });
	fs.mkdirSync(to, { recursive: true });
	for (const name of fs.readdirSync(from)) {
		const src = path.join(from, name);
		if (fs.statSync(src).isDirectory()) { continue; }
		// Replace the bare `index.<hash>` prefix, not `index.<hash>.` -- the
		// shell's own config carries it without a trailing dot
		// (`"executable":"index.<hash>"`), and leaving that one behind produces
		// a forged build that still asks for the payload it replaced. It then
		// loads anyway, from whichever cache still happens to hold the old
		// files, and the suite passes for entirely the wrong reason.
		const rename = (s) => s.split(`index.${hash}`).join(`index.${FORGED_HASH}`);
		const dst = path.join(to, rename(name));
		if (!REWRITTEN.has(path.extname(name))) {
			fs.copyFileSync(src, dst);
			continue;
		}
		let text = rename(fs.readFileSync(src, 'utf8'));
		if (name === 'index.html') {
			text = text.replace(/"commit": "[0-9a-f]*"/, `"commit": "${FORGED_COMMIT}"`);
			text = text.replace('<title>', `<meta name="${FORGED_MARK}" content="1">\n<title>`);
		}
		if (name === 'index.service.worker.js') {
			text = text.replace(/const CACHE_VERSION = '[^']*';/, `const CACHE_VERSION = '${FORGED_CACHE}';`);
		}
		fs.writeFileSync(dst, text);
	}
	const served = fs.readFileSync(path.join(to, 'index.html'), 'utf8');
	if (served.includes(`index.${hash}`)) {
		throw new Error(`forged index.html still references index.${hash}`);
	}
	if (!served.includes(`"executable":"index.${FORGED_HASH}"`)) {
		throw new Error('forged index.html does not name the forged executable');
	}
	return hash;
}

const cacheKeys = (page) => page.evaluate(() => caches.keys());

function waitForCaches(page, predicateSource, timeout) {
	return page.waitForFunction(
		async (src) => {
			// eslint-disable-next-line no-new-func
			const test = new Function('keys', `return (${src})(keys);`);
			return test(await caches.keys());
		},
		predicateSource,
		{ timeout }
	);
}

/** A deploy whose engine script is rubbish. Same failure, no cache involved. */
function breakBuild(from, to) {
	const hash = payloadHash(from);
	fs.rmSync(to, { recursive: true, force: true });
	fs.cpSync(from, to, { recursive: true });
	fs.writeFileSync(path.join(to, `index.${hash}.js`), 'throw new Error("broken deploy");\n');
	return `index.${hash}.js`;
}

const recoveredFlag = (page) => page.evaluate(() => sessionStorage.getItem('itaw.recovered'));

/**
 * Write rubbish into the worker's cache in place of the engine script, then
 * make sure the worker is actually in the path when the page asks for it.
 *
 * Chromium keeps `immutable` subresources in its own HTTP cache across a reload
 * and hands them straight to the page, never dispatching a fetch event -- which
 * would quietly hide the poison and let this pass for the wrong reason. So the
 * HTTP cache is emptied *and* switched off for the rest of the run; Cache
 * Storage is untouched. That is the state a phone is in after Safari evicts or
 * the browser restarts, which is exactly when a bad cached build strands you.
 *
 * The write is read back before reloading, because "the poison never landed" and
 * "the poison was ignored" look identical from the outside and are not the same
 * bug.
 */
async function poisonEnginePayload(page, cdp) {
	const planted = await page.evaluate(async () => {
		const keys = await caches.keys();
		if (!keys.length) { return { ok: false, why: 'no cache to poison' }; }
		const cache = await caches.open(keys[0]);
		const target = `${location.origin}/${window.GODOT_CONFIG.executable}.js`;
		await cache.put(new Request(target), new Response('throw new Error("poisoned cache entry");', {
			headers: { 'Content-Type': 'text/javascript' },
		}));
		const back = await cache.match(target);
		const body = back ? await back.text() : '';
		return { ok: /poisoned/.test(body), why: back ? 'read back wrong' : 'not stored', target, key: keys[0] };
	});
	if (!planted.ok) {
		throw new Error(`could not poison the cache: ${planted.why}`);
	}
	await cdp.send('Network.clearBrowserCache');
	await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
	await page.reload({ waitUntil: 'load' }).catch(() => {});
	return planted.target;
}

/** Resolves to whichever the page reaches first: playable, or asking for help. */
async function gateOrRecover(page, timeout) {
	return Promise.race([
		page.waitForSelector(GATE, { timeout }).then(() => 'gate'),
		page.waitForSelector('#recover:not([hidden])', { timeout }).then(() => 'recover'),
	]).catch(() => 'neither');
}

async function clearToasts(page) {
	await page.evaluate(() => document.querySelectorAll('.toast').forEach((el) => el.click()));
	await page.waitForFunction(() => document.querySelectorAll('.toast').length === 0, null, { timeout: 15000 });
}

const isForged = (page) => page.evaluate(
	(mark) => !!document.querySelector(`meta[name="${mark}"]`),
	FORGED_MARK
);

async function startEngine(page) {
	await page.tap('#begin');
	await page.waitForFunction(() => document.getElementById('veil').hidden, null, { timeout: BOOT_MS });
}

// The one thing Playwright cannot do for real: send the tab to the home screen
// and bring it back. The listeners under test read document.visibilityState, so
// that is what gets replaced.
async function cycleBackground(page) {
	await page.evaluate(() => {
		const set = (value) => Object.defineProperty(document, 'visibilityState', {
			get: () => value, configurable: true,
		});
		set('hidden');
		document.dispatchEvent(new Event('visibilitychange'));
		set('visible');
		document.dispatchEvent(new Event('visibilitychange'));
	});
}

(async () => {
	const originalHash = forgeRebuild(BUILD, FORGED);
	breakBuild(BUILD, BROKEN);
	const root = { dir: BUILD };
	const server = await serve(root, PORT);
	const { browser, context } = await openBrowser();
	await context.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: ORIGIN });
	const page = await context.newPage();
	lastPage = page;
	watch(page);
	const cdp = await context.newCDPSession(page);
	await cdp.send('Network.enable');

	// ---- A. install --------------------------------------------------------
	await page.goto(`${ORIGIN}/index.html`, { waitUntil: 'load' });
	await page.waitForSelector(GATE, { timeout: BOOT_MS });
	await page.waitForFunction(() => !!navigator.serviceWorker.controller, null, { timeout: SETTLE_MS });
	t.check(true, 'A1 the service worker installs and claims the open page');

	let keys = await cacheKeys(page);
	const buildCache = keys[0];
	t.check(
		keys.length === 1 && /-sw-cache-[0-9a-f]{16}$/.test(buildCache || ''),
		`A2 one cache, named for the build hash (${keys.join(', ') || 'none'})`
	);

	await page.reload({ waitUntil: 'load' });
	await page.waitForSelector(GATE, { timeout: BOOT_MS });
	const cached = await page.evaluate(async (key) => {
		const cache = await caches.open(key);
		return (await cache.keys()).map((r) => new URL(r.url).pathname);
	}, buildCache);
	t.check(
		cached.some((n) => n.endsWith('.wasm')) && cached.some((n) => n.endsWith('.pck')),
		`A3 the engine payload is cached once it has been through the worker (${cached.length} entries)`
	);

	await context.setOffline(true);
	await page.reload({ waitUntil: 'load' });
	const offline = await page.waitForSelector(GATE, { timeout: BOOT_MS }).then(() => true, () => false);
	t.check(offline, 'A4 the game still reaches the tap gate with the network off');
	await context.setOffline(false);

	const stamp = ((await page.textContent('#stamp')) || '').trim();
	t.check(/^v\d+\.\d+\.\d+ [0-9a-f]{7}$/.test(stamp), `A5 build stamp reads version + short sha ("${stamp}")`);

	const box = await page.locator('#stamp').boundingBox();
	await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
	const clipboard = await page.evaluate(() => navigator.clipboard.readText().catch(() => ''));
	t.check(
		clipboard.includes(stamp.split(' ')[1]) && clipboard.includes('payload'),
		'A6 tapping the stamp copies a full build report'
	);

	await clearToasts(page);
	// Four separate flushes, because one GDScript error inside _process is what
	// this has to survive: the same message, over and over, at frame rate.
	for (let i = 0; i < 4; i++) {
		await page.evaluate(() => window.GODOT_CONFIG.onPrintError(
			'SCRIPT ERROR: smoke-probe', 'at: _process (res://x.gd:1)'
		));
		await page.waitForTimeout(140);
	}
	const engineToast = await page.evaluate(() => ({
		count: document.querySelectorAll('.toast').length,
		text: (document.querySelector('.toast') || {}).textContent || '',
	}));
	t.check(/smoke-probe/.test(engineToast.text), `A7 an engine error surfaces on screen ("${engineToast.text}")`);
	t.check(
		engineToast.count === 1 && /×4/.test(engineToast.text),
		`A8 a repeating error is one toast with a count, not a storm (${engineToast.count} toasts)`
	);

	await page.evaluate(() => { setTimeout(() => { throw new Error('smoke-js-boom'); }, 0); });
	await page.waitForFunction(
		() => [...document.querySelectorAll('.toast')].some((e) => /smoke-js-boom/.test(e.textContent)),
		null,
		{ timeout: SETTLE_MS }
	);
	t.check(true, 'A9 an unhandled JavaScript exception surfaces on screen');

	const dismissed = await clearToasts(page).then(() => true, () => false);
	t.check(dismissed, 'A10 toasts are dismissible');

	// ---- B. a deploy lands under a running game ---------------------------
	await startEngine(page);
	t.check(true, 'B1 the engine starts');

	root.dir = FORGED;
	const detected = await page.evaluate(() => window.__itaw_checkForUpdate('poll'));
	t.check(detected === true, 'B2 a rebuilt payload is detected while the game is running');
	t.check(await page.isHidden('#update'), 'B3 the banner is withheld mid-scene');

	await cycleBackground(page);
	t.check(await page.isVisible('#update'), 'B4 returning from the home screen releases the banner');

	await page.tap('#update');
	await page.waitForSelector(GATE, { timeout: BOOT_MS });
	t.check(await isForged(page), 'B5 taking the update swaps the live build');
	// The banner's reload must land the new build outright. If the shell had to
	// fall back on its own recovery, something served a stale document and the
	// player paid for it with an extra purge and reload.
	t.check(
		await recoveredFlag(page) !== '1',
		'B6 and lands it directly, without falling back on the recovery path'
	);
	await waitForCaches(page, `(keys) => keys.length === 1 && keys[0].endsWith('${FORGED_CACHE}')`, SETTLE_MS)
		.then(() => t.check(true, 'B7 the rebuild invalidates the old cache'))
		.catch(async () => t.check(false, `B7 the rebuild invalidates the old cache (${(await cacheKeys(page)).join(', ')})`));

	// ---- C. the other place a banner is allowed to appear ------------------
	root.dir = BUILD;
	await page.reload({ waitUntil: 'load' });
	await page.waitForSelector(GATE, { timeout: BOOT_MS });
	t.check(!(await isForged(page)), 'C1 rolling the deploy back restores the previous build');
	await waitForCaches(page, `(keys) => keys.length === 1 && keys[0] === '${buildCache}'`, SETTLE_MS)
		.then(() => t.check(true, 'C2 and the forged cache is gone in turn'))
		.catch(async () => t.check(false, `C2 and the forged cache is gone in turn (${(await cacheKeys(page)).join(', ')})`));

	await startEngine(page);
	root.dir = FORGED;
	await page.evaluate(() => window.__itaw_checkForUpdate('poll'));
	t.check(await page.isHidden('#update'), 'C3 withheld mid-scene again');
	await page.evaluate(() => window.__itaw_setUpdateGate(true));
	t.check(await page.isVisible('#update'), 'C4 opening a menu releases the banner');
	root.dir = BUILD;

	// ---- D. the cache holds a broken build --------------------------------
	// The recovery ladder, in the order a real failure climbs it: heal itself
	// once, then say so and offer the way out by hand.
	await page.reload({ waitUntil: 'load' });
	await page.waitForSelector(GATE, { timeout: BOOT_MS });
	await page.evaluate(() => sessionStorage.removeItem('itaw.recovered'));

	const poisoned = await poisonEnginePayload(page, cdp);
	await page.waitForURL((u) => !u.href.includes('fresh=1'), { timeout: SETTLE_MS });
	await page.waitForSelector(GATE, { timeout: BOOT_MS });
	t.check(true, `D1 a poisoned engine payload heals itself and reloads (${poisoned})`);
	t.check(await recoveredFlag(page) === '1', 'D2 and records that it had to');
	t.check(!page.url().includes('fresh=1'), `D3 onto a clean URL (${page.url()})`);

	const report = JSON.parse((await page.evaluate(() => sessionStorage.getItem('itaw.purged'))) || '{}');
	t.check(
		report.done === true && report.caches >= 1 && report.workers >= 1,
		`D4 having finished the purge before reloading, not on its deadline (${JSON.stringify(report)})`
	);

	// Second time in the same tab: no automatic purge, because a loop of
	// purge-and-fail would be worse than a message.
	//
	// Broken at the server this time rather than in the cache. It is the same
	// code path -- the engine script does not define Engine -- but it does not
	// depend on which Chromium is running or on what its HTTP cache happens to
	// be holding, both of which decided the outcome when this was a second
	// poisoning.
	await page.evaluate(async () => {
		const regs = await navigator.serviceWorker.getRegistrations();
		await Promise.all(regs.map((r) => r.unregister()));
		const keys = await caches.keys();
		await Promise.all(keys.map((k) => caches.delete(k)));
	});
	root.dir = BROKEN;
	await page.reload({ waitUntil: 'load' }).catch(() => {});
	const landed = await gateOrRecover(page, SETTLE_MS);
	t.check(landed === 'recover', `D5 a second failure in the same tab is not purged automatically (${landed})`);
	t.check(await page.isVisible('#recover'), 'D6 and offers "Reload cleanly" instead');

	root.dir = BUILD;
	await page.tap('#recover');
	await page.waitForURL((u) => !u.href.includes('fresh=1'), { timeout: SETTLE_MS });
	await page.waitForSelector(GATE, { timeout: BOOT_MS });
	t.check(true, 'D7 which recovers the build by hand');

	console.log(`\n(original payload index.${originalHash}, forged index.${FORGED_HASH})`);
	await browser.close();
	server.close();
	fs.rmSync(FORGED, { recursive: true, force: true });
	fs.rmSync(BROKEN, { recursive: true, force: true });
	process.exit(t.report());
})().catch(async (err) => {
	console.error('smoke:pwa crashed', err);
	if (lastPage) { await dump(lastPage).catch(() => {}); }
	process.exit(2);
});
