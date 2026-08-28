# Reference shots

Captured by `npm --prefix tools/web run shots`, which drives
`src/render/shot_list.gd` through a fixed list of poses. Fixed poses are the
point: a suite that walks the player around photographs two different walls on
two runs and nothing can be said about a change between them.

**What these are not.** A software rasteriser at 956×440, on a monitor, in a
room with the lights on. They are how the art gets reviewed in a session with
no device, and they cannot answer the questions in `../NEEDS_DEVICE_QA.md`.

| Shot | What to look at |
|---|---|
| `00-first-frame` | Exactly what the player sees when the game starts: panel DP-1, four fuse handles and two breakers, in the torch. The first puzzle is the first thing on screen. |
| `01-hall-west` | The generator hall, dark, from the east end. Scale, and how far the torch reaches. |
| `02-lamp-close` | A bulkhead lamp, unlit, and the concrete around it. |
| `03-across-the-dark` | Twelve metres of nothing, with the generator sets as silhouettes. The navigability question. |
| `04-generator-set` | Flaking marine paint at close range. Chipping should read as neglect, not as camouflage. |
| `05-switchgear-door` | The doorway in the hall's west wall, shut. |
| `06-office-desk` | Three logbooks on a desk, in the order they were filled. |
| `07-stair-head` | The landing and the head of the stair. |
| `08-gallery` | Twenty metres of gallery. Tension or tedium. |
| `09-page-typed` | A printed operating card in the reader. |
| `10-page-pencil` | Emil's logbook. Note the line on the wrong page. |
| `11-lit-hall` | The same hall with the lighting restored — what the first puzzle buys. |
| `12-lit-panel` | The panel lit, so the handles are legible. |
| `13-lit-switchgear` | The switchgear room with its lamp on. |

Shots from index 11 on are taken with every lamp lit (`ShotList.lit_from`).
Act 1 starts dark and its first puzzle is the lighting, so both states are worth
photographing and neither of them is "the game".
