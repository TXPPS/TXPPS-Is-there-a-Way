# Needs device QA

> Everything here is **built, green in CI, and unverified by a human**. CI runs
> headless Godot and a headless Chromium; neither can tell you whether something
> feels right, sounds right, or looks right, and neither is an iPhone.
>
> Numbered so it can be run in one sitting. Report anything that fails by its
> number. A hundred and sixteen items; the Act 4 section (107 onward) is the newest and the
> least examined.

---

## ⚠️ Read this before anything else

**The twin-stick control layer has never run on a real device.** It was written
against a device-QA report, and the only thing that has ever exercised it is a
test suite I wrote in the same pass. The suite is thorough — 96 headless checks
and 43 in a browser at iPhone metrics — but a passing assertion about a number
is not the same as a thumb on glass.

Everything built after it assumes it works. If the sticks are wrong, the
interaction framework, the pause menu and Act 1's puzzles are all standing on
it. **Run section "Controls" first.** If it fails there, stop and say so; the
rest of the list is not worth your time until it is fixed.

Nothing downstream has changed the input layer since. It is frozen: no change
to touch semantics, layout or the router lands without a failing test to justify
it.

---

Open <https://txpps.github.io/TXPPS-Is-there-a-Way/> in Safari, landscape.

Run in order. The build stamp must match the commit at the top of `main` —
check that first, because everything else is meaningless if it does not. CI
already asserts it, so a mismatch means you are looking at a cached page:
append `?fresh=1` and start again.

**Load and shell**
1. Page loads black; title fades up; the hairline rule fills.
2. "TAP TO BEGIN" appears. Tap it — the game starts. (This tap is also what
   unlocks Web Audio for every later phase.)
3. The **top-left stamp** reads `v0.1.0 <sha>` and matches the deployed commit.
4. **Tap the stamp.** A "Build details copied." toast appears; paste it
   somewhere and confirm it names the branch, payload hash and user agent.

**Controls — the point of this round**
5. Two rings, bottom-left and bottom-right. **Neither base may move.** Drag each
   thumb around: only the knob travels, and it stops at the ring.
6. Left thumb walks, in any direction, at a speed that follows how far you push.
7. Right thumb turns. It is a *rate*: hold it deflected and the camera keeps
   turning; let go and it stops dead, with no drift and no glide.
8. **Both thumbs at once.** Walk and turn together, then **lift the left thumb
   while the right one is still turning.** The camera must not stutter, jump or
   change speed. Re-plant the left thumb several times quickly. This is the one
   assertion that matters most; it is what was broken.
9. Start a drag on a stick and pull your thumb right across the screen and off
   the far side. It must keep driving the stick it started on, and must not
   touch the other one.
10. Walking into the crate stops you; you cannot leave the room.
11. Nothing sits under the Dynamic Island or the home indicator, and no control
    is within a slip of the build stamp or the pause button.
12. No rubber-band scroll, no double-tap zoom, no text selection, no page chrome.

**Pause and settings**
13. **Pause button, top right.** Tap it. The world stops, the mix ducks, the
    menu appears.
14. The **Controls** diagram shows two sticks and says what each does.
15. Open **Controls** in the list and switch **Look style** to **Drag**. Resume.
    The right stick is gone and dragging anywhere turns the camera. The diagram
    updates the moment you switch. Switch back.
16. Move **Turn speed**, **Stick size**, **Stick visibility**, **Stick height**
    and **Dead zone**. Resume after each. Every one must apply immediately.
17. **Master** and **Effects** must change the lamp hum while you listen.
18. **Brightness** and **Field of view** must change the scene live.
19. Pause, resume, and confirm **the camera has not moved** and no stick is
    stuck. Pause *while both thumbs are down*, resume, and check the same.
20. Reload the page. Every setting you changed is still set.
21. The stamp at the foot of the menu matches the top-left one; tap it to copy.
22. **Return to Title** asks first, then returns you to the tap gate.

**Interaction — new, and throwaway**
23. Walk to the far wall. A **dial lock** with three wheels. When you are close
    enough, a prompt appears and a round button appears above the right stick.
