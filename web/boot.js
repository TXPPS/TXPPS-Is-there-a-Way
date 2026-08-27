// Boot, escape hatch, instrumentation and update path for the web build.
//
// This is inlined into build/index.html by tools/ci/postprocess_web.py, at the
// `$ITAW_BOOT` marker in web/shell.html. Inlined rather than loaded as a second
// <script>, because half of this file's job is to be the recourse when the
// cache has gone wrong -- a recourse that itself lived in a cacheable file
// would not be one.
//
// tools/ci/postprocess_web.py prepends `window.ITAW_BUILD = {...}` (the
// contents of build_stamp.json) immediately above this.
(function () {
	'use strict';

	var CONFIG = window.GODOT_CONFIG;
	var THREADS = window.GODOT_THREADS_ENABLED;
	var BUILD = window.ITAW_BUILD || {};

	var canvasEl = document.getElementById('canvas');
	var veil = document.getElementById('veil');
	var loading = document.getElementById('loading');
	var gauge = document.getElementById('gauge');
	var gaugeFill = document.getElementById('gauge-fill');
	var readoutLabel = document.getElementById('readout-label');
	var readoutValue = document.getElementById('readout-value');
	var beginBtn = document.getElementById('begin');
	var hint = document.getElementById('hint');
	var fault = document.getElementById('fault');
	var updateBtn = document.getElementById('update');
	var toastHost = document.getElementById('toasts');
	var stampEl = document.getElementById('stamp');
	var probe = document.getElementById('safe-probe');

	// ---- safe-area bridge --------------------------------------------------
	// Godot cannot see env(safe-area-inset-*), so we publish it. Returns
	// "top,right,bottom,left" in CSS pixels; see src/ui/safe_area_margin.gd.
	function safeArea() {
		try {
			var s = getComputedStyle(probe);
			return [s.paddingTop, s.paddingRight, s.paddingBottom, s.paddingLeft]
				.map(function (v) { return parseFloat(v) || 0; })
				.join(',');
		} catch (e) {
			return '0,0,0,0';
		}
	}
	window.__itaw_safeArea = safeArea;

	// ---- on-screen error surfacing -----------------------------------------
	// There is no console on a phone. Anything that would have been a silent
	// red line in devtools becomes a toast instead. Deduplicated hard: a
	// GDScript error inside _process fires sixty times a second, and sixty
	// toasts a second is a worse failure than the bug.
	var TOAST_MAX = 3;             // on screen at once
	var TOAST_DISTINCT_MAX = 12;   // distinct messages before we stop making more
	var NOTE_LINGER_MS = 7000;     // non-errors dismiss themselves; errors do not
	var MSG_MAX = 400;
	var toasts = {};
	var toastOrder = [];
	var distinctSeen = 0;
	var suppressed = false;

	// Emscripten and WebKit both emit these during normal operation.
	var BENIGN = /ResizeObserver loop|Script error\.?$|The play\(\) request was interrupted/;

	function dismiss(key) {
		var t = toasts[key];
		if (!t) { return; }
		if (t.timer) { clearTimeout(t.timer); }
		if (t.el.parentNode) { t.el.parentNode.removeChild(t.el); }
		delete toasts[key];
		toastOrder = toastOrder.filter(function (k) { return k !== key; });
	}

	function note(text, kind) {
		if (!toastHost) { return; }
		var msg = String(text == null ? '' : text).trim();
		if (!msg || BENIGN.test(msg)) { return; }
		if (msg.length > MSG_MAX) { msg = msg.slice(0, MSG_MAX) + '…'; }
		var key = (kind || 'note') + '|' + msg;

		var existing = toasts[key];
		if (existing) {
			existing.count += 1;
			existing.countEl.textContent = '×' + existing.count;
			existing.countEl.hidden = false;
			return;
		}
		if (distinctSeen >= TOAST_DISTINCT_MAX) {
			if (!suppressed) {
				suppressed = true;
				note('Further errors suppressed. Reload with ?fresh=1 for a clean start.', 'note');
			}
			return;
		}
		distinctSeen += 1;

		var el = document.createElement('div');
		el.className = 'toast' + (kind === 'note' ? ' toast--note' : '');
		var body = document.createElement('span');
		body.className = 'toast__msg';
		body.textContent = msg;
		var count = document.createElement('span');
		count.className = 'toast__count';
		count.hidden = true;
		var x = document.createElement('span');
		x.className = 'toast__x';
		x.textContent = '×';
		el.appendChild(body);
		el.appendChild(count);
		el.appendChild(x);
		el.addEventListener('click', function () { dismiss(key); });
		toastHost.appendChild(el);

		var entry = { el: el, countEl: count, count: 1, timer: 0 };
		toasts[key] = entry;
		toastOrder.push(key);
		while (toastOrder.length > TOAST_MAX) { dismiss(toastOrder[0]); }
		if (kind === 'note') {
			entry.timer = setTimeout(function () { dismiss(key); }, NOTE_LINGER_MS);
		}
	}
	window.__itaw_note = function (text, kind) { note(text, kind); };

	window.addEventListener('error', function (e) {
		note(e.message || String(e.error || 'script error'), 'error');
	});
	window.addEventListener('unhandledrejection', function (e) {
		var r = e.reason;
		note('Unhandled: ' + ((r && (r.message || r)) || 'promise rejection'), 'error');
	});

	// ---- hard escape hatch: ?fresh=1 ---------------------------------------
	// A cache-first PWA that goes wrong is unfixable from a phone: there is no
	// devtools, and Safari's "clear website data" is buried and nukes every
	// site. This is the recourse. The service worker refuses to serve any
	// request carrying fresh=1 (see tools/ci/service_worker.py), so this page
	// arrives from the network even when the cached one is broken.
	//
	// Saves are deliberately untouched: this clears the code, not the player.
	var PURGE_DEADLINE_MS = 6000;

	function cleanUrl() {
		var kept = location.search.replace(/^\?/, '').split('&').filter(function (part) {
			return part !== '' && part !== 'fresh=1';
		});
		return location.origin + location.pathname
			+ (kept.length ? '?' + kept.join('&') : '') + location.hash;
	}

	// Workers first, then caches: a worker that is still alive when its cache
	// is deleted can repopulate it from its own install handler.
	function purgeEverything() {
		var report = { caches: 0, workers: 0, done: false };
		if (readoutLabel) { readoutLabel.textContent = 'Purging'; }
		var clean = cleanUrl();
		var landed = false;

		function land() {
			if (landed) { return; }
			landed = true;
			try { sessionStorage.setItem('itaw.purged', JSON.stringify(report)); } catch (e) { /* private mode */ }
			location.replace(clean);
		}

		// Never strand the player on the purge screen, whatever hangs.
		setTimeout(land, PURGE_DEADLINE_MS);

		unregisterWorkers(report)
			.then(function () { return deleteCaches(report); })
			.then(function () {
				report.done = true;
				// Hosts that ignore web/_headers can still hold a stale
				// index.html in the HTTP cache; this is the only way to be sure
				// the reload gets the real one.
				return fetch(clean, { cache: 'reload' }).catch(function () {});
			})
			.catch(function () { /* land with whatever we managed */ })
			.then(land);
	}

	function unregisterWorkers(report) {
		if (!navigator.serviceWorker || !navigator.serviceWorker.getRegistrations) {
			return Promise.resolve();
		}
		return navigator.serviceWorker.getRegistrations().then(function (regs) {
			report.workers = regs.length;
			return Promise.all(regs.map(function (reg) {
				return reg.unregister().catch(function () { return false; });
			}));
		}).catch(function () {});
	}

	function deleteCaches(report) {
		if (!window.caches || !caches.keys) { return Promise.resolve(); }
		return caches.keys().then(function (keys) {
			report.caches = keys.length;
			return Promise.all(keys.map(function (key) {
				return caches.delete(key).catch(function () { return false; });
			}));
		}).catch(function () {});
	}

	if (/(^|[?&])fresh=1(&|$)/.test(location.search)) {
		purgeEverything();
		return;
	}

	// ---- persistent store --------------------------------------------------
	// Two stores, on purpose. IndexedDB is the durable one and is where a save
	// really lives; localStorage is a synchronous mirror, and synchronous is the
	// only thing that reliably lands when iOS kills a backgrounded tab mid-write.
	// On boot the mirror wins for any key both hold, because it is the one that
	// can have been written after the last IndexedDB transaction completed.
	// Godot talks to this through src/core/storage.gd.
	window.__itaw_store = (function () {
		var PREFIX = 'itaw.kv.';
		var DB_NAME = 'itaw';
		var STORE = 'kv';
		var cache = {};
		var db = null;
		var state = { ready: false, local: false, idb: false, pending: 0, verified: 0, failed: 0, error: '' };
		var settle;
		var ready = new Promise(function (resolve) { settle = resolve; });

		function probeLocal() {
			try {
				localStorage.setItem(PREFIX + '__probe', '1');
				localStorage.removeItem(PREFIX + '__probe');
				return true;
			} catch (e) {
				state.error = 'local storage unavailable';
				return false;
			}
		}

		function loadLocal() {
			if (!state.local) { return; }
			for (var i = 0; i < localStorage.length; i++) {
				var k = localStorage.key(i);
				if (k && k.indexOf(PREFIX) === 0) {
					cache[k.slice(PREFIX.length)] = localStorage.getItem(k);
				}
			}
		}

		function openDb() {
			return new Promise(function (resolve) {
				var req;
				try { req = indexedDB.open(DB_NAME, 1); }
				catch (e) { state.error = 'indexeddb unavailable'; return resolve(null); }
				req.onupgradeneeded = function () { req.result.createObjectStore(STORE); };
				req.onsuccess = function () { resolve(req.result); };
				req.onerror = function () { state.error = 'indexeddb open failed'; resolve(null); };
				req.onblocked = function () { state.error = 'indexeddb blocked'; resolve(null); };
			});
		}

		function readAll(database) {
			return new Promise(function (resolve) {
				try {
					var tx = database.transaction(STORE, 'readonly');
					var store = tx.objectStore(STORE);
					var keyReq = store.getAllKeys();
					var valReq = store.getAll();
					tx.oncomplete = function () {
						var keys = keyReq.result || [];
						var vals = valReq.result || [];
						for (var i = 0; i < keys.length; i++) {
							if (!(keys[i] in cache)) { cache[keys[i]] = vals[i]; }
						}
						resolve();
					};
					tx.onerror = function () { resolve(); };
				} catch (e) { resolve(); }
			});
		}

		function verify(key, expected) {
			try {
				var tx = db.transaction(STORE, 'readonly');
				var req = tx.objectStore(STORE).get(key);
				tx.oncomplete = function () {
					if (req.result === expected) { state.verified += 1; }
					else { state.failed += 1; state.error = 'indexeddb read-back mismatch'; }
				};
			} catch (e) { state.failed += 1; }
		}

		function put(key, value) {
			if (!db) { return; }
			state.pending += 1;
			try {
				var tx = db.transaction(STORE, 'readwrite');
				tx.objectStore(STORE).put(value, key);
				tx.oncomplete = function () { state.pending -= 1; verify(key, value); };
				tx.onerror = function () { state.pending -= 1; state.failed += 1; state.error = 'indexeddb write failed'; };
				tx.onabort = function () { state.pending -= 1; state.failed += 1; state.error = 'indexeddb write aborted'; };
			} catch (e) {
				state.pending -= 1;
				state.failed += 1;
				state.error = 'indexeddb write threw';
			}
		}

		state.local = probeLocal();
		loadLocal();
		openDb().then(function (opened) {
			db = opened;
			state.idb = !!opened;
			return opened ? readAll(opened) : null;
		}).then(function () {
			state.ready = true;
			settle();
		});

		return {
			ready: ready,
			read: function (key) { return (key in cache) ? cache[key] : null; },
			write: function (key, value) {
				cache[key] = value;
				var mirrored = false;
				if (state.local) {
					try { localStorage.setItem(PREFIX + key, value); mirrored = true; }
					catch (e) { state.local = false; state.error = 'local storage full or blocked'; }
				}
				put(key, value);
				if (mirrored) { return 'ok'; }
				return db ? 'idb-only' : 'memory-only';
			},
			erase: function (key) {
				delete cache[key];
				try { localStorage.removeItem(PREFIX + key); } catch (e) { /* nothing to remove */ }
				if (db) {
					try { db.transaction(STORE, 'readwrite').objectStore(STORE).delete(key); }
					catch (e) { /* already gone */ }
				}
			},
			keys: function () { return Object.keys(cache).join(','); },
			status: function () { return JSON.stringify(state); },
			health: function () {
				if (!state.ready) { return 'opening'; }
				if (state.failed > 0) { return 'degraded'; }
				if (state.local && state.idb) { return 'ok'; }
				if (state.idb) { return 'idb-only'; }
				if (state.local) { return 'local-only'; }
				return 'none';
			}
		};
	}());

	// The game registers __itaw_onSuspend so it can flush a save synchronously.
	// iOS discards backgrounded tabs without warning and fires no further
	// frames, so anything not written inside these handlers is lost.
	function suspendGame() {
		if (typeof window.__itaw_onSuspend === 'function') {
			try { window.__itaw_onSuspend(); } catch (e) { note('Suspend hook failed: ' + e.message, 'error'); }
		}
	}
	document.addEventListener('freeze', suspendGame);
	window.addEventListener('pagehide', suspendGame);

	// ---- browser affordances we never want ---------------------------------
	// Pinch/double-tap zoom. iOS ignores user-scalable=no in some contexts.
	['gesturestart', 'gesturechange', 'gestureend'].forEach(function (type) {
		document.addEventListener(type, function (e) { e.preventDefault(); }, { passive: false });
	});
	// Rubber-band scrolling anywhere that is not the canvas (the canvas has
	// touch-action:none, so the browser never tries to scroll from it).
	document.addEventListener('touchmove', function (e) {
		if (e.target !== canvasEl) { e.preventDefault(); }
	}, { passive: false });
	document.addEventListener('contextmenu', function (e) { e.preventDefault(); });
	// Belt-and-braces double-tap suppression for older WebKit.
	var lastTouchEnd = 0;
	document.addEventListener('touchend', function (e) {
		var now = Date.now();
		if (now - lastTouchEnd <= 300) { e.preventDefault(); }
		lastTouchEnd = now;
	}, { passive: false });

	function showFault(err) {
		var msg = (err && err.message) ? err.message : String(err);
		note(msg, 'error');
		loading.style.display = 'none';
		beginBtn.hidden = true;
		hint.hidden = true;
		fault.style.display = 'block';
		fault.textContent = msg;
	}

	// ---- build stamp -------------------------------------------------------
	// Deliberately not a real button. A 44px tap target pinned over the canvas
	// would eat a stick drag that happened to start in that corner, so the
	// element ignores pointer events entirely and we recognise the tap
	// ourselves -- a tap with no travel, which the floating stick reads as zero
	// deflection anyway.
	var STAMP_TRAVEL_MAX = 12;
	var STAMP_HOLD_MAX = 500;

	function stampShort() {
		var v = BUILD.version ? 'v' + BUILD.version : 'dev';
		var c = BUILD.commit ? String(BUILD.commit).slice(0, 7) : 'local';
		return v + ' ' + c;
	}

	function stampReport() {
		var vp = window.visualViewport;
		return [
			'Is There a Way? ' + stampShort(),
			'branch   ' + (BUILD.branch || '-'),
			'built    ' + (BUILD.built_at || '-'),
			'payload  ' + (CONFIG['executable'] || '-'),
			'store    ' + window.__itaw_store.health(),
			'worker   ' + workerState(),
			'viewport ' + Math.round(vp ? vp.width : innerWidth) + 'x'
				+ Math.round(vp ? vp.height : innerHeight) + ' @' + (devicePixelRatio || 1),
			'safearea ' + safeArea(),
			'agent    ' + navigator.userAgent
		].join('\n');
	}

	function copyText(text) {
		if (navigator.clipboard && navigator.clipboard.writeText) {
			navigator.clipboard.writeText(text).then(function () {
				note('Build details copied.', 'note');
			}, function () { legacyCopy(text); });
			return;
		}
		legacyCopy(text);
	}

	// iOS Safari only honours execCommand('copy') for a genuinely selected,
	// editable range -- hence the contentEditable dance.
	function legacyCopy(text) {
		var ok = false;
		try {
			var ta = document.createElement('textarea');
			ta.value = text;
			ta.contentEditable = 'true';
			ta.readOnly = false;
			ta.style.cssText = 'position:fixed;left:0;top:0;width:1px;height:1px;opacity:0;';
			document.body.appendChild(ta);
			var range = document.createRange();
			range.selectNodeContents(ta);
			var sel = window.getSelection();
			sel.removeAllRanges();
			sel.addRange(range);
			ta.setSelectionRange(0, text.length);
			ok = document.execCommand('copy');
			sel.removeAllRanges();
			document.body.removeChild(ta);
		} catch (e) { ok = false; }
		if (ok) { note('Build details copied.', 'note'); return; }
		// Last resort: put it on screen so it can be selected by hand.
		note(text, 'note');
		var last = toastHost.lastChild;
		if (last) { last.classList.add('toast--select'); }
	}

	function hitsStamp(x, y) {
		if (!stampEl || stampEl.hidden) { return false; }
		var r = stampEl.getBoundingClientRect();
		return x >= r.left && x <= r.right && y >= r.top && y <= r.bottom;
	}

	var stampTouch = null;
	document.addEventListener('touchstart', function (e) {
		var t = e.changedTouches[0];
		if (!t || !hitsStamp(t.clientX, t.clientY)) { stampTouch = null; return; }
		stampTouch = { id: t.identifier, x: t.clientX, y: t.clientY, at: Date.now() };
	}, { passive: true });

	document.addEventListener('touchend', function (e) {
		if (!stampTouch) { return; }
		for (var i = 0; i < e.changedTouches.length; i++) {
			var t = e.changedTouches[i];
			if (t.identifier !== stampTouch.id) { continue; }
			var travel = Math.abs(t.clientX - stampTouch.x) + Math.abs(t.clientY - stampTouch.y);
			var held = Date.now() - stampTouch.at;
			if (travel <= STAMP_TRAVEL_MAX && held <= STAMP_HOLD_MAX && hitsStamp(t.clientX, t.clientY)) {
				copyText(stampReport());
			}
			stampTouch = null;
			return;
		}
	}, { passive: true });

	// Mouse, for the desktop editor and for the browser tests.
	document.addEventListener('click', function (e) {
		if (hitsStamp(e.clientX, e.clientY)) { copyText(stampReport()); }
	});

	if (stampEl) {
		stampEl.textContent = stampShort();
		stampEl.hidden = false;
	}
	window.__itaw_buildStamp = function () { return stampShort(); };

	// ---- engine ------------------------------------------------------------
	var missing = Engine.getMissingFeatures({ threads: THREADS });
	if (missing.length !== 0) {
		showFault(new Error('This browser is missing:\n' + missing.join('\n')));
		return;
	}

	CONFIG['onProgress'] = function (current, total) {
		if (total > 0) {
			gauge.classList.remove('unknown');
			var pct = Math.max(0, Math.min(100, (current / total) * 100));
			gaugeFill.style.width = pct.toFixed(1) + '%';
			readoutValue.textContent = pct.toFixed(0) + '%';
		} else {
			gauge.classList.add('unknown');
			readoutValue.textContent = '';
		}
	};

	// Godot writes every engine-level error here, GDScript runtime errors
	// included. One error is several printErr calls (message, then "at:"), so
	// coalesce a frame's worth before raising a toast.
	var errBuffer = [];
	var errFlush = 0;
	CONFIG['onPrintError'] = function () {
		var line = Array.prototype.join.call(arguments, ' ');
		console.error(line); // eslint-disable-line no-console
		errBuffer.push(line);
		if (errFlush) { return; }
		errFlush = setTimeout(function () {
			errFlush = 0;
			var joined = errBuffer.join(' ').replace(/\s+/g, ' ').trim();
			errBuffer = [];
			note(joined, 'error');
		}, 60);
	};

	var engine = new Engine(CONFIG);
	var exe = CONFIG['executable'];
	var pack = CONFIG['mainPack'] || (exe + '.pck');

	// Load everything up front, but do NOT start. Godot builds its AudioContext
	// during start(), and Safari only lets that context begin running if it is
	// created inside a user gesture -- so start() has to happen under the tap.
	// init() must come first: it is what installs the progress callback.
	var loaded = Promise.all([
		engine.init(exe).then(function () { return engine.preloadFile(pack, pack); }),
		window.__itaw_store.ready
	]);

	loaded.then(function () {
		gauge.classList.remove('unknown');
		gaugeFill.style.width = '100%';
		readoutLabel.textContent = 'Ready';
		readoutValue.textContent = '';
		loading.style.display = 'none';
		beginBtn.hidden = false;
		hint.hidden = false;
		// Only now: the install handler re-fetches the shell files, and doing
		// that while the 37 MB payload is still in flight costs first-load time
		// on the connection that can least afford it.
		installWorker();
	}).catch(showFault);

	var started = false;
	function begin() {
		if (started) { return; }
		started = true;

		// Nudge WebKit's audio unlock heuristics inside the gesture, then let
		// Godot build its own context in the same turn.
		try {
			var AC = window.AudioContext || window.webkitAudioContext;
			if (AC) {
				var probeCtx = new AC();
				var src = probeCtx.createBufferSource();
				src.buffer = probeCtx.createBuffer(1, 1, 22050);
				src.connect(probeCtx.destination);
				src.start(0);
				probeCtx.resume();
			}
		} catch (e) { /* not fatal: the game is playable muted */ }

		veil.classList.add('dissolving');
		engine.start({
			'args': ['--main-pack', pack].concat(CONFIG['args'] || [])
		}).then(function () {
			window.setTimeout(function () { veil.hidden = true; }, 460);
			canvasEl.focus();
		}).catch(function (err) {
			veil.classList.remove('dissolving');
			showFault(err);
		});
	}

	beginBtn.addEventListener('click', begin);
	// Touch first: on iOS, click lags a touch by enough to lose the gesture.
	beginBtn.addEventListener('touchend', function (e) { e.preventDefault(); begin(); }, { passive: false });

	// ---- service worker ----------------------------------------------------
	// Godot's shell calls engine.installServiceWorker(); ours does the
	// registration itself so it can choose the moment.
	var workerReg = null;

	function installWorker() {
		if (!CONFIG['serviceWorker'] || !('serviceWorker' in navigator)) { return; }
		navigator.serviceWorker.register(CONFIG['serviceWorker']).then(function (reg) {
			workerReg = reg;
		}).catch(function (e) {
			note('Offline cache unavailable: ' + e.message, 'note');
		});
	}

	function workerState() {
		if (!('serviceWorker' in navigator)) { return 'unsupported'; }
		if (navigator.serviceWorker.controller) { return 'active'; }
		if (workerReg) { return 'installing'; }
		return 'none';
	}

	// ---- "there is a newer build" -----------------------------------------
	// Fetch index.html and compare it to what we are running. Two signals,
	// because they catch different things: the commit stamp changes on every
	// build, and the content-hashed payload name changes whenever the engine or
	// the pack does. Comparing the *served document* rather than asking the
	// service worker means no false alarm once a reload has already landed us
	// on the newest build.
	//
	// Detection runs whenever; *presentation* does not. A banner that appears
	// mid-corridor is an interruption in a game whose whole business is
	// atmosphere, so it waits for a moment when the player is already out of
	// the fiction: the tap gate, a menu, or the first frame after coming back
	// from the home screen.
	var POLL_MS = 300000;      // background poll while the tab stays open
	var THROTTLE_MS = 20000;   // floor between checks, so tab-flipping cannot spam
	var lastCheck = Date.now();
	var updatePending = false;
	var updateShown = false;
	var atSafePoint = false;

	function presentUpdate(reason) {
		if (!updatePending || updateShown) { return false; }
		if (!(reason === 'background' || !started || atSafePoint)) { return false; }
		updateShown = true;
		updateBtn.hidden = false;
		return true;
	}

	// Called by the game (src/core/diagnostics.gd) when it opens or closes a
	// menu, i.e. when interrupting the player costs nothing.
	window.__itaw_setUpdateGate = function (open) {
		atSafePoint = !!open;
		presentUpdate('gate');
	};

	function isNewer(served) {
		var exe = /"executable"\s*:\s*"([^"]+)"/.exec(served);
		if (exe && exe[1] !== CONFIG['executable']) { return true; }
		var stamp = /window\.ITAW_BUILD\s*=\s*(\{[^}]*\})/.exec(served);
		if (!stamp || !BUILD.commit) { return false; }
		try {
			return JSON.parse(stamp[1]).commit !== BUILD.commit;
		} catch (e) {
			return false;
		}
	}

	function refreshWorker() {
		if (!navigator.serviceWorker || !navigator.serviceWorker.getRegistration) { return; }
		navigator.serviceWorker.getRegistration().then(function (reg) {
			if (reg) { reg.update().catch(function () {}); }
		}).catch(function () {});
	}

	function checkForUpdate(force, reason) {
		var now = Date.now();
		if (updatePending) {
			presentUpdate(reason);
			return Promise.resolve(true);
		}
		if (!force && (document.visibilityState !== 'visible' || now - lastCheck < THROTTLE_MS)) {
			return Promise.resolve(false);
		}
		lastCheck = now;
		refreshWorker();
		// The query string is not decoration. An installed worker treats a bare
		// fetch of index.html as a cacheable file and answers it from its own
		// cache -- which is the very thing we are trying to look past. A URL it
		// does not recognise goes to the network, which is the only answer worth
		// having here.
		return fetch('index.html?u=' + now, { cache: 'reload' }).then(function (res) {
			return res.ok ? res.text() : '';
		}).then(function (text) {
			if (!text || !isNewer(text)) { return false; }
			updatePending = true;
			presentUpdate(reason);
			return true;
		}).catch(function () { return false; });
	}

	var wasHidden = false;
	document.addEventListener('visibilitychange', function () {
		if (document.visibilityState === 'hidden') {
			wasHidden = true;
			suspendGame();
			return;
		}
		var returning = wasHidden;
		wasHidden = false;
		checkForUpdate(false, returning ? 'background' : 'visible');
	});
	window.addEventListener('focus', function () { checkForUpdate(false, 'focus'); });
	window.setInterval(function () { checkForUpdate(false, 'poll'); }, POLL_MS);
	if (navigator.serviceWorker) {
		// A worker taking over mid-session means a deploy landed; confirm it.
		navigator.serviceWorker.addEventListener('controllerchange', function () {
			checkForUpdate(true, 'controllerchange');
		});
	}

	updateBtn.addEventListener('click', function () { location.reload(); });
	updateBtn.addEventListener('touchend', function (e) {
		e.preventDefault();
		location.reload();
	}, { passive: false });

	// Used by tools/web/smoke_pwa.js, and useful on a phone when you want to
	// know right now whether the build you are looking at is the current one.
	window.__itaw_checkForUpdate = function (reason) {
		return checkForUpdate(true, reason || 'manual');
	};

	// ---- what the in-game debug overlay cannot see from inside Godot -------
	window.__itaw_env = function () {
		var vp = window.visualViewport;
		return JSON.stringify({
			dpr: devicePixelRatio || 1,
			css_w: Math.round(vp ? vp.width : innerWidth),
			css_h: Math.round(vp ? vp.height : innerHeight),
			safe: safeArea(),
			store: window.__itaw_store.health(),
			worker: workerState(),
			build: stampShort(),
			exe: CONFIG['executable'] || '',
			update: updatePending ? (updateShown ? 'shown' : 'held') : 'none',
			standalone: !!(window.navigator.standalone
				|| (window.matchMedia && matchMedia('(display-mode: standalone)').matches))
		});
	};
}());
