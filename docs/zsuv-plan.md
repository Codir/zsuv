# Zsuv: a new game on Khutir Road's base, for Game Off 2026 (plan)

The owner's brief, 2026-11-13: a new, separate project built on this one, entered in the jam that
is running now (GitHub's Game Off 2026). One map that opens up over time. You build bases and fuel
stations by hauling in resources and fuel. You break up the ground: dig it, and build roads and
bridges to open the map. A scout car carries nothing: you only drive it, to explore. The owner
builds it in a local session.

This file lists **only what changes** from Khutir Road 0.3.0 (commit `9682b06`). Anything it does
not name stays as it is: the driving and the raycast wheels, the five rigs, the hitch, the winch,
the tow, the sound, the PSX look, the tests harness, the CI and the exports. Every number below is
a first guess, to be tuned in playtests. Where this file and the code disagree after a change, the
code and its tests win, and this file is corrected.

**Working title: Zsuv** (Зсув). In Ukrainian the word means a shift, and also a landslide
(*зсув ґрунту*, a "soil shift"). The title is the owner's call (§13).

## 0. The jam: Game Off 2026

- GitHub's annual jam on itch.io: https://itch.io/jam/game-off-2026, announced on
  https://github.blog/open-source/gaming/game-off-2026-the-theme-is-shift/. **Theme: SHIFT.**
- **Deadline: 2026-12-01 13:37 PST (21:37 UTC).** Voting opens after it closes.
- **Two steps are required.** The source must be in a **public GitHub repository**, pushed before
  the deadline, **and** the game must be submitted on the jam's itch.io page. A push to GitHub on
  its own does not enter the game.
- **Any engine, language or library** may be used.
- **Not confirmed, so check it on day 0, before anything else.** Neither page could be read from
  this session, and search did not show the 2026 FAQ. Read the jam's pinned FAQ for three things:
  1. **Pre-jam code.** Is a game built on a team's own project from before November allowed? In
     2025 the host pinned "guidelines on using code/ideas from before the start of the jam". If
     2026 forbids it, this plan does not fit the jam as written, and the owner decides what to do
     before any work starts.
  2. **AI-made work.** Khutir Road was made with an AI agent, and the jam's rules on that need
     checking.
  3. **A licence.** Is one required or expected?
- **Disclose the base either way.** The README and the itch page both say: "Built on Khutir Road
  (October 2026): the driving, the trucks, the sound. New for Game Off: …". The commit the fork
  starts from gets the tag `base-khutir-road-0.3.0`, so `git diff base-khutir-road-0.3.0..main`
  shows exactly what was made during the jam (§2).
- **Judging.** 2025 judged gameplay, graphics, audio, innovation and theme interpretation, and the
  2026 criteria were not found. The theme has to show in the first minute of play and on the
  itch page.

## 1. SHIFT, and what the player does

**The pitch.** It is spring after the floods. Landslides have *shifted* the hillsides onto the
roads, the river took the bridge, and the villages up the valley are cut off. You are the road
crew: scout the valley, dig through the slides, haul gravel, timber, concrete and fuel, and build
outposts, fuel stations, roads and bridges until the valley is open again. You shift the land
back: every cubic metre you dig is carried somewhere and dumped. The HUD counts the m³ shifted,
and the end card shows the total.

This uses the theme three ways. *Zsuv* means both shift and landslide, you move earth, and the
gearbox already has its shifts (low range, G).

**The first ten minutes** carry the jam score, because most voters play for 5-15 minutes:

1. You start at the base camp in the scout. The paper map (M) is blank paper except for the
   ground around the camp. You drive out, and the map draws itself as you go. You find the
   quarry, the river with its bridge gone, and the north road buried under a landslide.
2. Back at the camp, the garage (Tab) gives you the tractor and its tipper. At the landslide,
   hold **B**: the tractor's front bucket bites into the slide and fills the tipper. You drive off
   the road, hold **V** to tip, and the heap pours out behind. A few loads later, the road is
   through.
3. Over the ridge the map opens: a forestry, a khutir, and the stakes of an outpost to build.

**The whole arc** is about 45-60 minutes. Four regions are opened by five barriers. Sites are
built from four resources. The game ends when the mountain village is reached and supplied, then
play goes on.

## 2. The fork: a separate project

The owner's local session does this first, in this order:

1. **A new public GitHub repository** (owner's account, name as the title, e.g. `zsuv`). Its
   history starts from Khutir Road's: push this repository's `main` there as `main`, then tag
   `base-khutir-road-0.3.0` on that commit. The history keeps the October dates, so it shows what
   came before the jam.
2. **Rename everything that names Khutir Road:**
   - `project.godot`: `config/name`, `config/description`, and `config/version="0.1.0"`.
   - `export_presets.cfg`: the `KhutirRoad.*` export paths, `product_name`, `file_description`,
     and `bundle_identifier` (`com.codirs.zsuv`).
   - `.github/workflows/godot.yml`: the `KhutirRoad*` file and artifact names, and the
     `ITCH_TARGET` default (`codirs/zsuv`, a new itch.io page; the `BUTLER_API_KEY` secret is set
     again in the new repository).
   - `godot.sh`: the header line and the export paths.
   - `Profile.PATH` (`user://zsuv.cfg`), so the two games never share a save in the browser.
3. **Reset the docs:**
   - `README.md` gets rewritten for the new game, with the disclosure from §0.
   - `CHANGELOG.md` starts at 0.1.0.
   - `media/` loses Khutir Road's trailer, GIF, screenshots and devlogs.
   - `media/itch-page.md` gets new copy, and `media/comments.md` gets new Sources: the game's page
     and the Game Off 2026 rate page.
   - The two skills (`release-itch`, `player-comments`) get the new name, page and target.
   - Keep `docs/sound.md` and `docs/trucks.md`. Replace `docs/valleys.md` with this file, moved to
     `docs/plan.md`.
4. **An itch.io page** for the new game: HTML kind, "played in the browser", viewport 960x540,
   kept as a draft until the first build. Most jam voters play in the browser, so **the web build
   is the one that has to work**.

## 3. One map that opens

### Size and shape

- **One map, 512 m square** (Khutir Road's valleys are 256 m), from -256 to 256 on x and z. North
  is -z, the top of the paper map. It has four regions of about 256 m each, split by real
  landscape, not invisible walls. The boundary walls and the rim stay at the map's edge only.
- **What goes:** the five valleys, the valleys screen, buying valleys, and picking a sky.
  `Valley.all()` becomes the one map, `Valley.zsuv()`. The `Valley` class stays as the map's data,
  so `Terrain`, `WorldBuilder` and the tests keep their shape. The five valleys' place builders
  (`_build_sawmill`, `_build_forestry`, `_build_koliba`…) stay, reused for the new map's places.
- **Weather and season:** spring after the floods, an overcast morning, mud in the lows and snow
  above about 25 m only (`layer_from`, as Zakarpattia has it). One sky, `Weather` as it is.

```
 -z (north)
 +-----------------------------+-----------------------------+
 | NW  THE FOREST SIDE         | NE  THE HIGH VILLAGE (end)  |
 |  forestry (timber)          |  mountain village           |
 |  khutir                     |  weather station            |
 |  outpost site O1 + pump ===ravine G1===> (fill or bridge) |
 |  gravel road site R1 (bog)  |          ^ landslide L2     |
 |~~ hillside: landslide L1 ~~~|~~~~~~~~ steep slope ~~~~~~~~|
 +------------------- the river, north to south -------------+
 | SW  BASE CAMP (start)       | SE  ACROSS THE RIVER        |
 |  depot, pump, garage        |  fuel depot (fuel)          |
 |  concrete yard (concrete)   |  village (supply orders)    |
 |  quarry (gravel)  ==bridge site B1==> fuel station F1     |
 +-----------------------------+-----------------------------+
 +z (south)
```

### The barriers, and what opens each

| Barrier | Between | What it is | Opened by |
|---|---|---|---|
| L1, landslide | SW to NW | a mound over the north road, ~3 m high, ~16 m along it, ~40 m³ | digging it out (tractor) |
| B1, river bridge | SW to SE | the river in a wide bed, too deep to drive, its bridge gone | concrete ×2, timber ×2, gravel ×1 |
| R1, washed-out road | in NW | ~60 m of deep mud between the landslide and the outpost site, where a loaded pickup bogs | a gravel road (§5): about 2 loads spread |
| G1, ravine | NW to NE | the river's upper course, ~10 m wide, ~5 m deep, steep sides | filling it (~80 m³ of soil, dug from its own banks) **or** a timber bridge (timber ×2, gravel ×1): the player's choice |
| L2, landslide | SE to NE | a bigger slide on the switchbacks, ~90 m³ | digging it out |

**The critical path needs only the starting rigs:** L1 dug out, R1 gravelled, outpost O1 built,
G1 filled, and the village. The river bridge, SE and L2 are the faster, richer route for players
who buy the 6x6 and the semi.

### What the terrain needs (`scripts/world/terrain.gd`)

- **The map's size comes from its data.** Terrain's `SIZE`/`HALF`/`N` constants become values read
  from `valley.size`. Every place that reads them has to change:
  - `map_screen.gd` (`_to_map`, `_render_image`).
  - `world_builder.gd`: the ±118 m tree scatter and the walls at ±127.
  - `main.gd`: the map edge in `_parking`.
  - Terrain's rim: `smoothstep(100, 126)` becomes `HALF - 28` to `HALF - 2`.
  - The tests: `test_terrain_shape`, `test_world`, `test_garage`.
- **Two new ground features in `base_height`/`generate`:**
  - **`river`**: a gully with a flat water plane at its bottom. Past 0.8 m of water the engine
    floods and dies, as on an empty tank, and T tows. It needs no new water physics.
  - **`slide`**: a mound of loose earth laid over a road after the road's shelf. Its loose layer
    is set in the works image (below), so it is soft until dug.
  - A road can also have **gap spans** (a bridge site): no shelf is cut there, so the ground
    keeps its ravine or riverbed until a bridge stands over it.
- **The ground can change after it is built.** Add `Terrain.set_heights(rect, values)` (or a brush
  call). It writes `heights`, marks the touched 32 m chunks dirty, and once per frame at most:
  - rebuilds the **collision of those chunks only**: collision becomes one `HeightMapShape3D` per
    32 m chunk (33x33, edges shared), all under the one `body`, so queries that exclude
    `terrain.body` still work;
  - updates the **height texture** the two shaders read, at most 10 times a second, as the ruts'
    texture is now. A 513x513 RF update is 1 MB. If the web build stutters while digging, split
    it into four 257x257 textures, one per region.
  - re-renders the touched rectangle of the **paper map's** image.
- **A works image** (new, RGBA8, 0.5 m per pixel like the ruts):
  - R: loose earth (dug, dumped or slid): soft, with more drag and less grip, like snow 0.3 m
    deep. It **packs down under wheels through the existing compaction**, firm after about three
    passes.
  - G: gravel spread: firm, road grip.
  - B: exposed earth, for the look.
  - The snow shader gets its colours: fresh brown earth, grey gravel.
- **The surface under a wheel on a structure.** `Chassis._update_suspension` samples
  `terrain.sample(hit)` whatever the ray hit, so a wheel on a bridge deck would feel the river's
  mud. The surface must come from the terrain only when `hit.collider` is the terrain body.
  Otherwise it is a firm road surface (grip 1, rolling 0.015).
- **Build time.** Khutir Road's 256 m map builds in 0.4-0.7 s native, 3-5 times that in a
  browser, and 4 times the area costs about 4 times that. **Target: 8 s or less in the web build**,
  measured on day 2. If it is slower:
  1. Look up places' flats through a grid, as roads already are. Each metre of ground now loops
     over every flat.
  2. Failing that, **bake** the generated heights and ground images at export: `./godot.sh bake`
     writes them into `res://map/`, and the game loads them.
- **The map's version.** Earthworks are saved as changes to the generated map (§10). Any change
  to the generator moves `MAP_VERSION`. A save from another version drops its earthworks and
  says so in a message.

### Fog: the map draws itself

- **A fog mask**, 4 m per texel (128x128), kept in the profile. Every vehicle uncovers the map
  around it as it drives:

  | What reveals | Radius |
  |---|---|
  | The scout | 90 m, up to 150 m when it stands 15 m or more above the ground within 60 m (on a hilltop) |
  | Any other truck | 40 m |
  | A built base or fuel station | 80 m around it |

- **The paper map (M):** fogged paper is drawn blank with a pencil hatch, the revealed part as
  today. The whole map at 0.47 px/m fits the 240 px map. The mouse wheel or **Z** zooms to 256 m
  about the truck, so marks stay readable at 480x270.
- **Discovery.** A place, source or site whose centre comes into the revealed area is *found*:
  - a message ("Found: Quarry");
  - its marker pole in the world;
  - its mark on the map, plus its needs for a site;
  - its line on the board.

  Nothing unfound is shown anywhere.
- **The scout's track.** The trail the map already draws behind the truck (`_trail`) is kept for
  the scout, saved, and drawn as a dashed line in its own colour. The heavy rigs **follow** it on
  the map: the scout finds the way through, the haulers take it.

## 4. Earthworks: shifting the land

The core of the theme, and the first thing to make fun.

### Who digs

**The tractor gets a front loader**: two arms and a 2.2 m bucket, built from boxes like its body.
The bucket hangs low while B is held and rises when B is let go. It is the only rig that digs (a
dozer blade on the 6x6 is a stretch, §12). Its farm trailer becomes **a tipper**. It already
carries bulk; soil and gravel are bulk loads now.

| Key | Action |
|---|---|
| **B** (hold) | Bucket down. While the tractor creeps forward under 6 km/h, the bucket takes a bite of the ground just ahead every 0.4 s: up to 0.15 m off a 2.2 x 1.0 m patch, rounded at the edges. The soil goes into the hitched tipper (an animation of the bucket swinging back is optional); without the tipper, into the bucket itself (1.5 m³). |
| **B** (tap, bucket full, no tipper) | Drop the bucket's soil just ahead: small fills and ramps. |
| **V** (hold) | Tip the tipper. Its load pours out over about 4 s just behind it. Standing still makes a heap; creeping forward spreads it in a strip, which is how gravel roads are laid (§5). |

**Capacity:** the tipper holds 10 m³, 4000 kg as bulk does today. That is a game scale, not real
soil weight, so a slide is a few loads, not dozens. The HUD shows the load in m³ and the total
m³ shifted.

### Rules for the ground

- **Volume is kept.** What a bite takes off the heights (1 m² cells, so the sum of the drops is
  in m³) is exactly what goes into the load. What is dumped raises the ground by exactly the
  load. The tests hold this to 2% (§11).
- **It slumps.** After every bite or dump, the 9x9 m around it is relaxed. A metre of ground more
  than 0.8 m above its neighbour sheds half the difference downhill, in three passes. Heaps take
  a natural slope, and a cut has no wall the wheels' rays could snag on.
- **Limits:**
  - no deeper than 3 m below the ground as generated;
  - never below a river's water plus 0.3 m;
  - no higher than 6 m above it;
  - nothing on ice;
  - nothing inside a place's or a built site's flat (B says why, and does not dig).
- **What digging and dumping clear:**
  - Trees and rocks within 1.5 m of a bite or a dump go: their MultiMesh instance is scaled to
    zero, their collision shape removed, and the fact saved.
  - The road mark (`snow_img` B) goes where the ground drops or rises by more than 0.3 m.
  - Dug ground shows fresh earth. Dumped ground is loose earth (works R) until packed.
- **The ground wears.** A heavy rig (over 5 t with its load) spinning a wheel (slip) in mud
  churns it: mud (`snow_img` G) at the wheel grows by 0.01 a tick, up to 1. The dirt tracks that
  get the most traffic turn to bog, and gravel does not churn. That makes a gravel road worth
  building. Real ruts in the heights are a stretch (§12).

## 5. Building: sites

### The sites

A **site** is a place on the map with stakes and a sign: what it becomes and what it needs.
Sites are data in the map, as places are:

```gdscript
"o1": {"name": "Forest Outpost", "pos": Vector2(...), "radius": 12.0, "site": "outpost",
       "needs": {"parts": 2, "gravel": 2}, "pays": 800}
```

| Site | Needs (units) | Built, it gives |
|---|---|---|
| **Outpost** (base) | parts 2, gravel 2 (+ timber 1 for the far ones) | **a depot**: the board, the garage (any truck owned is driven from here), a pump with a fuel stock, the tow's destination, a spot for trailers. Its pad is levelled when built. |
| **Fuel station** | parts 1, gravel 1, then fuel | **a pump** with a fuel stock |
| **Bridge** | concrete 2, timber 2, gravel 1 (the river); timber 2, gravel 1 (the ravine) | **a deck over the gap span**: a StaticBody3D of boxes (deck, rails, piers or trestles) at the road's level at both ends. The road's gap span becomes passable. |
| **Landslide** | digging, no deliveries | the road under it is clear: done when 85% of the slide above the road's level in the road's corridor (7 m wide) is gone and the corridor is drivable (below) |
| **Ravine fill** | soil, dumped in | done when the corridor across it is drivable; then its surface becomes a road |
| **Gravel road** | gravel, spread (V) | done when 90% of its staked corridor is covered. Then the corridor is **graded**: its profile is smoothed the way `_profile` smooths a road (14 m, 22% at most), it is marked as road, the mud and soft layer go, and it no longer churns. |

**Drivable**, for a landslide, a fill or a road: along the corridor's centre line no metre climbs
more than 0.4 m, and across its width it is level to 0.5 m. The same check as
`test_terrain_shape.gd`, run on the live heights. A road site whose corridor is too steep says
where ("Too steep 40 m along: dig or fill there first"). That is where earthworks come into road
building.

### Delivering

- **A unit** is one load of a resource, so a site's needs are counted in loads. The bigger rigs
  carry more per trip (§6).
- **E at a site**, stopped with a load it needs, unloads it into the site's stock (a load in a
  trailer comes off only with the trailer hitched, as today). Each unit pays $100 times the
  site's pay. When every need is met, the site is **built on the spot**: the stakes go, the
  structure stands, the site pays its `pays`, and a message says what it opened. A short dust
  puff is a nice extra.
- **Sites accept any load they need**, whoever's it is. A load is not bound to a site; the map
  shows every site's needs.

### More than one base

Khutir Road has one depot: `Contracts._depot`, `spawn_pos`, and `main.gd` parking the trailers
about the spawn. Here the base camp is the first base and each outpost built is another.

- `_near(_depot)` becomes "near any built base". The board and the garage say which base they are
  at.
- **T (tow)** takes the truck to the **nearest built base**: $100 plus $1 per 20 m.
- **The garage** puts the truck at the base it is opened at, with its trailers parked about that
  base's spawn. `_parking` already works about a spawn. The trailers a player owns stay where they
  were left; the tow brings a trailer to the base it tows to.

## 6. Resources, sources and the board

| Resource | Where it is loaded (E at the source, stopped) | Rig and load kind | Units a trip |
|---|---|---|---|
| Gravel | the quarry (SW) | tractor + tipper (bulk) | 1 |
| Soil | anywhere, dug (§4) | tractor + tipper (bulk) | n/a: m³ |
| Parts (tools, panels) | the base camp, any outpost | pickup (plain); pickup + trailer (double) | 1; 2 |
| Fuel (barrels) | the base camp, the fuel depot (SE) | pickup (plain); pickup + trailer (double) | 1 = 400 L; 2 |
| Concrete (blocks, rings) | the concrete yard at the base camp | 6x6 (heavy) | 1 |
| Timber (logs, beams) | the forestry (NW) | 6x6 (on its bed, 3500 kg); semi (long) | 1; 2 |

Loading is free. A source is a place with `gives` in the map's data, built by its own
`_build_<kind>`: the quarry is new, and the forestry, the yard and the fuel depot reuse the old
builders.

**Fuel is a stock.**
- The base camp's pump never runs dry.
- An outpost's pump and a fuel station start empty. Each fuel unit delivered adds 400 L.
- **E at a pump**, stopped, fills the tank from the stock. With an empty stock, it says "Dry:
  bring fuel".
- The heavy rigs burn a lot (the 6x6 1.8 times), so the far regions need their pumps stocked.
  That is the "заправка" in the brief.

**The board** (E at a base) shows two lists:
- **Supply orders** are Khutir Road's jobs as they are (plain, double, heavy, bulk, long),
  offered only to places found in a region already opened, i.e. one whose barrier on the way
  from this base is done. Reconnecting a village opens its orders, and they are the steady
  income.
- **Sites** lists each site found, with its stock against its needs ("Forest Outpost: parts 1/2,
  gravel 0/2").

**What goes from the jobs:** timed jobs with their medals and records, fragile loads, and stuck
cars with their ditches. They go to keep the scope down, and their tests go with them.

**Prices** (garage, one wallet as today):

| Rig | Price |
|---|---|
| The scout, the pickup, the tractor + tipper | owned from the start |
| The trailer | $400 |
| The 6x6 | $2500 |
| The semi + semi-trailer | $3500 |

The player starts with $300.

## 7. The scout

A new `TruckSpec`, `TruckSpec.scout()`, with a body of its own (`Vehicle._build_scout`):

| | |
|---|---|
| Look | A short two-door 4x4 of the road service, white with an orange stripe, an amber beacon and a light bar on a roof rack, a spare wheel on the tailgate, a whip antenna. Built from boxes like the pickup; no brand. |
| Wheels | 4, radius 0.36 m, 4x4 always (`all_wheel`, no 2WD toggle needed), low range |
| Mass | 1200 kg |
| Top speed | about 65 km/h on the flat, as measured (the pickup does 48) |
| Turns in | about 4.5 m |
| Fuel | 45 L, burns 0.5 times the pickup's |
| Carries | **nothing**: `cargo_mass` empty, `tows` empty, no hitch. The board says "SCOUT: carries nothing" against every order, and a source or a site says so on E. |
| Winch | yes, at the front: it is light and gets itself out |
| Camera | closer (8 m), lower |
| Sound | the pickup's recordings, pitched up (`engine_pitch` about 1.3) |
| Its job | revealing (§3): 90-150 m against 40 m; its track is kept and drawn for the others to follow |

The game starts in the scout. `Profile.truck` defaults to `"scout"`, and the pickup and the
tractor are in the garage.

## 8. Screens, HUD and keys

- **Title screen** (replaces `start_screen.gd`): ZSUV, a still of the valley behind it,
  **Continue** / **New game** (New asks before it wipes a save). `scripts/ui/icons.gd`,
  `scripts/capture/previews.gd` and `./godot.sh previews` go, as do the valleys screen's tests.
- **HUD**, in addition:
  - the m³ shifted;
  - with the tipper, its load ("SOIL 6.4/10 m³");
  - near a site, its needs;
  - near a pump, its stock.
  The three-line hint in the corner becomes: drive, **B** dig / **V** tip with the tractor, **M**
  map.
- **Keys:** B (bucket), V (tip) and Z (map zoom) are new. All are free today and set as physical
  keys in `_setup_input`. The help card (F1) and the README's table get them.
- **The end:** when the mountain village takes its first supply order, an end card shows "The
  valley is open", with the m³ shifted, the metres of road built, the bridges, the time played
  and the money. Esc closes it, and play goes on.
- **All text in English**, as `test_english.gd` holds now. A Ukrainian version is not in scope.

## 9. What stays as it is

The driving model, every rig's spec but the tractor's new loader, the hitch and the trailers'
spots, the winch, R (upright), Esc, the PSX shaders and the dither, the sound and
`./godot.sh soundcheck`, the CI's tests and exports, `godot.sh`, and the controls being physical
keys.

## 10. What is saved (`Profile`, `user://zsuv.cfg`)

As today: the money, the rigs bought, the truck picked. New:

- `map_version`;
- the fog mask (compressed bytes);
- the scout's track;
- per site: its stock and whether it is built;
- per pump: its stock;
- the bases built;
- where each owned trailer stands;
- the trees and rocks gone;
- the stats (m³ shifted, metres of road, time played).

**Earthworks:**
- each changed 32 m chunk's heights minus the generated ones, at 1 cm in 16 bits;
- the works image of that chunk;
- the road marks changed;
- all compressed (DEFLATE: it works in the web build).

A third of the map dug over is still well under 1 MB in IndexedDB.

**When it saves:** on every change but earthworks, as today; earthworks at most every 5 s while
digging, when B or V is let go, and when the window loses focus. **A save loads the generated
map, then lays the earthworks over it.**

Cut: the valleys owned, the skies and the records.

## 11. Tests

The shared world becomes the one map. The harness, the error trap and the watchdog stay, and the
watchdog's time is raised if the bigger map needs it.

**New:**
- `test_map.gd`:
  - The map builds within its budget, with nothing on its roads.
  - Every road open from the start drives both ways in 4x4.
  - Every barrier stops a truck as built (the landslide, the river, the ravine).
  - With every site built by a test hook, every road drives both ways, bridges included, for
    every rig that the map's `no` lists allow.
- `test_earthworks.gd`:
  - A bite lowers the ground by what it puts in the tipper, and a dump raises it by what came
    out, both to 2%.
  - The floor, the ceiling and the flats hold.
  - A wheel's ray meets the new height on the next physics tick.
  - The slump leaves no step over 0.8 m.
  - A tree in the way goes.
  - **The tractor digs L1 out with B and V, and then the pickup drives the north road through.**
- `test_sites.gd`:
  - Each unit delivered counts and pays.
  - A site builds when its needs are met.
  - A built outpost is a depot: board, garage, pump, tow destination, trailers parked there.
  - A pump's stock fills a tank and runs dry.
  - A gravel road is laid by spreading with V, is graded, and does not churn.
  - The ravine fill completes when the corridor is drivable.
  - A bridge carries every rig both ways, with road grip on its deck.
- `test_fog.gd`:
  - Each vehicle reveals its radius, and the scout more on a hill.
  - Places are found once revealed, and not before.
  - The fog and the track survive a save and a load.
- `test_scout.gd`:
  - It drives and turns as specified.
  - It takes no order, no load and no trailer.
  - Its winch pulls it out.
- `test_profile` (in `test_start.gd`'s place): everything in §10 round-trips, and a save from
  another `map_version` drops its earthworks without an error.

**Changed:**
- `test_contracts` loses timed, fragile and stuck.
- `test_garage` checks the parking about every base.
- `test_world`, `test_terrain_shape` and `test_trucks` use the map's size, not 256.
- `test_english` covers the new strings.

**Removed:** `test_valleys.gd`, `test_stuck_car.gd`, and the valleys screen's part of
`test_start.gd`.

## 12. Order of work, to 2026-12-01

The days are the owner's. Every milestone ends with the tests green and a web build that runs.

| When | Milestone |
|---|---|
| Nov 14 (day 0) | Read the jam's FAQ (§0); stop if pre-jam code is not allowed. The fork and the renames (§2), the itch page drafted. The title screen in place of the valleys screen. |
| Nov 15-17 | The 512 m map from data: the size made a variable, chunked collision, rivers, slides, gap spans; the content laid out roughly; web build time measured (≤ 8 s or fix it, §3). The scout's spec and body. Fog and discovery. **Playable: scout the whole map.** |
| Nov 18-21 | Earthworks: `set_heights` with collision, texture and map updates; the loader and the tipper (B, V); volume, slump, limits, trees; the works image; the landslide site. **Playable: dig through L1.** This is the heart of the theme, so give it the time. |
| Nov 22-25 | Sites: stakes, E to deliver, stock, built effects. Outposts as depots (more than one base). Pumps with fuel stock. Gravel road by spreading, and grading. The river bridge and the ravine (fill or bridge). The board's two lists, prices. The end card. Saving all of it. |
| Nov 26-28 | Content and tuning: places, needs and pay along the critical path, playtests from a new save to the end (45-60 min). Wear (churn). Web performance. |
| Nov 29 | **Release 0.1.0** (the `release-itch` skill), the itch page with screenshots and a GIF, **submitted to the jam**. |
| Nov 30 - Dec 1 | Buffer: fixes as 0.1.x. **Nothing new after Nov 30.** The deadline is Dec 1, 13:37 PST. |

**If it is late on Nov 24, cut in this order:**
1. The ground wearing (churn).
2. The SE region and the river bridge (B1 and L2, so the 6x6 and semi go with them).
3. The ravine's timber-bridge choice (keep the fill).
4. Map zoom.
5. Fuel station F1.

**Never cut:** the scout and fog, digging and tipping, one landslide, one outpost with a pump,
one gravel road, the end card.

**Stretch, after the jam:**
- real ruts in the heights from heavy wheels;
- a dozer blade on the 6x6;
- roads the player lays out: the scout drives the line with a key held and leaves stakes, and the
  stakes become a gravel road site;
- leaving trucks out on the map and switching between them;
- a working day, morning to dusk, as a "shift";
- a Ukrainian translation.

## 13. Decisions for the owner

1. **The name.** *Zsuv* is the working title (the Ukrainian for shift and for landslide, which is
   the game). Check itch.io for a clash before the page goes up.
2. **The jam's rules on pre-jam code and AI** (§0), on day 0. They decide whether the plan stands.
3. **The repository:** its name, public (required), and a licence if the jam expects one.
4. **The start:** the scout, pickup and tractor owned, $300 (§6). Or should the tractor be the
   first thing earned?
5. **"Слідувати"** in the brief is read here as *to explore*: the scout reveals the map, and its
   track is kept for the haulers to follow. If it meant a truck that follows you on its own (a
   convoy), that is a separate system and a stretch.
