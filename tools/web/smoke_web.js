/**
 * Headless smoke test for the exported web build.
 *
 * The only device that matters here is a phone the CI runner does not have, so
 * this is the last line of defence before a build reaches it: serve the export,
 * load it in Chromium at iPhone 16 Pro Max landscape metrics, walk through the
 * tap gate, and assert the things that actually break -- a threaded export, a
 * missing file, a script error, a canvas that never draws, touch controls that
 * do nothing, a frame budget quietly blown, audio that never unlocked.
 *
 * The update path is a separate suite: tools/web/smoke_pwa.js.
 *
 *   npm --prefix tools/web run smoke
 *   node tools/web/smoke_web.js <build-dir> <screenshot-dir>
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { VIEWPORT, serve, openBrowser, tally } = require('./harness');

const BUILD = path.resolve(process.argv[2] || 'build');
const SHOTS = path.resolve(process.argv[3] || 'build-smoke');
const PORT = 8099;
const BOOT_MS = 180000;

// Phase 0 budgets, asserted rather than aspired to. Draw calls and primitives
// are the two the Compatibility renderer will punish first on a phone; CPU
// frame time is the only timing number that means anything under swiftshader,
// where the GPU is a software rasteriser and its numbers are fiction.
const MAX_DRAW_CALLS = 120;
const MAX_TRIS = 150000;
// The phone budget is 16.6 ms, and it can only be measured on the phone: under
// swiftshader the main thread blocks on a software rasteriser and that wait
// lands inside TIME_PROCESS. This ceiling is a tripwire for something spinning,
// not a claim about device performance.
const MAX_CPU_MS_CI = 250;
// Enough wall-clock for a playback head to have visibly moved.
const AUDIO_SETTLE_MS = 1200;

const t = tally('smoke');

(async () => {
	fs.mkdirSync(SHOTS, { recursive: true });
	const server = await serve({ dir: BUILD }, PORT);
	const { browser, context } = await openBrowser();
	const page = await context.newPage();

	const consoleLines = [];
	const pageErrors = [];
	const requestFailures = [];
	page.on('console', (m) => consoleLines.push(`[${m.type()}] ${m.text()}`));
	page.on('pageerror', (e) => pageErrors.push(String(e)));
	page.on('requestfailed', (r) => requestFailures.push(`${r.url()} :: ${r.failure() && r.failure().errorText}`));

	await page.goto(`http://127.0.0.1:${PORT}/index.html`, { waitUntil: 'load' });

	// The gate is only revealed once the wasm and the pack have both landed.
	await page.waitForSelector('#begin:not([hidden])', { timeout: BOOT_MS });
	t.check(true, 'tap gate appears after the payload loads');
	await page.screenshot({ path: path.join(SHOTS, '01-gate.png') });

	await page.tap('#begin');
	await page.waitForFunction(() => document.getElementById('veil').hidden, null, { timeout: BOOT_MS });
	await page.waitForTimeout(2500);
	const running = await page.screenshot({ path: path.join(SHOTS, '02-running.png') });
	t.check(true, 'engine starts and the loading veil clears');

	const info = await page.evaluate(() => ({
		fault: document.getElementById('fault').textContent.trim(),
		canvasW: document.getElementById('canvas').width,
		canvasH: document.getElementById('canvas').height,
		safeArea: window.__itaw_safeArea ? window.__itaw_safeArea() : null,
		hasSharedArrayBuffer: typeof SharedArrayBuffer !== 'undefined',
		crossOriginIsolated: window.crossOriginIsolated,
	}));

	t.check(info.fault === '', 'no fault reported by the shell');
	t.check(info.safeArea !== null, 'safe-area bridge is exposed to the game');
	t.check(info.hasSharedArrayBuffer === false, 'runs without SharedArrayBuffer');
	t.check(info.crossOriginIsolated === false, 'runs without cross-origin isolation');
	t.check(
		info.canvasW === VIEWPORT.width && info.canvasH === VIEWPORT.height,
		`canvas renders at CSS resolution, not 3x (${info.canvasW}x${info.canvasH})`
	);

	const joined = consoleLines.join('\n');
	t.check(/Compatibility/.test(joined), 'renderer is Compatibility (WebGL2)');
	t.check(/single-threaded/.test(joined), 'engine build is single-threaded');

	// Real touch events, dispatched through CDP -- the same event stream the
	// phone produces. (Synthetic mouse drags do not reach the game: Chromium's
	// mobile emulation swallows them, and the phone has no mouse anyway.)
	const cdp = await context.newCDPSession(page);
	const points = (list) => list.map((p, i) => ({ x: p[0], y: p[1], id: i + 1 }));

	async function touchDrag(fromX, fromY, toX, toY, steps) {
		await cdp.send('Input.dispatchTouchEvent', {
			type: 'touchStart', touchPoints: points([[fromX, fromY]]),
		});
		for (let i = 1; i <= steps; i++) {
			await cdp.send('Input.dispatchTouchEvent', {
				type: 'touchMove',
				touchPoints: points([[
					fromX + ((toX - fromX) * i) / steps,
					fromY + ((toY - fromY) * i) / steps,
				]]),
			});
			await page.waitForTimeout(30);
		}
	}
	async function touchEnd() {
		await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
	}
	async function threeFingerTap() {
		await cdp.send('Input.dispatchTouchEvent', {
			type: 'touchStart', touchPoints: points([[440, 130], [480, 120], [520, 130]]),
		});
		await page.waitForTimeout(80);
		await touchEnd();
		await page.waitForTimeout(700);
	}

	// Right half: drag to look. The camera must turn.
	await touchDrag(700, 220, 520, 220, 10);
	await touchEnd();
	await page.waitForTimeout(800);
	const looked = await page.screenshot({ path: path.join(SHOTS, '03-looked.png') });
	t.check(!looked.equals(running), 'dragging the right half turns the camera');

	// Left half: hold to raise the floating stick and walk forward.
	await touchDrag(200, 300, 200, 230, 6);
	await page.waitForTimeout(900);
	const sticked = await page.screenshot({ path: path.join(SHOTS, '04-stick.png') });
	await touchEnd();
	t.check(!sticked.equals(looked), 'holding the left half raises the stick and moves the player');

	// The debug overlay is the phone's only instrumentation, so it gets tested
	// like a feature rather than trusted like a debug aid.
	await page.evaluate(() => { window.__itaw_probe = null; });
	await threeFingerTap();
	const probe = await page.evaluate(() => window.__itaw_probe);
	t.check(!!probe && probe.visible === true, 'three-finger tap opens the debug overlay');
	console.log('  probe: ' + JSON.stringify(probe));
	await page.screenshot({ path: path.join(SHOTS, '05-overlay.png') });

	if (probe) {
		t.check(probe.fps > 0, `overlay reports a live frame rate (${probe.fps} fps)`);
		t.check(
			probe.draw_calls > 0 && probe.draw_calls <= MAX_DRAW_CALLS,
			`draw calls within budget (${probe.draw_calls} / ${MAX_DRAW_CALLS})`
		);
		t.check(probe.tris <= MAX_TRIS, `visible primitives within budget (${probe.tris} / ${MAX_TRIS})`);
		t.check(
			probe.cpu_ms > 0 && probe.cpu_ms <= MAX_CPU_MS_CI,
			`CPU frame time is not runaway (${probe.cpu_ms.toFixed(2)} ms / ${MAX_CPU_MS_CI} ms ceiling)`
		);
		// Playback position, not bus peak: Godot's web build never populates the
		// peak monitor, and a head that advances proves the AudioContext is
		// running and the mixer is consuming the stream. Whether it is audible
		// is a question only the device answers -- see docs/TESTING.md.
		const before = probe.audio_source;
		await page.waitForTimeout(AUDIO_SETTLE_MS);
		const after = await page.evaluate(() => window.__itaw_probe.audio_source);
		const at = (s) => parseFloat(String(s).split(' ')[1] || '0');
		t.check(
			/^on /.test(after) && at(after) > at(before),
			`audio unlocked and the mixer is consuming the stream (${before} -> ${after})`
		);
		t.check(probe.listener === true, 'the scene has a 3D audio listener');
		t.check(
			probe.shell && probe.shell.store === 'ok',
			`shell reports durable storage (${probe.shell && probe.shell.store})`
		);
	}

	await threeFingerTap();
	const closed = await page.evaluate(() => window.__itaw_probe);
	t.check(!!closed && closed.visible === false, 'a second three-finger tap closes it again');

	t.check(pageErrors.length === 0, `no uncaught script errors (${pageErrors.length})`);
	t.check(requestFailures.length === 0, `no failed requests (${requestFailures.length})`);
	t.check(
		await page.locator('.toast').count() === 0,
		'nothing surfaced an error toast during play'
	);

	if (pageErrors.length) { console.log('\npage errors:\n' + pageErrors.join('\n')); }
	if (requestFailures.length) { console.log('\nfailed requests:\n' + requestFailures.join('\n')); }
	console.log('\n--- console ---\n' + joined);

	await browser.close();
	server.close();
	process.exit(t.report());
})().catch((err) => {
	console.error('smoke: crashed', err);
	process.exit(2);
});
