// This service worker is required to expose an exported Godot project as a
// Progressive Web App. It provides an offline fallback page telling the user
// that they need an Internet connection to run the project if desired.
// Incrementing CACHE_VERSION will kick off the install event and force
// previously cached resources to be updated from the network.
/** @type {string} */
const CACHE_VERSION = 'bd91aade85fb24af';
/** @type {string} */
const CACHE_PREFIX = 'Is There a Way?-sw-cache-';
const CACHE_NAME = CACHE_PREFIX + CACHE_VERSION;
/** @type {string} */
const OFFLINE_URL = 'index.offline.html';
/** @type {boolean} */
const ENSURE_CROSSORIGIN_ISOLATION_HEADERS = false;
// Files that will be cached on load.
/** @type {string[]} */
const CACHED_FILES = ["index.html", "index.9389e4ee81.js", "index.offline.html", "index.icon.png", "index.apple-touch-icon.png", "index.9389e4ee81.audio.worklet.js", "index.9389e4ee81.audio.position.worklet.js", "index.manifest.json", "index.144x144.png", "index.180x180.png", "index.512x512.png"];
// Files that we might not want the user to preload, and will only be cached on first load.
/** @type {string[]} */
const CACHEABLE_FILES = ["index.9389e4ee81.wasm","index.9389e4ee81.pck"];
const FRESH = /[?&]fresh=1(&|$)/;
const FULL_CACHE = CACHED_FILES.concat(CACHEABLE_FILES);

self.addEventListener('install', (event) => {
	event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CACHED_FILES)));
});

self.addEventListener('activate', (event) => {
	event.waitUntil(caches.keys().then(
		function (keys) {
			// Remove old caches.
			return Promise.all(keys.filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME).map((key) => caches.delete(key)));
		}
	).then(function () {
		// Enable navigation preload if available.
		return ('navigationPreload' in self.registration) ? self.registration.navigationPreload.enable() : Promise.resolve();
	}));
});

/**
 * Ensures that the response has the correct COEP/COOP headers
 * @param {Response} response
 * @returns {Response}
 */
function ensureCrossOriginIsolationHeaders(response) {
	if (response.headers.get('Cross-Origin-Embedder-Policy') === 'require-corp'
		&& response.headers.get('Cross-Origin-Opener-Policy') === 'same-origin') {
		return response;
	}

	const crossOriginIsolatedHeaders = new Headers(response.headers);
	crossOriginIsolatedHeaders.set('Cross-Origin-Embedder-Policy', 'require-corp');
	crossOriginIsolatedHeaders.set('Cross-Origin-Opener-Policy', 'same-origin');
	const newResponse = new Response(response.body, {
		status: response.status,
		statusText: response.statusText,
		headers: crossOriginIsolatedHeaders,
	});

	return newResponse;
}

/**
 * Calls fetch and cache the result if it is cacheable
 * @param {FetchEvent} event
 * @param {Cache} cache
 * @param {boolean} isCacheable
 * @returns {Response}
 */
async function fetchAndCache(event, cache, isCacheable) {
	// Use the preloaded response, if it's there
	/** @type { Response } */
	let response = await event.preloadResponse;
	if (response == null) {
		// Or, go over network.
		response = await self.fetch(event.request);
	}

	if (ENSURE_CROSSORIGIN_ISOLATION_HEADERS) {
		response = ensureCrossOriginIsolationHeaders(response);
	}

	if (isCacheable) {
		// And update the cache
		cache.put(event.request, response.clone());
	}

	return response;
}

self.addEventListener(
	'fetch',
	/**
	 * Triggered on fetch
	 * @param {FetchEvent} event
	 */
	(event) => {
		// PATCHED (tools/ci/service_worker.py): the ?fresh=1 escape hatch must
		// reach the network even when every cached file is broken, so nothing
		// loaded by such a page enters this handler at all. See web/boot.js.
		if (FRESH.test(event.request.url) || FRESH.test(event.request.referrer || '')) {
			return;
		}
		const isNavigate = event.request.mode === 'navigate';
		const url = event.request.url || '';
		const referrer = event.request.referrer || '';
		const base = referrer.slice(0, referrer.lastIndexOf('/') + 1);
		const local = url.startsWith(base) ? url.replace(base, '') : '';
		const isCacheable = FULL_CACHE.some((v) => v === local) || (base === referrer && base.endsWith(CACHED_FILES[0]));
		if (isNavigate || isCacheable) {
			event.respondWith((async () => {
				// Try to use cache first
				const cache = await caches.open(CACHE_NAME);
				if (isNavigate) {
					// PATCHED (tools/ci/service_worker.py): network-first for the
					// document. index.html names the content-hashed engine payload, so
					// serving it from cache pins the player to whichever build they
					// first loaded. Offline still works: we fall back to the cached
					// document, and only then to the offline page.
					//
					// Deliberately not fetchAndCache(): that awaits
					// event.preloadResponse, and a navigation preload that rejects
					// sends us down the fallback below -- which serves the *previous*
					// build's document, whose payload the deploy we are trying to
					// pick up has already removed. A 404 on the engine wasm is the
					// symptom, and it is not recoverable by reloading.
					try {
						const doc = await self.fetch(event.request);
						if (!doc || !doc.ok) {
							throw new Error(`document status ${doc && doc.status}`);
						}
						cache.put(event.request, doc.clone());
						return doc;
					} catch (e) {
						const offlineDoc = await cache.match(event.request) || await cache.match(CACHED_FILES[0]);
						return offlineDoc || caches.match(OFFLINE_URL);
					}
				}
				let cached = await cache.match(event.request);
				if (cached != null) {
					if (ENSURE_CROSSORIGIN_ISOLATION_HEADERS) {
						cached = ensureCrossOriginIsolationHeaders(cached);
					}
					return cached;
				}
				// Try network if don't have it in cache.
				const response = await fetchAndCache(event, cache, isCacheable);
				return response;
			})());
		} else if (ENSURE_CROSSORIGIN_ISOLATION_HEADERS) {
			event.respondWith((async () => {
				let response = await fetch(event.request);
				response = ensureCrossOriginIsolationHeaders(response);
				return response;
			})());
		}
	}
);

self.addEventListener('message', (event) => {
	// No cross origin
	if (event.origin !== self.origin) {
		return;
	}
	const id = event.source.id || '';
	const msg = event.data || '';
	// Ensure it's one of our clients.
	self.clients.get(id).then(function (client) {
		if (!client) {
			return; // Not a valid client.
		}
		if (msg === 'claim') {
			self.skipWaiting().then(() => self.clients.claim());
		} else if (msg === 'clear') {
			caches.delete(CACHE_NAME);
		} else if (msg === 'update') {
			self.skipWaiting().then(() => self.clients.claim()).then(() => self.clients.matchAll()).then((all) => all.forEach((c) => c.navigate(c.url)));
		}
	});
});


// --- appended by tools/ci/service_worker.py ---------------------------------
// Take over as soon as we are installed instead of waiting for every tab to
// close. An installed PWA on iOS may never close a tab, and a player who cannot
// reach a new build from their phone has no recourse at all. The page watches
// for this and offers "New version - tap to reload"; see web/boot.js.
self.addEventListener('install', () => {
	self.skipWaiting();
});

self.addEventListener('activate', (event) => {
	event.waitUntil(self.clients.claim());
});