24. Tap it. The sticks disappear; you are locked to the panel.
25. Drag **up and down on one wheel**. Only that wheel turns, one number per
    pull. Try each of the three.
26. Set **4 1 7**. The indicator goes green.
27. Tap the button again. The sticks come back and the camera is where you left
    it.

**Instrumentation**
28. **Three-finger tap.** The overlay appears top-right. Read out `fps`, `cpu`,
    `draw`, `tris` — this is the only 60 fps measurement that means anything.
29. In the overlay: `safe` must be non-zero (the notch and home indicator),
    `dpr` should read 3, `store` should read `ok`, `sw` should read `active`
    after a reload.
30. Touch the screen with one finger, then two. The `touch` line must list the
    live touch IDs and clear when you lift.
31. **Audio.** Stand next to the lamp: a quiet mains hum. Walk away: it fades.
    In the overlay, `hum on N.NNs` must be **counting up**. Check with the
    silent switch both on and off, and note which one silences it.
32. Three-finger tap again — the overlay closes.

**The update path** (the part that decides whether I can ship you fixes)
33. Load the site, then leave the tab open.
34. Tell me, and I will push a rebuild. Wait for CI to go green. (Or trigger
    one yourself: Actions → build and deploy → **Run workflow** on `main`.)
35. Send the phone to the home screen and come back. A **"New version — tap to
    reload"** banner should appear at the top.
36. It must **not** appear while you are walking around with the tab in the
    foreground. If it does, that is a bug.
37. Tap it. The game reloads and the stamp shows the new commit.
38. **Break it deliberately:** append `?fresh=1` to the URL. The page purges and
    reloads onto the clean URL, and the game still loads. (You should not
    normally need this: a build that cannot load its payload purges itself.)

**Installed PWA**
39. Add to Home Screen. It launches full-screen, black, with the seam icon.
40. After one online run, put the phone in airplane mode and launch it again —
    it should still reach the tap gate.
41. In the overlay, `pwa` should read `true` when launched from the home screen.

**Saving** — new, and the part most likely to behave differently on a real phone
42. Pause. Under **SAVES**, the status line says whether anything is kept and
    whether this browser's storage is temporary. Note exactly what it says.
43. Tap **Save**, then **Resume**, walk somewhere else, pause, tap **Load**.
    You are put back where you saved, pointing where you were pointing.
44. Tap **Export code**. A "Save code copied." toast appears. Paste it into
    Notes and confirm it starts `ITAW.` and is one unbroken block.
45. Walk somewhere else. Pause, tap **Import code**, paste it, confirm. You are
    put back.
46. Tap **Delete save**. It asks first. Confirm the autosave line still says
    "kept" afterwards.
47. **The one that matters:** play for a minute, then send the phone to the home
    screen (do not close the tab). Come back. Reload the page. Tap through the
    gate. Pause: the autosave line must say "kept". This is the path iOS
    actually takes when it discards a backgrounded tab.
48. In the debug overlay, read the `persist` field. `yes` means Safari has
    promised to keep your save; `no` means it will be evicted after about a week
    idle. Report which you got, before and after adding to the home screen.
49. Play for ninety seconds without pausing. A one-time note offers **Share →
    Add to Home Screen**. It must appear once and never again, in this session
    or any later one.

**Rendering** — everything here was tuned by looking at `docs/shots/`, which is
a software rasteriser's idea of the picture, at 956×440, on a monitor
50. Stand under the bulkhead lamp. The panel must read as **sodium**, not as a
    white rectangle. If its centre is white, the emissive is still too hot.
51. Look at the lit wall and follow the falloff into the dark. There must be no
    **banding** — no visible steps or rings. This is the one thing the ordered
    dither exists for, and a phone's display is where it either works or does
    not.
52. Look at the concrete close up, then at two metres, then across the room. Does
    it read as **concrete**, or as noise? There are no normal maps: roughness
    variation is doing all of it, and this is the single most likely thing in
    the render stack to be wrong.
53. Find the **tide mark** — the wall goes darker and smoother about a third of
    the way up. Does it read as a waterline or as a seam in the shading?
