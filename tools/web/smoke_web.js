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
// The debug overlay publishes its sample four times a second; a gesture has to
// outlive one interval before the readout can be trusted.
const PROBE_MS = 400;
// Between dispatched touch points, so the engine sees a gesture and not a jump.
const TOUCH_STEP_MS = 30;
// The canvas and the HTML shell share the top-left corner. Enough of a gap that
// a font change cannot silently close it.
const STAMP_CLEARANCE_PX = 6;

const t = tally('smoke');

/** Whether [x,y,w,h] `inner` sits entirely within [x,y,w,h] `outer`. */
function encloses(outer, inner) {
	return inner[0] >= outer[0] && inner[1] >= outer[1]
		&& inner[0] + inner[2] <= outer[0] + outer[2]
		&& inner[1] + inner[3] <= outer[1] + outer[3];
}

/** Pairs of reserved rects that intersect. Empty is the contract. */
function overlaps(list) {
	const hits = [];
	for (let i = 0; i < list.length; i++) {
		for (let j = i + 1; j < list.length; j++) {
			const a = list[i];
			const b = list[j];
			if (a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h) {
				hits.push(`${a.id}/${b.id}`);
			}
		}
	}
	return hits;
}

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
	// phone produces, including the multi-touch sequences that broke the first
	// control scheme. (Synthetic mouse drags do not reach the game: Chromium's
	// mobile emulation swallows them, and the phone has no mouse anyway.)
	// One changed point per call, which is what CDP models: it fills in the
	// other live points as stationary and produces a single DOM event with the
	// right changedTouches. Note that `touchEnd` takes the point being
	// *released*, not the ones remaining -- passing the remainder releases the
	// wrong finger, silently, and the suite then proves nothing.
	const cdp = await context.newCDPSession(page);
	const down = new Map();

	async function dispatch(type, id, at) {
		await cdp.send('Input.dispatchTouchEvent', {
			type, touchPoints: [{ x: at.x, y: at.y, id }],
		});
		await page.waitForTimeout(TOUCH_STEP_MS);
	}
	const press = (id, at) => { down.set(id, at); return dispatch('touchStart', id, at); };
	const move = (id, at) => { down.set(id, at); return dispatch('touchMove', id, at); };
	const lift = (id) => {
		const at = down.get(id);
		down.delete(id);
		return dispatch('touchEnd', id, at);
	};
	async function slide(id, from, to, steps) {
		await press(id, from);
		for (let i = 1; i <= steps; i++) {
			await move(id, {
				x: from.x + ((to.x - from.x) * i) / steps,
				y: from.y + ((to.y - from.y) * i) / steps,
			});
		}
	}
	async function threeFingerTap() {
		await press(90, { x: 440, y: 130 });
		await press(91, { x: 480, y: 118 });
		await press(92, { x: 520, y: 130 });
		await page.waitForTimeout(90);
		await lift(90); await lift(91); await lift(92);
		await page.waitForTimeout(700);
	}

	const readProbe = () => page.evaluate(() => window.__itaw_probe);
	async function sample() {
		await page.waitForTimeout(PROBE_MS);
		return readProbe();
	}

	// The debug overlay is the phone's only instrumentation, so it gets tested
	// like a feature rather than trusted like a debug aid. From here on it is
	// also the readout the touch assertions are made against.
	await page.evaluate(() => { window.__itaw_probe = null; });
	await threeFingerTap();
	const probe = await readProbe();
	t.check(!!probe && probe.visible === true, 'three-finger tap opens the debug overlay');
	console.log('  probe: ' + JSON.stringify(probe));
	await page.screenshot({ path: path.join(SHOTS, '02b-overlay.png') });

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
		const after = (await readProbe()).audio_source;
		const at = (s) => parseFloat(String(s).split(' ')[1] || '0');
		t.check(
			/^on /.test(after) && at(after) > at(before),
			`audio unlocked and the mixer is consuming the stream (${before} -> ${after})`
		);
		t.check(probe.listener === true, 'the scene has a 3D audio listener');
		// The score is four layers crossfaded by the fear number. At rest only
		// the bed should be up: if the upper layers are audible in an empty
		// room, the mix is narrating.
		t.check(
			!!probe.score && probe.score.score_bed > 0.3,
			`the score's bed layer is playing (${probe.score && probe.score.score_bed})`
		);
		t.check(
			!!probe.score && probe.score.score_room < 0.25 && probe.score.score_edge < 0.05,
			`and the upper layers are held back while nothing is wrong `
				+ `(room ${probe.score && probe.score.score_room}, edge ${probe.score && probe.score.score_edge})`
		);
		t.check(
			probe.shell && probe.shell.store === 'ok',
			`shell reports durable storage (${probe.shell && probe.shell.store})`
		);
	}

	// ---- the control scheme, at the device's real metrics -------------------
	// Rects come back in viewport units; touches go out in CSS points. The
	// overlay reports both sizes, so the conversion is measured rather than
	// assumed -- which is the whole point of doing this in a browser as well as
	// headless.
	const size = (text) => String(text).split('x').map(Number);
	const [viewW] = size(probe.view);
	const [winW] = size(probe.window);
	const k = winW / viewW;
	const toCss = (r) => ({ x: (r.x + r.w / 2) * k, y: (r.y + r.h / 2) * k });
	const byId = (list) => Object.fromEntries(list.map((r) => [r.id, r]));
	const rects = byId(probe.hud.rects);

	t.check(
		['move_stick', 'look_stick', 'pause', 'action_arc_0'].every((id) => id in rects),
		`the sticks, pause and action arc all reserve screen area (${Object.keys(rects).join(' ')})`
	);
	t.check(overlaps(probe.hud.rects).length === 0,
		`no two reserved rects overlap (${overlaps(probe.hud.rects).join(', ') || 'none'})`);

	// The one place the canvas and the HTML shell share a corner. Godot cannot
	// see the stamp, so only a browser can check this.
	const stampBox = await page.evaluate(() => {
		const el = document.getElementById('stamp');
		const r = el.getBoundingClientRect();
		return { x: r.x, y: r.y, w: r.width, h: r.height };
	});
	const [ox, oy, ow, oh] = probe.overlay;
	const overlayCss = { x: ox * k, y: oy * k, w: ow * k, h: oh * k };
	t.check(
		overlayCss.y >= stampBox.y + stampBox.h + STAMP_CLEARANCE_PX,
		`the debug overlay clears the build stamp `
			+ `(overlay top ${overlayCss.y.toFixed(0)}, stamp bottom ${(stampBox.y + stampBox.h).toFixed(0)})`
	);
	t.check(
		overlaps([...probe.hud.rects, { id: 'debug_overlay', x: ox, y: oy, w: ow, h: oh }]).length === 0,
		'the debug overlay is not drawn on top of a control'
	);

	const moveAt = toCss(rects.move_stick);
	const lookAt = toCss(rects.look_stick);

	// Both sticks, one at a time, against the screen they are actually drawn on.
	// The baseline is taken here rather than earlier, so the overlay being open
	// is not what makes the frames differ.
	const rest = await page.screenshot({ path: path.join(SHOTS, '03-rest.png') });
	await slide(1, lookAt, { x: lookAt.x - 60, y: lookAt.y }, 8);
	await lift(1);
	await page.waitForTimeout(800);
	const looked = await page.screenshot({ path: path.join(SHOTS, '04-looked.png') });
	t.check(!looked.equals(rest), 'the right stick turns the camera');

	await slide(1, moveAt, { x: moveAt.x, y: moveAt.y - 55 }, 6);
	await page.waitForTimeout(900);
	const sticked = await page.screenshot({ path: path.join(SHOTS, '05-stick.png') });
	await lift(1);
	t.check(!sticked.equals(looked), 'the left stick lights up and moves the player');

	// The assertion this whole pass exists for.
	await press(1, moveAt);
	await press(2, lookAt);
	await move(1, { x: moveAt.x, y: moveAt.y - 50 });
	await move(2, { x: lookAt.x + 55, y: lookAt.y });
	const both = await sample();
	t.check(both.hud.move[1] > 0.2, `left thumb walks forward (${both.hud.move[1].toFixed(2)})`);
	t.check(both.hud.look[0] > 0.2, `right thumb turns the camera (${both.hud.look[0].toFixed(2)})`);
	t.check(
		JSON.stringify(byId(both.hud.rects).move_stick) === JSON.stringify(rects.move_stick),
		'the stick base does not travel with the thumb'
	);

	await lift(2);
	const afterLift = await sample();
	t.check(
		afterLift.hud.move[1] === both.hud.move[1] && afterLift.hud.move[0] === both.hud.move[0],
		`lifting the right thumb leaves movement exactly unchanged `
			+ `(${both.hud.move} -> ${afterLift.hud.move})`
	);
	t.check(afterLift.hud.look.every((v) => v === 0), 'the look stick recentres on release');

	// Rapid replanting of the other thumb, which is what the device could not do.
	await press(2, lookAt);
	await move(2, { x: lookAt.x + 55, y: lookAt.y - 20 });
	const held = (await sample()).hud.look;
	let disturbed = false;
	for (let i = 0; i < 4; i++) {
		await lift(1);
		await press(1, { x: moveAt.x, y: moveAt.y + 6 * i });
		await move(1, { x: moveAt.x + 30, y: moveAt.y - 40 });
		const now = await readProbe();
		if (JSON.stringify(now.hud.look) !== JSON.stringify(held)) { disturbed = true; }
	}
	t.check(!disturbed, `four left-thumb replants leave the look stick at ${held}`);
	await lift(1);
	await lift(2);
	await page.waitForTimeout(300);

	// A touch that begins on a stick belongs to it wherever it ends up.
	await press(1, moveAt);
	await move(1, lookAt);
	const wandered = await sample();
	t.check(
		wandered.hud.claims.move_stick === 1 && !('look_stick' in wandered.hud.claims),
		`a touch dragged across the screen keeps its owner `
			+ `(${JSON.stringify(wandered.hud.claims)})`
	);
	await lift(1);
	await page.waitForTimeout(300);

	// ---- pause --------------------------------------------------------------
	await press(1, toCss(rects.pause));
	await lift(1);
	await page.waitForTimeout(500);
	t.check(await page.evaluate(() => window.__itaw_paused === true), 'the pause button pauses');
	const menu = await page.evaluate(() => window.__itaw_menu);
	t.check(encloses(menu.view, menu.panel), `the menu fits the screen (${menu.panel} in ${menu.view})`);
	t.check(encloses(menu.panel, menu.resume), `Resume is inside the panel (${menu.resume})`);
	t.check(
		await page.evaluate(() => document.getElementById('stamp').hidden),
		"the shell's build stamp steps aside for the menu's own"
	);
	await page.screenshot({ path: path.join(SHOTS, '06-paused.png') });
	await page.keyboard.press('Escape');
	await page.waitForTimeout(500);
	t.check(await page.evaluate(() => window.__itaw_paused === false), 'the menu closes again');
	t.check(
		await page.evaluate(() => !document.getElementById('stamp').hidden),
		'and comes back when it closes'
	);

	// ---- settings survive a reload -----------------------------------------
	const stored = await page.evaluate(() => window.__itaw_store.read('settings.v1'));
	t.check(
		!!stored && 'look_style' in JSON.parse(stored),
		`settings are written to durable storage (${String(stored).slice(0, 60)})`
	);
	await page.evaluate(() => {
		const kept = JSON.parse(window.__itaw_store.read('settings.v1'));
		kept.look_style = 1;
		kept.stick_deadzone = 0.31;
		window.__itaw_store.write('settings.v1', JSON.stringify(kept));
	});
	await page.reload({ waitUntil: 'load' });
	await page.waitForSelector('#begin:not([hidden])', { timeout: BOOT_MS });
	await page.tap('#begin');
	await page.waitForFunction(() => document.getElementById('veil').hidden, null, { timeout: BOOT_MS });
	await page.waitForTimeout(2000);
	await threeFingerTap();
	const restored = await sample();
	t.check(
		restored && restored.hud.style === 'drag',
		`a stored look style is applied on the next load (${restored && restored.hud.style})`
	);
	t.check(
		!byId(restored.hud.rects).look_stick,
		'the drag style takes the right stick off the screen'
	);

	// ---- saving -------------------------------------------------------------
	// The shell is the only thing that hears the browser say a tab is going
	// away, so the whole autosave story hangs off one registered callback.
	t.check(
		await page.evaluate(() => typeof window.__itaw_onSuspend === 'function'),
		'the game registers a suspend hook with the shell'
	);

	await page.evaluate(() => window.__itaw_store.erase('save.auto'));
	await page.evaluate(() => { window.dispatchEvent(new Event('pagehide')); });
	await page.waitForTimeout(400);
	const afterHide = await page.evaluate(() => window.__itaw_store.read('save.auto'));
	t.check(
		!!afterHide && JSON.parse(afterHide).nodes.player !== undefined,
		'a tab going away writes an autosave carrying the player'
	);

	// The event iOS actually fires when the app is backgrounded.
	await page.evaluate(() => window.__itaw_store.erase('save.auto'));
	await page.evaluate(() => {
		Object.defineProperty(document, 'visibilityState', { value: 'hidden', configurable: true });
		document.dispatchEvent(new Event('visibilitychange'));
	});
	await page.waitForTimeout(400);
	t.check(
		!!(await page.evaluate(() => window.__itaw_store.read('save.auto'))),
		'so does the tab becoming hidden'
	);
	await page.evaluate(() => {
		Object.defineProperty(document, 'visibilityState', { value: 'visible', configurable: true });
	});

	// The write has to still be there after the tab is thrown away and rebuilt.
	const before = await page.evaluate(() => window.__itaw_store.read('save.auto'));
	await page.evaluate(() => window.__itaw_store.drained());
	await page.reload({ waitUntil: 'load' });
	await page.waitForSelector('#begin:not([hidden])', { timeout: BOOT_MS });
	const survived = await page.evaluate(() => window.__itaw_store.read('save.auto'));
	// Not byte for byte: reloading fires pagehide, which correctly writes a
	// fresh autosave with a new timestamp. What has to survive is the world.
	t.check(
		!!survived
			&& JSON.stringify(JSON.parse(survived).nodes) === JSON.stringify(JSON.parse(before).nodes),
		'and the world in the autosave survives a reload unchanged'
	);
	t.check(
		['yes', 'no', 'unsupported', 'unknown'].includes(
			await page.evaluate(() => window.__itaw_store.persisted())
		),
		`storage persistence is asked about and reported `
			+ `(${await page.evaluate(() => window.__itaw_store.persisted())})`
	);

	await page.tap('#begin');
	await page.waitForFunction(() => document.getElementById('veil').hidden, null, { timeout: BOOT_MS });
	await page.waitForTimeout(2000);

	// A browser that refuses to keep anything must say so, not crash.
	await page.evaluate(() => {
		window.__itaw_realWrite = window.__itaw_store.write;
		window.__itaw_store.write = function () { return 'memory-only'; };
	});
	await page.evaluate(() => window.__itaw_store.erase('save.auto'));
	await page.evaluate(() => window.__itaw_onSuspend());
	await page.waitForTimeout(600);
	const complaint = await page.locator('.toast').first().textContent().catch(() => '');
	t.check(
		/Export code/.test(complaint || ''),
		`a save that cannot be kept says so on screen (${(complaint || 'no toast').slice(0, 60)})`
	);
	await page.evaluate(() => { window.__itaw_store.write = window.__itaw_realWrite; });
	await page.evaluate(() => {
		document.querySelectorAll('.toast__x').forEach((x) => x.click());
	});

	// ---- add to home screen, once -------------------------------------------
	await page.evaluate(() => window.__itaw_store.erase('a2hs.told'));
	await page.evaluate(() => window.__itaw_offerHomeScreen());
	await page.waitForTimeout(200);
	const offered = await page.locator('.toast').count();
	t.check(offered === 1, `the home-screen offer appears once (${offered} toasts)`);
	t.check(
		!!(await page.evaluate(() => window.__itaw_store.read('a2hs.told'))),
		'and records that it was made'
	);
	await page.evaluate(() => {
		document.querySelectorAll('.toast__x').forEach((x) => x.click());
	});
	await page.evaluate(() => window.__itaw_offerHomeScreen());
	await page.waitForTimeout(200);
	t.check(
		await page.locator('.toast').count() === 0,
		'and never appears again'
	);

	await threeFingerTap();
	await threeFingerTap();
	const closed = await readProbe();
	t.check(!!closed && closed.visible === false, 'a second three-finger tap closes the overlay');

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
