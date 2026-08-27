/**
 * Shared plumbing for the browser smoke suites.
 *
 * A static server whose document root can be swapped mid-test (that is how we
 * simulate a deploy landing under a running client), a Chromium launched at
 * iPhone 16 Pro Max landscape metrics, and a tiny assertion tally.
 */
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

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

// Mirrors web/_headers, so the suites exercise the caching contract we ship.
function cacheControl(name) {
	if (/^index\.[0-9a-f]{10}\./.test(name)) {
		return 'public, max-age=31536000, immutable';
	}
	if (/\.png$/.test(name)) { return 'public, max-age=86400'; }
	return 'no-cache, must-revalidate';
}

/**
 * A server whose root is `state.dir`, reassignable at any time.
 *
 * `state.stale = { name, body }` answers *document* requests for that basename
 * with `body` until a request carrying `?fresh=1` arrives, which disarms it.
 *
 * That models the failure worth reproducing -- a host still handing out a
 * document from a previous build -- and it disarms on the one event that means
 * the client has decided to start clean, so nothing has to race a directory
 * swap against a reload it cannot see. Counting uses instead does not work:
 * navigation preload can spend one, and whether it is enabled at any moment
 * depends on how recently a worker activated.
 */
function serve(state, port) {
	const server = http.createServer((req, res) => {
		const root = path.resolve(state.dir);
		let rel = decodeURIComponent(req.url.split('?')[0]);
		if (rel === '/') { rel = '/index.html'; }
		const file = path.join(root, rel);
		if (!file.startsWith(root) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
			res.writeHead(404);
			return res.end('not found');
		}
		const wantsDocument = req.headers['sec-fetch-mode'] === 'navigate'
			|| /text\/html/.test(req.headers.accept || '');
		let body;
		if (state.stale && /[?&]fresh=1(&|$)/.test(req.url)) { state.stale = null; }
		let servedStale = false;
		if (state.stale && state.stale.name === path.basename(file) && wantsDocument) {
			body = Buffer.from(state.stale.body);
			servedStale = true;
		} else {
			body = fs.readFileSync(file);
		}
		// ITAW_SERVE_LOG=1 turns the server into a witness. Which request got
		// the one-shot, and in what order, is the only way to tell a suite that
		// is wrong from a browser that is different.
		if (process.env.ITAW_SERVE_LOG) {
			console.log(`[serve] ${rel} mode=${req.headers['sec-fetch-mode'] || '-'}`
				+ ` dest=${req.headers['sec-fetch-dest'] || '-'} stale=${servedStale}`);
		}
		res.writeHead(200, {
			'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream',
			'Content-Length': body.length,
			'Cache-Control': cacheControl(path.basename(file)),
		});
		return res.end(body);
	});
	return new Promise((resolve) => server.listen(port, () => resolve(server)));
}

async function openBrowser() {
	const launch = {
		args: [
			'--use-gl=swiftshader',
			'--enable-unsafe-swiftshader',
			// Headless Chromium has no audio device and suspends the
			// AudioContext even behind a trusted tap, which would make "is the
			// engine mixing anything" untestable. On the phone the tap gate is
			// what unlocks audio, and only the device can confirm that.
			'--autoplay-policy=no-user-gesture-required',
		],
	};
	if (process.env.CHROMIUM_PATH) { launch.executablePath = process.env.CHROMIUM_PATH; }
	const browser = await chromium.launch(launch);
	const context = await browser.newContext({
		viewport: VIEWPORT,
		deviceScaleFactor: 3,
		isMobile: true,
		hasTouch: true,
		userAgent: UA,
	});
	return { browser, context };
}

/** Assertion tally. `report()` returns the process exit code. */
function tally(label) {
	const failures = [];
	return {
		check(condition, message) {
			if (!condition) { failures.push(message); }
			console.log(`${condition ? '  ok  ' : ' FAIL '} ${message}`);
			return condition;
		},
		report() {
			if (failures.length) {
				console.error(`\n${label}: ${failures.length} check(s) failed`);
				failures.forEach((f) => console.error(`  - ${f}`));
				return 1;
			}
			console.log(`\n${label}: all checks passed`);
			return 0;
		},
	};
}

module.exports = { VIEWPORT, UA, serve, openBrowser, tally };