54. Look at the painted crate. The chipping should read as **paint lifted off
    primer**, with a hard edge. If it reads as a pattern, the tile is too small.
55. **The dark must be navigable.** Take the phone somewhere genuinely bright —
    outdoors, or a window at noon — and confirm you can still find your way
    across the unlit half of the room. This is the real viewing condition and no
    monitor can stand in for it.
56. **Frame rate.** Three-finger tap and read `fps` while walking. The post pass
    is a fullscreen shader with six texture fetches plus the engine's glow; it
    is the most likely thing to have cost the 60 fps budget. Report the number
    with and without **Reduce motion** on.
57. Turn **Reduce motion** on. The edge distortion must go completely, the grain
    must soften but not vanish, and the falloff must still be smooth.
58. Move **Brightness**. It must change the image immediately and must not wash
    the blacks to grey at the top of its range.

**Audio** — a headless runner has no ears and Chromium's is not a phone speaker
59. Put the phone to your ear at low volume with the tap gate just taken. There
    should be a **bed**: a very low drone, below what the speaker can really
    reproduce, felt rather than heard. On headphones it should be obvious. If
    there is silence, say so — the mixer may be running and producing nothing
    audible, which the suite cannot tell apart.
60. Walk toward the bulkhead lamp. The **ballast hum** should get louder and
    brighter; walking away should make it quieter *and* duller, not just
    quieter. That is distance filtering, and it is the cheapest cue in the game.
61. Stand so the crate is between you and the lamp. **Nothing should change** —
    the crate is too small to occlude. Then walk out of the room's line of sight
    if you can. Occlusion is a ray four times a second; report any *stuttering*
    as the filter opens and closes, which would mean the glide is too fast.
62. **Footsteps.** Walk. One step per stride, not a machine-gun and not silence.
    Walk into a wall: it must go quiet, because nothing is going under you.
63. Move the **Effects** slider while the hum is audible. It must change
    immediately. Then pause: the hum must **duck** and the menu stay clear.
    Resume: it must come all the way back, not most of the way.
64. Listen for the **room tone** — a broad low hiss with a 60 Hz component under
    it. If it sounds like tape hiss rather than a room, say so.
65. **The silent switch.** Check with it on and off, and tell me which one
    silences the game. iOS treats Web Audio differently depending on how the
    context was created and this is the single most likely audio bug on the
    device.
66. Anything that **clicks**, anywhere, especially at the moment a loop wraps
    (every 16 seconds). Every tonal loop is periodic by construction and should
    be seamless; a click means one is not.

**Act 1** — the whole point. It is finishable: `tests/case_act1.gd` walks it end
to end every build. What no test can tell me is whether it is *playable*
67. You start in the generator hall in the dark with a flashlight. **Can you
    see enough to move?** This is the single most likely thing to be wrong, and
    it cannot be judged on a monitor. Try it once indoors and once in daylight.
68. Find the **panel** on the north wall. Read the schedule card on it. Close
    the **MAIN**: it must trip, audibly, and come back open by itself. Nothing
    should be lost by trying it.
69. Pull the **LT-6** fuse and close the main again. Lights, everywhere except
    the stair tower — because that is the circuit you pulled.
70. Open the **bus main**. The switchgear door opens, and the lighting stays on:
    they are different systems and the panel says so.
71. Go through the east doorway onto the landing and **walk down the stair**.
    The third step is missing; the card taped to the rail says so. You should be
    able to walk over the gap. If you fall, or if you cannot walk down at all,
    that is the ramp under the nosings and it is a real bug.
72. At the bottom: the **watertight door**. Work the last dog — it refuses.
    Find the **wrench on its hook** beside it, take it, work the dog again.
73. Walk the **gallery**. It is twenty metres and mostly dark; note whether that
    reads as tension or as tedium.
74. At the far end, the sign says **RING FOR ADMITTANCE**. Ring it. Eleven
    seconds. Tell me what those eleven seconds felt like — that is the act's
    last beat and the thing I most need a human on.
75. Read all seven documents. Any that are hard to read on the device, or whose
    line breaks are wrong, say which.
