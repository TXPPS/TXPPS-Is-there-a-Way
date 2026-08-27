# Needs device QA

> Everything here is **built, green in CI, and unverified by a human**. CI runs
> headless Godot and a headless Chromium; neither can tell you whether something
> feels right, sounds right, or looks right, and neither is an iPhone.
>
> Numbered so it can be run in one sitting. Report anything that fails by its
> number.

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

**Errors**
59. If anything at all goes wrong, a toast should say what. If something goes
    wrong **silently**, that is itself the bug worth reporting.
