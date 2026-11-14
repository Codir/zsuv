# itch.io page copy

A draft until the first build (plan §2). The page stays unpublished until then.

**Title:** Zsuv

**Short description / tagline:** Shift the land, reopen the valley.

**Cover:** `media/cover.png` (630x500: the tractor's bucket at the washout) · **GIF for the
description:** `media/zsuv.gif` (480x270: the bucket, the tipper, the river bridge, the swamp) ·
**Trailer:** `media/trailer/zsuv-trailer.mp4` (55 s, 1920x1080, upload it to YouTube for the page's
video link) · **Screenshots** (1920x1080, in this order), `media/screenshots/`:
01-scout-over-the-steppe, 02-the-map-draws-itself, 03-the-bucket-bites, 04-filling-the-washout,
05-placing-a-fuel-station, 06-the-mixer-countdown, 07-the-river-bridge, 08-the-winch-aimed,
09-the-swamp-water, 10-the-upper-village-at-night. All made by `./godot.sh capture` and
`tools/make_media.py`.

**Classification:** Game · **Release status:** In development · **Genre:** Simulation ·
**Tags:** driving, off-road, psx, low-poly, truck, building, terrain, exploration, physics, game-off

**AI generation disclosure:** Yes: Graphics, Text & Dialog, Code (no Sounds: they are CC0
recordings by people, `docs/sound.md`). The jam's submission form asks the same.

**Browser build:** kind of project "HTML", the `html5` channel upload marked "This file will be
played in the browser", viewport 960 x 540 (the game scales to any size), "Fullscreen button" on.

**Jam:** submitted to Game Off 2026 (https://itch.io/jam/game-off-2026) with the repository's URL.

---

## Description

Spring after the floods. The land has shifted, and the road to the upper village is gone.

**Zsuv** (*зсув*: Ukrainian for a shift, and for a landslide) is a PSX-style off-road building
game. You are the road crew sent from the railhead to get a road through to a village cut off in
the mountains. Nobody knows what the land between looks like now. You find out by driving it.

- **Scout it.** A light 4x4 carries nothing and goes anywhere, and the paper map draws itself
  behind it.
- **Shift it.** Dig through landslides with the tractor's bucket, fill the washouts, level a spot,
  spread gravel into a road.
- **Fuel is the frontier.** A tank lasts a couple of kilometres, so you build fuel stations out
  there, and keep them full.
- **Build where you choose:** a sawmill in a forest on the way, a quarry on a gravel bed, a
  concrete plant, an outpost with a garage. Concrete sets in its mixer in five minutes, so plan
  the road.
- **Bridge the river and the gorge,** cross a bog that floods the engine, and climb a pass in a
  blizzard.
- **The trucks stay where you leave them:** step from one to another, winch one out with
  another, and aim the winch with the mouse.
- Five biomes of Ukraine on one map: the steppe, a snowy pine forest, the Polissia swamp, the
  Carpathian foothills and the pass.
- 480x270, wobbly vertices, dithering and fog, like it fell out of 1998.

Built on my earlier game Khutir Road (October 2026): the driving, the trucks and the sound come
from it. Everything else was made for Game Off 2026. The source is on GitHub.
