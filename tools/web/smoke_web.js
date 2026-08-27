/**
 * Headless smoke test for the exported web build.
 *
 * The only device that matters here is a phone the CI runner does not have, so
 * this is the last line of defence before a build reaches it: serve the export,
 * load it in Chromium at iPhone 16 Pro Max landscape metrics, walk through the
 * tap gate, and assert the things that actually break -- a threaded export, a
 * missing file, a script error, a canvas that never draws, touch controls that
 * do nothing.
 *
 *   npm --prefix tools/web run smoke
 *   node tools/web/smoke_web.js <build-dir> <screenshot-dir>
 */
'use strict';

const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

const BUILD = path.resolve(process.argv[2] || 'build');
const SHOTS = path.resolve(process.argv[3] || 'build-smoke');
const PORT = 8099;

// iPhone 16 Pro Max, landscape, CSS pixels.
const VIEWPORT = { width: 956, height: 440 };
const UA =
	'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 ' +
	'(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1';

const TYPES = {
	'.html': 'text/html; charset=utf-8',
	'.js': 'text/javascript; charset=utf-8',
	'.wasm': 'application/wasm',
	'.pck': 'application/octet-stream',
	'.png': 'image/png',
	'.json': 'application/manifest+json',
};

const failures = [];
function check(condition, message) {
	if (!condition) { failures.push(message); }
	console.log(`${condition ? '  ok  ' : ' FAIL '} ${message}`);
}

function serve() {
	const server = http.createServer((req, res) => {
		let rel = decodeURIComponent(req.url.split('?')[0]);
		if (rel === '/') { rel = '/index.html'; }
		const file = path.join(BUILD, rel);
		if (!file.startsWith(BUILD) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
			res.writeHead(404);
			return res.end('not found');
		}
		const body = fs.readFileSync(file);
		res.writeHead(200, {
			'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream',
			'Content-Length': body.length,
		});
		return res.end(body);
	});
	return new Promise((resolve) => server.listen(PORT, () => resolve(server)));
}

(async () => {
	fs.mkdirSync(SHOTS, { recursive: true });
	const server = await serve();

	const launch = { args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] };
	if (process.env.CHROMIUM_PATH) { launch.executablePath = process.env.CHROMIUM_PATH; }
	const browser = await chromium.launch(launch);
	const context = await browser.newContext({
		viewport: VIEWPORT,
		deviceScaleFactor: 3,
		isMobile: true,
		hasTouch: true,
		userAgent: UA,
	});
	const page = await context.newPage();

	const consoleLines = [];
	const pageErrors = [];
	const requestFailures = [];
	page.on('console', (m) => consoleLines.push(`[${m.type()}] ${m.text()}`));
	page.on('pageerror', (e) => pageErrors.push(String(e)));
	page.on('requestfailed', (r) => requestFailures.push(`${r.url()} :: ${r.failure() && r.failure().errorText}`));

	await page.goto(`http://127.0.0.1:${PORT}/index.html`, { waitUntil: 'load' });

	// The gate is only revealed once the wasm and the pack have both landed.
	await page.waitForSelector('#begin:not([hidden])', { timeout: 120000 });
	check(true, 'tap gate appears after the payload loads');
	await page.screenshot({ path: path.join(SHOTS, '01-gate.png') });

	await page.tap('#begin');
	await page.waitForFunction(() => document.getElementById('veil').hidden, null, { timeout: 60000 });
	await page.waitForTimeout(2500);
	const running = await page.screenshot({ path: path.join(SHOTS, '02-running.png') });
	check(true, 'engine starts and the loading veil clears');

	const info = await page.evaluate(() => ({
		fault: document.getElementById('fault').textContent.trim(),
		canvasW: document.getElementById('canvas').width,
		canvasH: document.getElementById('canvas').height,
		safeArea: window.__itaw_safeArea ? window.__itaw_safeArea() : null,
		hasSharedArrayBuffer: typeof SharedArrayBuffer !== 'undefined',
		crossOriginIsolated: window.crossOriginIsolated,
	}));

	check(info.fault === '', 'no fault reported by the shell');
	check(info.safeArea !== null, 'safe-area bridge is exposed to the game');
	check(info.hasSharedArrayBuffer === false, 'runs without SharedArrayBuffer');
	check(info.crossOriginIsolated === false, 'runs without cross-origin isolation');
	check(
		info.canvasW === VIEWPORT.width && info.canvasH === VIEWPORT.height,
		`canvas renders at CSS resolution, not 3x (${info.canvasW}x${info.canvasH})`
	);

	const joined = consoleLines.join('\n');
	check(/Compatibility/.test(joined), 'renderer is Compatibility (WebGL2)');
	check(/single-threaded/.test(joined), 'engine build is single-threaded');

	// Real touch events, dispatched through CDP -- the same event stream the
	// phone produces. (Synthetic mouse drags do not reach the game: Chromium's
	// mobile emulation swallows them, and the phone has no mouse anyway.)
	const cdp = await context.newCDPSession(page);
	async function touchDrag(fromX, fromY, toX, toY, steps) {
		await cdp.send('Input.dispatchTouchEvent', {
			type: 'touchStart', touchPoints: [{ x: fromX, y: fromY, id: 1 }],
		});
		for (let i = 1; i <= steps; i++) {
			await cdp.send('Input.dispatchTouchEvent', {
				type: 'touchMove',
				touchPoints: [{
					x: fromX + ((toX - fromX) * i) / steps,
					y: fromY + ((toY - fromY) * i) / steps,
					id: 1,
				}],
			});
			await page.waitForTimeout(30);
		}
		return cdp;
	}
	async function touchEnd() {
		await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
	}

	// Right half: drag to look. The camera must turn.
	await touchDrag(700, 220, 520, 220, 10);
	await touchEnd();
	await page.waitForTimeout(800);
	const looked = await page.screenshot({ path: path.join(SHOTS, '03-looked.png') });
	check(!looked.equals(running), 'dragging the right half turns the camera');

	// Left half: hold to raise the floating stick and walk forward.
	await touchDrag(200, 300, 200, 230, 6);
	await page.waitForTimeout(900);
	const sticked = await page.screenshot({ path: path.join(SHOTS, '04-stick.png') });
	await touchEnd();
	check(!sticked.equals(looked), 'holding the left half raises the stick and moves the player');

	check(pageErrors.length === 0, `no uncaught script errors (${pageErrors.length})`);
	check(requestFailures.length === 0, `no failed requests (${requestFailures.length})`);

	if (pageErrors.length) { console.log('\npage errors:\n' + pageErrors.join('\n')); }
	if (requestFailures.length) { console.log('\nfailed requests:\n' + requestFailures.join('\n')); }
	console.log('\n--- console ---\n' + joined);

	await browser.close();
	server.close();

	if (failures.length) {
		console.error(`\nsmoke: ${failures.length} check(s) failed`);
		process.exit(1);
	}
	console.log('\nsmoke: all checks passed');
	process.exit(0);
})().catch((err) => {
	console.error('smoke: crashed', err);
	process.exit(2);
});
