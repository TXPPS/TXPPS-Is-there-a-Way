# Budgets

Enforced by `tools/ci/check_budgets.py` (size) and measured on device (frame).
A build that breaches a hard budget fails CI.

## Download

| Budget | Limit | P0 actual | Enforced |
|---|---|---|---|
| Total, gzipped | 40 MB | **9.10 MB** | yes, CI |
| Audio, gzipped | 12 MB | 0 MB | yes, CI |
| First load to playable on LTE | 15 s | see below | manual, on device |

P0 breakdown (gzipped):

| File | gz | Note |
|---|---|---|
| `index.<hash>.wasm` | 8.95 MB | the engine. This is the floor; only a custom engine build shrinks it. |
| `index.<hash>.js` | 76 KB | loader |
| `index.<hash>.pck` | 44 KB | all game content so far |
| everything else | ~40 KB | icons, shell, worklets, service worker |

**Headroom: ~30 MB gzipped for all game content across all four acts.** That is
generous, and it is the reason the art direction can be procedural-material-led
rather than texture-atlas-led: shaders cost kilobytes, 1024px textures cost
megabytes.

At 9 MB, a 15 s LTE budget implies roughly 6 Mbit/s sustained. Realistic on LTE,
tight on a bad connection — which is what the service worker is for: the second
launch is local.

## Frame

| Budget | Limit | Enforced |
|---|---|---|
| Frame rate | 60 fps | manual, on device |
| Draw calls | ≤ 120 / frame | manual, P7 automates |
| Visible triangles | ≤ 150 k / frame | manual, P7 automates |
| Texture size | ≤ 1024 px | manual, P2 asserts in the material generator |

P0 actual: 8 draw calls, ~96 triangles. There is a great deal of room, and the
plan is to spend it on shader work and light count rather than on geometry.

## Decisions taken to protect these

- **`display/window/dpi/allow_hidpi=false`.** The phone would otherwise render
  at 3× (2868×1320 instead of 956×440) — nine times the pixels for a game whose
  art direction is grain, dither and darkness. This is the single largest
  frame-time saving available, and it costs nothing this project cares about.
- **Content-hashed payload + `immutable` caching.** Repeat visits pay for
  `index.html` and the service-worker check only.
- **Audio is generated, not stored** wherever a generator is cheaper than a
  `.wav`. The 12 MB audio budget is a ceiling, not a target.
- **VRAM compression is on for both mobile and desktop** in the export preset.
  With no textures yet this costs nothing; revisit in P2 when the material
  generators start emitting real maps, and drop `for_desktop` if size demands it.

## How to re-measure

```sh
GODOT=/path/to/godot bash tools/ci/build_web.sh   # prints the full size table
```

On device: Safari → Develop → Timelines, or the in-game overlay planned for P7.

## Textures — asserted since P2

The ceiling is **1024 px on the longest side**, and `tools/ci/check_budgets.py`
now reads the IHDR of every committed PNG under `assets/` and fails the build on
anything over it. Reading eight bytes beats taking a dependency on an image
library CI would have to install.

The whole game's surface vocabulary is **one 256×256 RGBA tile** (~236 kB
committed, imported lossless with mipmaps and pinned against Godot's
`detect_3d` auto-recompression) plus a 256×16 LUT strip. Six materials share
them. That is the entire texture spend, and it is deliberate: the payload
headroom belongs to geometry and audio, not to pictures of concrete.
