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

const t = tally('smoke:pwa');

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
		const dst = path.join(to, name.split(`index.${hash}.`).join(`index.${FORGED_HASH}.`));
		if (!REWRITTEN.has(path.extname(name))) {
			fs.copyFileSync(src, dst);
			continue;
		}
		let text = fs.readFileSync(src, 'utf8').split(`index.${hash}.`).join(`index.${FORGED_HASH}.`);
		if (name === 'index.html') {
			text = text.replace(/"commit": "[0-9a-f]*"/, `"commit": "${FORGED_COMMIT}"`);
			text = text.replace('<title>', `<meta name="${FORGED_MARK}" content="1">\n<title>`);
		}
		if (name === 'index.service.worker.js') {
			text = text.replace(/const CACHE_VERSION = '[^']*';/, `const CACHE_VERSION = '${FORGED_CACHE}';`);
		}
		fs.writeFileSync(dst, text);
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
	const root = { dir: BUILD };
	const server = await serve(root, PORT);
	const { browser, context } = await openBrowser();
	await context.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: ORIGIN });
	const page = await context.newPage();

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
	await waitForCaches(page, `(keys) => keys.length === 1 && keys[0].endsWith('${FORGED_CACHE}')`, SETTLE_MS)
		.then(() => t.check(true, 'B6 the rebuild invalidates the old cache'))
		.catch(async () => t.check(false, `B6 the rebuild invalidates the old cache (${(await cacheKeys(page)).join(', ')})`));

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
	await page.reload({ waitUntil: 'load' });
	await page.waitForSelector(GATE, { timeout: BOOT_MS });
	const poisoned = await page.evaluate(async () => {
		const key = (await caches.keys())[0];
		const cache = await caches.open(key);
		const url = `${location.origin}/${window.GODOT_CONFIG.executable}.js`;
		await cache.put(new Request(url), new Response('throw new Error("poisoned cache entry");', {
			headers: { 'Content-Type': 'text/javascript' },
		}));
		return url;
	});
	// Chromium keeps `immutable` subresources in its own HTTP cache across a
	// reload and hands them straight to the page, never dispatching a fetch
	// event -- which would quietly hide the poison. Clearing that cache (and
	// only that cache; Cache Storage survives) is what puts the worker back in
	// the path, and is the state a phone is in after Safari evicts or restarts.
	const cdp = await context.newCDPSession(page);
	await cdp.send('Network.clearBrowserCache');
	await page.reload({ waitUntil: 'load' });
	const stillBroken = await page.waitForSelector(GATE, { timeout: 8000 }).then(() => false, () => true);
	t.check(stillBroken, `D1 a poisoned cache entry really does strand the build (${poisoned})`);

	await page.goto(`${ORIGIN}/index.html?fresh=1`, { waitUntil: 'load' });
	await page.waitForURL((u) => !u.href.includes('fresh=1'), { timeout: SETTLE_MS });
	t.check(!page.url().includes('fresh=1'), `D2 the purge reloads onto a clean URL (${page.url()})`);
	await page.waitForSelector(GATE, { timeout: BOOT_MS });
	t.check(true, 'D3 ?fresh=1 recovers a build the cache had broken');

	const report = JSON.parse((await page.evaluate(() => sessionStorage.getItem('itaw.purged'))) || '{}');
	t.check(
		report.done === true && report.caches >= 1 && report.workers >= 1,
		`D4 the purge finished before the reload, not on its deadline (${JSON.stringify(report)})`
	);

	console.log(`\n(original payload index.${originalHash}, forged index.${FORGED_HASH})`);
	await browser.close();
	server.close();
	fs.rmSync(FORGED, { recursive: true, force: true });
	process.exit(t.report());
})().catch((err) => {
	console.error('smoke:pwa crashed', err);
	process.exit(2);
});
