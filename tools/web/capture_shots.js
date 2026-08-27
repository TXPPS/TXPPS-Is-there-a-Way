/**
 * Photograph the reference gallery into docs/shots/.
 *
 * A test that walks the player around cannot review art: two runs point the
 * camera at different walls, so the two screenshots are not comparable and
 * nothing can be said about a change. `src/render/shot_list.gd` holds a fixed
 * list of poses still until each is photographed; this drives it.
 *
 *   node tools/web/capture_shots.js <build-dir> <out-dir>
 *
 * The output is committed, which is the point: a reviewer with no desktop
 * editor reads a directory of PNGs in one pass and says what is wrong.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { serve, openBrowser } = require('./harness');

const BUILD = path.resolve(process.argv[2] || 'build');
const OUT = path.resolve(process.argv[3] || 'docs/shots');
const PORT = 8097;
const BOOT_MS = 180000;
const SHOT_MS = 30000;

(async () => {
	fs.mkdirSync(OUT, { recursive: true });
	const server = await serve({ dir: BUILD }, PORT);
	const { browser, context } = await openBrowser();
	const page = await context.newPage();
	const problems = [];
	page.on('pageerror', (e) => problems.push(String(e)));

	await page.goto(`http://127.0.0.1:${PORT}/index.html?shots=1`, { waitUntil: 'load' });
	await page.waitForSelector('#begin:not([hidden])', { timeout: BOOT_MS });
	await page.tap('#begin');
	await page.waitForFunction(() => document.getElementById('veil').hidden, null, { timeout: BOOT_MS });

	// The engine only starts publishing once the shot list has a player to move.
	await page.waitForFunction(() => window.__itaw_shot, null, { timeout: BOOT_MS });
	const total = (await page.evaluate(() => window.__itaw_shot)).total;
	console.log(`shots: ${total} poses`);

	const taken = [];
	for (let i = 0; i < total; i++) {
		await page.waitForFunction(
			(want) => window.__itaw_shot && window.__itaw_shot.ready && window.__itaw_shot.index === want,
			i,
			{ timeout: SHOT_MS }
		);
		const shot = await page.evaluate(() => window.__itaw_shot);
		const file = path.join(OUT, `${shot.name}.png`);
		// CSS resolution, not device pixels: a 3x gallery is nine times the bytes
		// for a review that is about light and material, not about pixel grid.
		await page.screenshot({ path: file, scale: 'css' });
		const bytes = fs.statSync(file).size;
		// A uniformly black frame compresses to a couple of kilobytes. Anything
		// this small means the post stack ate the scene, which is a failure
		// worth stopping for rather than committing a gallery of black.
		if (bytes < 4000) { problems.push(`${shot.name} is ${bytes} bytes: the frame is empty`); }
		taken.push(`${shot.name} (${(bytes / 1024).toFixed(0)} kB)`);
		console.log(`  ${shot.name}  ${(bytes / 1024).toFixed(0)} kB`);
		await page.evaluate(() => window.__itaw_shotNext());
	}

	await browser.close();
	server.close();
	if (problems.length) {
		console.error('\ncapture: ' + problems.length + ' problem(s)');
		problems.forEach((p) => console.error('  - ' + p));
		process.exit(1);
	}
	console.log(`\ncapture: ${taken.length} shots into ${path.relative(process.cwd(), OUT)}`);
})().catch((err) => {
	console.error('capture: crashed', err);
	process.exit(2);
});