76. Walk through the shelter door. The world fades and a card says **End of
    Act One**. Putting the card down now puts you in the **shelter vestibule**,
    facing north up a corridor — Act 2 begins there.
77. **Pause mid-act and reload the page.** The autosave fires on checkpoints and
    on the tab going away; the breakers, the doors and the wrench must all come
    back as you left them.

**Act 2 — the shelter.** Three gates that are one system, plus one scene.
`tests/case_act2.gd` walks all of it, including the wrong answer.

78. You arrive in the vestibule in the dark. Two notices on the walls: the 1962
    stocking manifest and the 1964 occupancy notice taped over the capacity
    sign. Read both — the second is the first time the programme is named.
79. Walk north up the corridor. **Is the corridor lamp too bright at arm's
    length?** In the captures it clips to white a metre away. That is the one
    thing in Act 2 I could not judge without a phone in a dark room, and it is
    the difference between "a bare lamp is dazzling, which is true" and "the
    fitting is broken".
80. Find the **plant room** on the west side. Press **START**. It cranks and
    does not fire, and it should sound like an engine turning over willingly
    rather than a machine refusing. That sound *is* the puzzle.
81. Read the **service card** in its frame on the wall. Forty-seven monthly
    entries, every one ending `DAY TANK ISOL`. Say whether that lands as an
    answer or as wallpaper — it is the only place the solution exists.
82. Open the **day tank isolating valve**: three turns of the handwheel. Say
    whether three is right, or tedious, or too few to register.
83. Press **START** again. It catches and runs. **Does the running loop have an
    audible seam?** It is sixteen seconds long and every frequency in it is a
    multiple of 1/16 Hz, so it should not — but a click at the loop point is
    the loudest thing in a room this quiet.
84. Close the **SET MAIN**. Nothing happens, because the transfer switch is in
    `TEST`. Read the operating card taped inside the cabinet door, then move the
    switch to `EMERGENCY`.
85. The bus picks up, the lights come on — **and about four seconds later it
    trips**, audibly, and the set main flips open. Nothing is lost.
86. Go to **panel DP-2** in the corridor. Read the schedule in the door. Open
    the **UNIT HEATER** breaker (9 kW, the biggest single load) and close the
    set main again. It holds.
87. **Wait.** After about nine seconds the sump's float calls for it, the start
    surge takes the bus down again, and the trip message is different from the
    first one. **This is the act's best moment and I have never seen it happen
    on a device.** Tell me whether it reads as your own miscalculation or as
    the game being unfair — it is meant to be the former.
88. Shed more (the galley is 5.2 kW; there are 73 allocations that work) and
    close the main. It rides the sump start, the sump runs, and the stair at the
    north end drains.
89. Somewhere in here — twenty-four seconds after the bus first came up — the
    **intercom** in the mess speaks. Four lines, as subtitles. Were you in a
    position to notice? Did it land as somebody talking to you, or as a tooltip?
90. Try shedding **SHELTER LIGHTING** while you are at the panel. You should
    end up in the dark with a flashlight and a live bus. That is the act's
    lesson working: light is finite and you chose where it went.
91. The **bunk room**: one bunk made, one stripped. The **store room**: cartons
    rotated front to back. The **mess**: one place set. None of it is remarked
    on. Did any of it register before the intercom spoke?
92. Walk to the **stair head**. The annex door is open. Going through it ends
    the act — and somewhere on the way back down the corridor, **once**, there
    is a vertical seam of light on a wall where there is no gap. No sound, no
    consequence. **Did you see it?** A "no" is a useful answer.
93. **Reload mid-act.** The valve, the switch, every breaker and whether the
    sump has run must all come back. So must the act itself: you should reload
    into the shelter, not the powerhouse.
94. Read all six Act 2 documents plus the operating card and the panel
    schedule. Same question as before: any line breaks wrong on the device?

**Act 3 — the annex.** Behind the annex door, in the same scene, because P3.3
sends you back to Act 2's panel. `tests/case_act3.gd` walks all of it.

95. Go through the annex door. **The colour changes as you walk through it** —
    sodium behind you, fluorescent green-white ahead. That shift is the marker
    that you have left the dam and entered the programme, and it is the single
    thing in Act 3 I most want a human opinion on. Does it land, or does it just
    look like a different room?
96. The tubes **flicker**. Is it a tired fitting or a broken shader? It is meant
    to be a tube failing to strike and recovering, not noise on the brightness.
97. Read **Protocol 4** at the observer station. It is four lines and one of
    them is the entity's whole behaviour. Say whether 4.2 registers as a rule
    or as flavour — a player is meant to be able to state it in one sentence.
98. Chamber B's lamp is **warm** in a green building, because a 1964 dimmer-
    driven 150 W fitting is an incandescent one. Does that read as deliberate?
99. The **interlock** will not release chamber B's key while the lamp is on.
    Read Emil's cam notes, work the **timeclock**, get the key. **Is the cam
    relationship findable?** Tooth n covers hours 2n and 2n+1, it is written
    once, in his handwriting, with a worked example. This is the puzzle most
    likely to be too hard, and I cannot judge it.
100. Take the **photometer** from chamber B. Hold it up under a fitting and in
    the dark. Numbers on its face, not on the HUD. Is it readable at arm's
    length on a phone?
101. **Point it at the entity.** When something is between you and a lamp the
    reading drops, and the drop is the same number every time. Did you ever get
    the chance? Did you understand what you were looking at?
102. Open the **tank drain**. It trips the set, because starting the sump
    against head needs more than you have left. Go back to DP-2, shed something
    real, come back. **What did you choose to put out, and why?** That answer is
    the whole of Act 3 and there is no wrong one.
103. With the annex bank off, the entity has no line to walk. **Was being blind
    and safe better or worse than being lit and watched?**
104. The **tape library**: work out which reel is Run 9 from the index and the
    admission sheet. Wrong reels cost nothing. **Was the deduction fair, or did
    you end up pulling reels at random?**
105. Taking **RF-0840** ends what is built. The card says so plainly.
106. **Reload in the annex.** The clock's wheels, the key, the drain, the tank,
    and whether the reel is gone must all come back.

**Act 4 — the gate.** Back in Act 1's building, up the pier stair from the
gallery. `tests/case_act4.gd` walks it both ways.

107. Taking the reel puts you back in the **gallery**, facing a doorway that has
    been in that wall the whole time. Did you notice it in Act 1? A "no" is the
    right answer and I want to know if it is also a *fair* one.
108. On the gallery's east wall: the **1954 relay panel**, a stage gauge reading
    **30.5 ft**, and a lamp that says SEQ HELD. The sequence card you could read
    in minute four says it holds above 30.0. **Does the penny drop?**
109. Beside it, on a shelf, a **homemade box**. Read its label. It is in the
    same handwriting as WATCH THE THIRD STEP, four hours earlier, which you
    read as somebody's kindness. **This is the moment the game turns, and it is
    nine words on masking tape.** Tell me whether it landed or went past you.
110. Pull the lead. The gauge falls to **21.4 ft** — which is what the pool has
    read every year since 1994. Nothing opens. **Is it clear why not?** A latch
    that has stopped being fed a reason to hold is still latched.
111. Climb the **pier stair** out of the gallery. It is 4.5 m of grating in one
    flight. Is the climb tedious, or does the height register?
112. In the **control house**: the desk, the interlock cabinet, and a reset
    button that will not do anything. The cabinet holds the key and will not
    give it up, because Protocol 4.4 says a run is not concluded until the
    observer leaves the lamp — and he has not. **You read that in Act 3 and did
    not know it was about you.**
113. **The two endings.** Both are things you do with equipment. Conclude the
    run — stand at the lamp and let the seam close over you. Or refuse: walk out
    to the pier and take the gate off its permissive by hand.
114. Whichever you took: **was it a choice, or did you find one and stop
    looking?** The game must not appear to prefer either, and I cannot tell from
    here whether it does.
115. Read **Reel 9-C** in the control house. It is the title, and the only
    document in the game quoted in full. The silence in the middle of it is a
    man keeping a rule, not the tape failing. **Does that read?**

**Errors**
116. If anything at all goes wrong, a toast should say what. If something goes
    wrong **silently**, that is itself the bug worth reporting.
