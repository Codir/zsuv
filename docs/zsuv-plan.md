# Zsuv: a new game on Khutir Road's base, for Game Off 2026 (plan)

The owner's brief, 2026-11-13: a new, separate project built on this one, entered in the jam that
is running now (GitHub's Game Off 2026). One map that opens up over time. You build bases and fuel
stations by hauling in resources and fuel. You break up the ground: dig it, and build roads and
bridges to open the map. A scout car carries nothing: you only drive it, to explore. The owner
builds it in a local session. After reading the first draft, the owner asked for more of the
off-road genre: the engine flooding in water, the interactions between trucks, and a winch aimed
with the mouse (§8). After the second draft: hauling for money between fixed points is not the
game. Fuel runs out, so you cannot go just anywhere; you build fuel stations, and for them you
bring concrete in a mixer, timber and the rest. The player decides what is needed where, and
builds production too: a sawmill in a forest on the way, so timber does not come from far.
Nobody knows what is out there until they drive to it, and a goal pulls them on (§1, §5, §6).

This file lists **only what changes** from Khutir Road 0.3.0 (commit `9682b06`). Anything it does
not name stays as it is: the raycast wheels and the tyres on snow, mud and ice, the five rigs,
the hitch, the winch's pull, the sound, the PSX look, the tests harness, the CI and the exports. Every number below is
a first guess, to be tuned in playtests. Where this file and the code disagree after a change, the
code and its tests win, and this file is corrected.

**Working title: Zsuv** (Зсув). In Ukrainian the word means a shift, and also a landslide
(*зсув ґрунту*, a "soil shift"). The title is the owner's call (§14).

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
roads, the river took the bridges, and the upper village at the far end of the valley is cut off.
You are the road crew sent from the railhead: get a road through to the village. Nobody knows
what the valley looks like now. You find out by driving it.

**The goal** is set in the first minute. The upper village calls on the radio. Its rough place is
marked on the paper map ("about here"), and the HUD's arrow points at it. To finish, a truck brings
the village what it asks for (fuel 800 L and parts 2) along a road you made passable. Smaller
things pull you along the way:
- radio masts that show the land around them once repaired;
- ruins worth rebuilding;
- trucks left in the floods, to bring back to life;
- the village's calls as you get nearer.

**The limit is fuel, not money.** There is no money in this game. A tank lasts a couple of
kilometres, and past that you need a fuel station out there, with fuel in it.
- A fuel station needs concrete. Concrete is mixed at a concrete plant and sets in its mixer in
  5 minutes.
- The ravine's bridge needs timber, and the timber is far. So you build a sawmill in a forest on
  the way, keep it in fuel, and haul its timber from there.
- **What to build, and where, is the player's call.** The game says what a building needs, never
  where it goes.

**You shift the land to do it.** You dig through the slides, level a spot for a building, fill a
ravine, and spread gravel into a road. The HUD counts the m³ shifted, and the end card shows the
total.

This uses the theme three ways. *Zsuv* means both shift and landslide, you move earth, and the
gearbox gets gears you shift by hand (§8).

**The first ten minutes** carry the jam score, because most voters play for 5-15 minutes:

1. **The village calls.** You start at the railhead in the scout. The paper map (M) is blank paper
   except around the camp and the village's mark. You drive out, and the map draws itself as you
   go: stony ground for a quarry, the river with its bridge gone, the north road buried under a
   landslide. The fuel gauge falls.
2. **The slide.** Back at the camp, the tractor and its tipper stand by the garage: **E** beside it
   and you step across, leaving the scout parked. At the landslide, hold **B**: the tractor's front
   bucket bites into the slide and fills the tipper. You drive off the road, hold **V** to tip, and
   the heap pours out behind. A few loads later, the road is through.
3. **The first decision.** Over the ridge are a thick forest, a ruined sawmill, and a 6x6 left in
   the mud with an empty tank. It is too far to work from the railhead on one tank. Where does the
   first fuel station go?

**The whole arc** is about 60 minutes. Four regions are opened by five barriers. You build from
five resources, with production you place yourself. The game ends when the village gets its fuel
and parts, then play goes on.

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
  (`_build_sawmill`, `_build_forestry`, `_build_koliba`…) stay, reused for the ruins, the
  railhead and the village, and for the buildings the player puts up.
- **Weather and season:** spring after the floods, an overcast morning, mud in the lows and snow
  above about 25 m only (`layer_from`, as Zakarpattia has it). One sky, `Weather` as it is.

```
 -z (north)
 +-----------------------------+-----------------------------+
 | NW  THE FOREST SIDE         | NE  THE UPPER VILLAGE (goal)|
 |  thick forest               |  the village                |
 |  a ruined sawmill           |  a gravel deposit           |
 |  a 6x6 left in the mud      |  a radio mast on the ridge  |
 |  a radio mast on a hill ===ravine G1===> (bridge or fill) |
 |  a washed-out road R1 (bog) |          ^ landslide L2     |
 |~~ hillside: landslide L1 ~~~|~~~~~~~~ steep slope ~~~~~~~~|
 +------------------- the river, north to south -------------+
 | SW  THE RAILHEAD (start)    | SE  ACROSS THE RIVER        |
 |  fuel and parts, no end     |  the railway yard: a semi   |
 |  a concrete plant, a garage |  a pine forest              |
 |  a gravel deposit           |  an old fuel depot, 3000 L  |
 |              ==old bridge B1 (gone)==>                    |
 +-----------------------------+-----------------------------+
 +z (south)
```

None of these is built by the game but the railhead. What the player finds is what can be built
on or with: forests, gravel deposits, ruins, crossings (an old bridge's abutments), washed-out
roads, radio masts, and trucks.

### The barriers, and what opens each

| Barrier | Between | What it is | Opened by |
|---|---|---|---|
| L1, landslide | SW to NW | a mound over the north road, ~3 m high, ~16 m along it, ~40 m³ | digging it out (tractor) |
| R1, washed-out road | in NW | ~60 m of deep mud, where a loaded truck bogs | a gravel road (§5): about 2 loads spread |
| G1, ravine | NW to NE | the river's upper course, ~10 m wide, ~5 m deep, steep sides | a timber bridge (timber 3) **or** filling it (~80 m³ of soil, dug from its own banks): the player's choice |
| B1, river crossing | SW to SE | the river in a wide bed, too deep to drive, its bridge gone | a bridge (concrete 2, timber 3), or a 6x6 with a snorkel through the shallows (§8) |
| L2, landslide | SE to NE | a bigger slide on the switchbacks, ~90 m³ | digging it out |

**The critical path** needs only the trucks you start with and the 6x6 you find:
1. dig out L1;
2. put a fuel station in NW and stock it;
3. bring the 6x6 back to life;
4. build a sawmill in the NW forest (or rebuild the old one) and bridge G1 with its timber, or
   fill G1 instead;
5. put a fuel station in NE;
6. deliver to the village.

The river, SE and L2 are optional. They are a richer route, with the semi, a second forest and
the old fuel depot.

### What the terrain needs (`scripts/world/terrain.gd`)

- **The map's size comes from its data.** Terrain's `SIZE`/`HALF`/`N` constants become values read
  from `valley.size`. Every place that reads them has to change:
  - `map_screen.gd` (`_to_map`, `_render_image`).
  - `world_builder.gd`: the ±118 m tree scatter and the walls at ±127.
  - `main.gd`: the map edge in `_parking`.
  - Terrain's rim: `smoothstep(100, 126)` becomes `HALF - 28` to `HALF - 2`.
  - The tests: `test_terrain_shape`, `test_world`, `test_garage`.
- **Two new ground features in `base_height`/`generate`:**
  - **`river`**: a gully with water in it: a level along its course and a current, read by
    `Terrain.water_level(p)`, with a flat water plane drawn at that level. Ponds and flooded lows
    are lakes without ice. What water does to a truck (drag, lift, the current, the engine
    flooding) is in §8.
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
- **The map's version.** Earthworks are saved as changes to the generated map (§11). Any change
  to the generator moves `MAP_VERSION`. A save from another version drops its earthworks and
  says so in a message.

### Fog: the map draws itself

- **A fog mask**, 4 m per texel (128x128), kept in the profile. Every vehicle uncovers the map
  around it as it drives:

  | What reveals | Radius |
  |---|---|
  | The scout | 90 m, up to 150 m when it stands 15 m or more above the ground within 60 m (on a hilltop) |
  | Any other truck | 40 m |
  | Any building of yours | 60 m around it |
  | A radio mast, repaired | 250 m around it |

- **The paper map (M):** fogged paper is drawn blank with a pencil hatch, the revealed part as
  today. The whole map at 0.47 px/m fits the 240 px map. The mouse wheel or **Z** zooms to 256 m
  about the truck, so marks stay readable at 480x270.
- **Discovery.** A thing whose centre comes into the revealed area is *found*: a forest, a
  gravel deposit, a ruin, a crossing, a washed-out road, a radio mast, a truck or the village.
  Finding it gives:
  - a message ("Found: a ruined sawmill");
  - its marker pole in the world;
  - its mark on the map;
  - its line in the map's ledger (§9).

  Nothing unfound is shown anywhere.
- **The scout's track.** The trail the map already draws behind the truck (`_trail`) is kept for
  the scout, saved, and drawn as a dashed line in its own colour. The heavy rigs **follow** it on
  the map: the scout finds the way through, the haulers take it.

## 4. Earthworks: shifting the land

The core of the theme, and the first thing to make fun.

### Who digs

**The tractor gets a front loader**: two arms and a 2.2 m bucket, built from boxes like its body.
The bucket hangs low while B is held and rises when B is let go. It is the only rig that digs (a
dozer blade on the 6x6 is a stretch, §13). Its farm trailer becomes **a tipper**. It already
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
  load. The tests hold this to 2% (§12).
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
  building. Real ruts in the heights are a stretch (§13).
- **Levelling a spot.** A building needs level ground (§5). Where the player wants one on a slope,
  they level it with the bucket first. A building does not flatten its own pad.
- **A quarry digs its own pit.** Each load of gravel it makes takes the same volume off the ground
  inside its footprint, through `set_heights`. The pit is seen growing, and the quarry stops when
  it is 4 m deep.

## 5. Infrastructure, built where the player chooses

### Placing a building

- **P**, stopped, opens the list of what can be built (keys 1-7). The building picked shows its
  footprint, which follows the mouse cursor on the ground within 40 m of the truck. It uses the
  same ray as the winch's aim (§8). The mouse wheel turns it, left click places it, and Esc
  cancels.
- **Green or red.** The footprint is green where the building can go and red where it cannot, with
  the reason:
  - "Not level: 1.4 m. Level it with the bucket (§4)": more than 0.6 m between its highest and
    lowest corner;
  - on a road, in water, on ice, or within 6 m of another building or a found place;
  - what the building needs around it: a sawmill needs 12 trees within 40 m ("Only 5 trees
    here"); a quarry needs a gravel deposit.
- **Placed, it is a site:** stakes and a sign, with its needs in the ledger. Trees and rocks inside
  its footprint go. P beside a site with nothing delivered yet takes it down again.
- **Building it.** E at the site, stopped with a load it needs, unloads that load (a load in a
  trailer comes off only with the trailer hitched, as today). When every need is in, the building
  stands. The stakes go and a message says what it does. A short puff of dust is a nice extra.

### What can be built

| Building | Needs (loads) | Where | Burns | What it does |
|---|---|---|---|---|
| **Fuel station** | concrete 1, parts 1 | level ground | | Holds 2000 L of fuel, brought in with E. E there, stopped, fills a tank from it. With nothing in it, it says "Dry: bring fuel". |
| **Sawmill** | parts 2, timber 1, gravel 1 | level ground, 12 or more trees within 40 m | 30 L a load | Makes timber: a load every 2 minutes while it has fuel and trees. It fells the trees nearest it, and they go from the world and the map. It holds 3 loads. With no trees left in reach it stops ("Felled out"), and the next sawmill goes further on. |
| **Quarry** | parts 1, timber 1 | on a gravel deposit | 20 L a load | Makes gravel: a load every 90 s, digging its pit (§4). It holds 3 loads. |
| **Concrete plant** | parts 2, timber 2, gravel 1 | level ground | 10 L a load | Makes concrete from gravel brought to it (it holds 4), one for one, poured into a mixer under its chute. Concrete sets in 5 minutes, so a plant closer to the work is often worth building. |
| **Outpost** | parts 2, timber 2, concrete 1 | level ground, 20x16 m | | A base (below): a garage, where the tow takes you, a yard that keeps any 6 loads, and a 1000 L tank. |
| **Bridge** | over the ravine: timber 3; over the river: concrete 2, timber 3 | only at a crossing found (an old bridge's abutments) | | A deck over the gap: a StaticBody3D of boxes (deck, rails, piers or trestles) at the road's level at both ends. The road's gap span becomes passable. |
| **Gravel road** | gravel, spread with V | a washed-out stretch found (its corridor staked) | | Done when 90% of the corridor is covered. Then the corridor is **graded**: its profile is smoothed the way `_profile` smooths a road (14 m, 22% at most), it is marked as road, the mud and soft layer go, and it no longer churns. |
| **Ravine fill** | soil, dumped in | at the ravine G1 | | Done when the corridor across it is drivable. Its surface then becomes a road. |
| **Radio mast** (found broken) | parts 1 | as found | | Shows the map 250 m around it. |
| **The upper village** (the goal) | fuel 800 L, parts 2 | as found | | The end card (§9). |

A **landslide** needs no deliveries. It is clear when 85% of the slide above the road's level in
the road's corridor (7 m wide) is gone, and the corridor is drivable.

**Drivable**, for a landslide, a fill or a road: along the corridor's centre line no metre climbs
more than 0.4 m, and across its width it is level to 0.5 m. This is the same check as
`test_terrain_shape.gd`, run on the live heights. A road whose corridor is too steep says where
("Too steep 40 m along: dig or fill there first"). That is where earthworks come into road
building.

### The railhead, ruins and production

- **The railhead** is the one place built from the start. It has:
  - fuel and parts that never run out;
  - a concrete plant, with 2 loads of gravel in it;
  - a garage;
  - 4 loads of timber in its yard, enough for the first buildings.
- **Ruins** found on the map cost less. The old sawmill in NW needs only parts 1 to run again.
  The old fuel depot in SE still holds 3000 L.
- **Production goes on while the player is away.** Buildings work in game time wherever the
  player is, so a sawmill left with fuel fills up. Its timers are saved (§11).
- **The loads' looks** are Khutir Road's, reused: the bulk heaps in the tipper, the logs on a bed
  or the semi-trailer, the crates and barrels on the pickup. A tank on the 6x6's bed and the
  mixer's drum are new.

### More than one base

Khutir Road has one depot: `Contracts._depot`, `spawn_pos`, and `main.gd` parking the trailers
about the spawn. Here the railhead is the first base and each outpost built is another.

- `_near(_depot)` becomes "near any base". The garage says which base it is at.
- **T (tow)** takes the truck being driven, with its trailer, to the **nearest base**. The load on
  the truck is lost; that is what a tow costs.
- **The garage** puts a truck that is in the garage at the base it is opened at, with its trailers
  parked about that base's spawn. `_parking` already works about a spawn. Trucks and trailers out
  on the map stay where they were left (§8).

## 6. Resources: what is hauled, on what

Five resources, plus the soil you dig. Every building's needs are counted in **loads**, except
fuel, which is counted in litres.

| Resource | Comes from | Carried by |
|---|---|---|
| **Fuel** | the railhead (no end), the old fuel depot (SE), any building's tank | pickup: barrels, 400 L, or 800 L with its trailer; 6x6: a tank on its bed, 2000 L |
| **Parts** (nails, pipes, pumps, sheet: the hardware) | the railhead (no end), an outpost's yard | pickup: 1 load, or 2 with its trailer |
| **Gravel** | a quarry, the railhead's first 2 | tractor + tipper: 1 load |
| **Timber** | a sawmill, the railhead's first 4 | tractor + farm trailer: 1 load; 6x6: 1; semi: 3 |
| **Concrete** | a concrete plant | the mixer: 1 load, which sets in 5 minutes (§7) |
| Soil | dug anywhere (§4) | tractor + tipper, in m³ |

- **Loading:** E at a building's yard (or the railhead's), stopped, with a truck that carries that
  resource and has room. One load goes on, and fuel fills to what the truck carries.
- **Unloading:** E at a site that needs the load, or at a building that takes it: fuel into any
  building's tank, gravel into a concrete plant, any load into an outpost's yard (up to 6).
- **Fuel is the frontier.** Today's burn is 0.04 L/s idling, up to 0.45 L/s at full throttle,
  times the truck's burn. A pickup's 80 L goes about 2 km of road, less off it in low range. The
  far corner and back is out of reach on one tank. The buildings burn fuel too (the sawmill, the
  quarry, the plant), so a working sawmill needs fuel brought to it. If the tanks reach too far
  in playtests, raise the burn rather than the map.
- **No money, anywhere.** The job board goes, with all its job kinds and their pay, the medals and
  records, the stuck cars, the wallet and the prices. Things are paid for in loads and fuel
  instead:
  - The garage's repair and addons cost parts from the base's yard.
  - Fetching a truck to a base costs 50 L from the base's tank.
  - The tow costs the load on the truck.

## 7. The trucks: two new, two to find

### The scout

A new `TruckSpec`, `TruckSpec.scout()`, with a body of its own (`Vehicle._build_scout`):

| | |
|---|---|
| Look | A short two-door 4x4 of the road service, white with an orange stripe, an amber beacon and a light bar on a roof rack, a spare wheel on the tailgate, a whip antenna. Built from boxes like the pickup; no brand. |
| Wheels | 4, radius 0.36 m, 4x4 always (`all_wheel`, no 2WD toggle needed), low range |
| Mass | 1200 kg |
| Top speed | about 65 km/h on the flat, as measured (the pickup does 48) |
| Turns in | about 4.5 m |
| Fuel | 45 L, burns 0.5 times the pickup's |
| Carries | **nothing**: `cargo_mass` empty, `tows` empty, no hitch. E at a yard or a site says "The scout carries nothing". |
| Winch | yes, at the front, 20 m: it is light and gets itself out |
| Intake | 0.8 m, 1.6 m with the snorkel (§8): it floods first, so the scout finds the fords, it does not take them |
| Camera | closer (8 m), lower |
| Sound | the pickup's recordings, pitched up (`engine_pitch` about 1.3) |
| Its job | revealing (§3): 90-150 m against 40 m; its track is kept and drawn for the others to follow |

### The mixer

A new `TruckSpec`, `TruckSpec.mixer()`, on the semi truck's chassis and wheels
(`Vehicle._build_mixer`):

| | |
|---|---|
| Look | the semi truck's cab, a drum behind it that turns while it carries concrete, a chute at the back |
| Wheels | 6, 6x4, low range |
| Mass | 9000 kg empty, 6000 kg more loaded |
| Top speed | about 45 km/h |
| Fuel | 200 L, burns 1.6 times |
| Carries | concrete only, 1 load, loaded under a concrete plant's chute |
| Concrete sets | 5 minutes after loading. The HUD counts it down. At zero the load is lost ("The concrete set"). E at a site that needs it pours it. |
| Winch | yes, 24 m |
| Intake | 1.3 m |

### What you start with, what you find

- **At the railhead from the start:** the scout (you are in it), the pickup with its trailer, the
  tractor with its farm trailer (the tipper, with the loader, §4), and the mixer.
  `Profile.truck` defaults to `"scout"`.
- **Out on the map, to be found:**
  - **The 6x6**, left in the mud in NW, with an empty tank and 20% condition.
  - **The semi** with its semi-trailer, at the railway yard in SE (optional).

  A truck found is yours once it runs. Fuel it from barrels (E beside it, §8). If its condition
  is 0, a load of parts beside it (E) brings it to 50%.
- **The garage sells nothing.** Every truck is either there from the start or found.

## 8. From the off-road genre: the trucks' mechanics

The owner, 2026-11-13, after reading this plan: bring over much more of what SnowRunner-style
games have. That means the engine flooding in water, the interactions between trucks and with the
world, and a winch hooked where the player points the mouse, not where the truck picks. These are
the genre's mechanics, built this game's own way. No game's names, interface, maps or art are
copied.

**Khutir Road already has:**
- 4x4 and 2WD, the diff lock, low range, the headlights;
- the winch (to what it picks), trailers on a hitch;
- refuelling, the tow, setting upright;
- the paper map, mud and snow that pack into ruts;
- a garage of rigs.

**What comes over**, in the order it is worth building:

| Mechanic | For the jam? | About |
|---|---|---|
| The winch aimed with the mouse, to trees, rocks, buildings and vehicles | must | 1.5 days |
| Trucks left out on the map, switched between | must | 2-3 days |
| Water: depth, drag, the river's current, the engine flooding, the snorkel | must | 2 days |
| Truck to truck: winching one out with another, refuelling one from barrels, stepping across | must, and cheap once the two above are in | half a day |
| A gearbox shifted by hand (the theme's own word) | should | 1-1.5 days |
| Condition and repair | should | 1 day |
| Addons in the garage: the snorkel (a must, with the water), chains, a long winch | should | 1 day |
| Cranes and loose cargo, logs loaded by hand, things that break (fences, poles), a cab view | after the jam | |

That is 7-10 more days of work on top of §3-§6. The schedule (§13) is rebuilt around it, and
its cut list says what gives way.

### The winch, aimed with the mouse

Today **F** hooks the tree or rock that `Winch._find_candidate` scores best ahead within 16 m, or
the stuck car. The player cannot choose, and it often takes the wrong tree.

- **F starts aiming.** A crosshair follows the mouse. The cursor stays free (not captured), and
  the right button still orbits the camera. A ray from the camera through the cursor finds what
  is under it. It uses `Camera3D.project_ray_origin`/`project_ray_normal` at
  `get_viewport().get_mouse_position()`, which the 480x270 stretch already maps.
  - **A tree, rock, building, bridge or post:** the hook goes there. On a tree it goes 1 m up the
    trunk.
  - **A vehicle** (a parked truck of yours, a trailer): the hook goes on it, at the point under
    the cursor. It is pulled as the stuck car is today, with the pull on both.
  - **The ground, water or sky:** nothing to hook ("Nothing to hook: a tree, a rock or a truck").
- **The preview.** While aiming, a dashed line runs from the winch to the point. The marker is
  **yellow** when it can hook and **red** when it cannot, with the reason:
  - "Too far: 24 m, the cable is 20";
  - "The ground is in the way" (a ray from the winch to the point meets the terrain);
  - "Too close".
- **The keys while aiming:**
  - **Left click** hooks.
  - **F** again, without a click, hooks what the winch would pick by itself, as today. The quick
    way stays for the keyboard, and the old tests keep working.
  - **Esc** cancels the aim. It does not leave the game while aiming.
- **Hooked**, it works as today: **Shift** reels in, **F** unhooks, and the HUD shows the length
  and the pull. The cable runs from the front mount in any direction, even back over the cab.
- **The cable's length is the truck's own** (`TruckSpec.winch_length`, in place of `RANGE`):
  - scout and pickup: 20 m;
  - tractor: 18 m;
  - 6x6, semi and mixer: 24 m;
  - the long winch addon: +10 m and 1.3 times the pull.
- **In the code:**
  - The trees are cylinder shapes in one body, and the ray's `shape` index finds the tree.
    WorldBuilder keeps a shape-to-tree list, so a felled tree's shape goes too (§4). Rocks work
    the same way. Any other StaticBody3D the world builder made counts as a building.
  - `anchor_body: StuckCar` becomes any `RigidBody3D`, with the hook as a point in its frame.
    `hook_point()` becomes `body.global_transform * local`.
  - `Winch.aim(origin, dir)` does what the cursor does, so the tests and the capture director can
    aim without a mouse.

### Trucks out on the map

Today one truck is in play. The garage's "drive" removes it and puts another at the depot
(`main.gd`, `set_truck`).

- **Every truck a player owns stays where it was left.** Its engine is off, its handbrake on, its
  lights off and its trailer hitched. Its load, fuel and condition are its own. More than 80 m
  from the truck being driven it is frozen (`freeze`), and it wakes when the driven truck comes
  near, hits it or hooks it.
- **Switching:**
  - On the paper map (M), click a truck's mark. The camera cuts to it, and you drive it from
    there.
  - **E** beside a parked truck of yours (within 5 m, stopped) steps you across into it. The
    scout drives up to the tractor, and you take the tractor on.
- **The garage** (Tab at a base) drives a truck that is in the garage. A truck out on the map is
  listed as "out at <nearest place>". You can switch to it, or **fetch it to this base** for 50 L
  from the base's tank: it is set down there, as the tow does.
- **The tow (T)** takes the truck being driven, with its trailer, to the nearest base, and its
  load is lost (§5). The others stay put.
- **The load belongs to the truck.** The load and a trailer's load move from `Contracts` (one
  `job`) onto the vehicle and its trailer. Buildings and sites read whichever truck is there.
- Only the truck being driven reveals the fog (§3).

### Water and the engine

The map has the river, ponds and flooded lows (§3). Water is a level over the ground, from the
map's data. `Terrain.water_level(p)` gives the river's level along its course, or a pond's level,
or none.

- **Depth, drag and lift.** Each wheel in water feels drag against its motion, growing with depth
  and speed: driving into the river fast throws you about and slows you hard. The truck's body
  gets lift for the part of it under water, at half its volume's worth. It is not afloat, but it
  is lighter, so it has less grip. Spray comes off the wheels, as in mud.
- **The current.** The river flows, with its direction and speed in the map's data, faster in the
  narrows. It pushes a truck in it downstream, more the deeper it is.
- **The engine floods.** Each truck has an air intake (`TruckSpec.intake`, a point in its frame).
  Its height above the ground:

  | Pickup | Scout | Tractor | 6x6 | Semi | Mixer |
  |---|---|---|---|---|---|
  | 0.9 m | 0.8 m | 1.3 m | 1.5 m | 1.2 m | 1.3 m |

  - Water over the intake for 1 s and the engine dies ("Engine flooded"). The truck cannot drive.
  - It runs again once the intake is out of the water, at the cost of a quarter of its
    condition. It gets out by the winch (which works off the battery) or by the tow.
  - A flooded engine with no condition left starts only after the tow.
- **The snorkel** (an addon, below) lifts the intake to the roof: 2.2 m on the 6x6, 1.6 m on the
  pickup and the scout. With it, a 6x6 can ford the river's shallows downstream if the current
  lets it. That makes a second way into SE besides the bridge, and it is earned.
- **The HUD** shows the depth against the intake while in water ("WATER 0.7 / 0.9 m"), red when
  close. The engine sound stops when it floods, and a splash plays when a truck goes in.

### Truck to truck

Once trucks stay on the map and the winch can take them, four things become possible:

- **Winch one truck out with another.** Park a heavy truck on firm ground, aim at the stuck one
  and reel in.
- **Refuel one truck from another.** A pickup carrying fuel barrels (§6), stopped within 6 m of
  another truck: **E** pours fuel into it until its tank is full or the barrels are empty. A load
  that is partly used holds what is left, and pours that into a fuel station.
- **Step across** from one truck into another (above).
- **Bring a found truck back to life:** fuel it from barrels, and with a load of parts beside it,
  E brings its condition to 50% (§7).

### A gearbox you shift

This is the theme's own word. Today the drive has only two ranges (G), and the gears exist only
for the sound: `truck_audio.gd` shifts through four gears in high and two in low, for the ear.

- **The gears become real.** `Vehicle` owns the gear. Each gear has its top speed (the audio's
  shares of the range's top speed) and pulls with the range's force times how much lower it is
  geared, so first gear pulls hardest. `truck_audio.gd` reads the gear instead of guessing it.
- **Auto** (as today, and the default) shifts up and down by speed, as the sound does now. With
  the wheels spinning in mud it shifts up and loses pull, and that is why manual exists.
- **Manual:** **N** switches to it, and **,** and **.** shift down and up. **G** still picks the
  range. In first gear of low range a truck crawls through what bogs it in auto.
- **With auto, nothing measured changes:** the top speeds and pulls stay as they are, and
  `test_trucks.gd` holds them.
- The HUD shows the gear: "A3", "L1", "M2", "R", "N".

### Condition and repair

- **Every truck has a condition**, 100% when new. It loses some to:
  - hard knocks: 0.4% per m/s² over 38, the same jolt the fragile load measures today;
  - a flooded engine: 25%;
  - rolling over: 10%.
- **Low condition costs power:**
  - under 50%, the engine pulls 0.8 times;
  - under 25%, it pulls 0.6 times and the fuel leaks (0.05 L/s);
  - at 0% it will not run.
- **Repair** is at a base's garage: Tab, then a line "Repair: a load of parts for each 50%",
  taken from the base's yard (at the railhead, parts never run out). The tow does not repair.
- The HUD shows the condition beside the fuel.

### Addons in the garage

Each addon is fitted once per truck, from the garage's list under that truck, for a load of
parts from the base's yard:

| Addon | What it does |
|---|---|
| Snorkel | the intake on the roof (above) |
| Chains | more grip on snow and ice (ice 0.15 → 0.4); a little slower on a road |
| Long winch | +10 m of cable, 1.3 times the pull |

A truck shows the ones it has: a snorkel as a pipe up beside the windscreen, chains drawn on the
tyres.

## 9. Screens, HUD and keys

- **Title screen** (replaces `start_screen.gd`): ZSUV, a still of the valley behind it,
  **Continue** / **New game** (New asks before it wipes a save). `scripts/ui/icons.gd`,
  `scripts/capture/previews.gd` and `./godot.sh previews` go, as do the valleys screen's tests.
- **The board is gone. The map's ledger takes its place.** Beside the paper map is a list of
  every building and site found, one line each, with what it holds, what it needs, its fuel and
  what it is doing ("Sawmill: timber 2/3, 140 L, 31 trees left"). Hovering a mark on the map
  shows its line.
- **Clicking the map:**
  - a truck's mark: you drive that truck (§8);
  - anything else: a waypoint, and the HUD's arrow points there instead of at the village.
    Click the waypoint again to clear it.
- **HUD**, in addition:
  - the m³ shifted;
  - with the tipper, its load ("SOIL 6.4/10 m³");
  - near a building or a site: what it holds, what it needs, and what E does there;
  - in the mixer, the concrete's countdown;
  - the gear ("A3", "L1"), the truck's condition beside the fuel, and the water's depth against
    the intake while in water (§8).
  The three-line hint in the corner becomes: drive, **B** dig / **V** tip with the tractor, **M**
  map.
- **Keys:** these are new, all free today, set as physical keys in `_setup_input`. The help card
  (F1) and the README's table get them.

  | Key | |
  |---|---|
  | B / V | the tractor's bucket / tip the tipper (§4) |
  | P, then 1-7 and left click | place a building; the wheel turns it (§5) |
  | F, then left click | aim the winch, hook what is under the cursor; F again hooks what the winch picks itself (§8) |
  | N | gearbox auto / manual (§8) |
  | , / . | shift down / up in manual (§8) |
  | E beside your parked truck | step across into it; with fuel barrels, refuel it (§8) |
  | M, then click a truck | drive that truck (§8); click anywhere else for a waypoint |
  | Z, or the wheel on the map | zoom the map (§3) |
- **The end:** when the upper village has its fuel and parts, an end card shows "The valley is
  open", with the m³ shifted, the metres of road built, the bridges, the buildings, the trees
  felled, the fuel burnt and the time played. Esc closes it, and play goes on.
- **All text in English**, as `test_english.gd` holds now. A Ukrainian version is not in scope.

## 10. What stays as it is

The driving model (with water, the real gears and condition added, §8), every rig's spec but the
tractor's new loader and the new winch lengths and intakes, the hitch and the trailers' spots, the
winch's pull and reel, R (upright), Esc, the PSX shaders and the dither, the sound and
`./godot.sh soundcheck`, the CI's tests and exports, `godot.sh`, and the controls being physical
keys.

## 11. What is saved (`Profile`, `user://zsuv.cfg`)

Khutir Road's money, rigs bought, valleys, skies and records go. Saved:

- `map_version`;
- **every truck:** found or not; in the garage or out on the map; if out, where it stands, its
  fuel, condition, load, gear mode, whether its engine is flooded, and its trailer if hitched; its
  addons; and which truck is being driven;
- **every building and site:** its kind, where it stands and which way it faces, whether it is
  built, what has been delivered, its stock, its fuel, and its production timer;
- the fog mask (compressed bytes);
- the scout's track and the waypoint;
- where each owned trailer stands, if not hitched;
- the trees and rocks gone, the ones the sawmills felled among them;
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

## 12. Tests

The shared world becomes the one map. The harness, the error trap and the watchdog stay, and the
watchdog's time is raised if the bigger map needs it.

**New:**
- `test_map.gd`:
  - The map builds within its budget, with nothing on its roads.
  - Every road open from the start drives both ways in 4x4.
  - Every barrier stops a truck as built (the landslide, the river, the ravine).
  - With every crossing bridged and every slide cleared by a test hook, every road drives both
    ways, bridges included, for every rig that the map's `no` lists allow.
- `test_earthworks.gd`:
  - A bite lowers the ground by what it puts in the tipper, and a dump raises it by what came
    out, both to 2%.
  - The floor, the ceiling and the flats hold.
  - A wheel's ray meets the new height on the next physics tick.
  - The slump leaves no step over 0.8 m.
  - A tree in the way goes.
  - **The tractor digs L1 out with B and V, and then the pickup drives the north road through.**
- `test_building.gd`:
  - Placing (`place(kind, at, yaw)`, as the cursor does): green on level ground, red with the
    right reason on a slope, a road, water, too near another building, too few trees, or off a
    deposit.
  - Levelled with the bucket, a slope takes a building.
  - Each load delivered counts, and a site builds when its needs are met.
  - A site with nothing delivered can be taken down.
  - A built outpost is a base: garage, tank, the tow's destination, a yard of 6, trailers parked
    there.
  - A gravel road is laid by spreading with V, is graded, and does not churn.
  - The ravine fill completes when the corridor is drivable.
  - A bridge carries every rig both ways, with road grip on its deck.
  - The village takes its fuel and parts, and the end card shows.
- `test_production.gd`:
  - A sawmill with fuel makes a load every 2 minutes, fells the trees nearest it, stops when full,
    out of fuel or felled out, and keeps going while the player is away.
  - A quarry makes gravel and its pit deepens by the volume.
  - A concrete plant turns gravel into concrete in a mixer under its chute.
  - A fuel station fills a tank from its stock and runs dry.
  - The tow loses the load; repair and addons take parts from the yard.
- `test_mixer.gd`:
  - The mixer drives as specified.
  - Its concrete sets after 5 minutes and is lost.
  - Poured in time, it counts at the site.
- `test_fog.gd`:
  - Each vehicle reveals its radius, and the scout more on a hill.
  - Places are found once revealed, and not before.
  - The fog and the track survive a save and a load.
- `test_scout.gd`:
  - It drives and turns as specified.
  - It takes no load and no trailer.
  - Its winch pulls it out.
- `test_water.gd`:
  - The water drags a truck and slows it, and the river's current pushes it downstream.
  - The intake under water for 1 s floods the engine. Out of the water, the engine runs again
    with 25% less condition.
  - With the snorkel, the 6x6 fords the shallows.
  - A truck on the bridge stays dry.
- `test_fleet.gd`, the trucks on the map:
  - A truck left stays where it was, with its fuel, load and trailer.
  - Switching works from the map and by E beside a truck.
  - A truck far off is frozen, and wakes when near, hit or hooked.
  - The garage fetches a truck out on the map.
  - The tow takes only the truck being driven.
  - A pickup with barrels refuels another truck.
  - A found truck runs once fuelled, and parts beside it bring its condition up.
- `test_gearbox.gd`:
  - Auto reaches today's top speeds.
  - In manual, first gear of low range climbs what auto spins on.
  - The sound's gear is the gearbox's.
- `test_condition.gd`:
  - Knocks, a flood and rolling over cost what §8 says.
  - The power drops with condition.
  - Repair at the garage brings it back.
- `test_profile` (in `test_start.gd`'s place): everything in §11 round-trips, and a save from
  another `map_version` drops its earthworks without an error.

**Changed:**
- `test_winch.gd`:
  - Aiming (`Winch.aim`) hooks the tree under the ray, not the one the winch would pick: one
    beside the truck, and one behind it.
  - Too far, the ground, or ground in between: refused, with the reason.
  - F twice hooks what the winch picks itself, as today.
  - Hooked to a parked truck, the winch pulls both, and the parked one wakes.
- `test_garage` sells nothing now. It fits addons, repairs and fetches a truck for parts and
  fuel, and checks the parking about every base.
- `test_world`, `test_terrain_shape` and `test_trucks` use the map's size, not 256.
- `test_english` covers the new strings.

**Removed:** `test_contracts.gd` (the jobs and their pay are gone), `test_valleys.gd`,
`test_stuck_car.gd`, and the valleys screen's part of `test_start.gd`.

## 13. Order of work, to 2026-12-01

The days are the owner's. Every milestone ends with the tests green and a web build that runs.

**This plan is about 26 days of work, and there are 15 to Nov 29:**

| Part | Days |
|---|---|
| The fork, the renames, the title screen (§2) | 1 |
| The map, the fog, the scout (§3, §7) | 3 |
| Earthworks (§4) | 3 |
| Placing and building: sites, bridges, gravel roads (§5) | 3 |
| Production, fuel, the mixer, loads on the trucks (§5-§7) | 3 |
| Trucks on the map, the winch by mouse, truck to truck, found trucks (§8) | 3.5 |
| Water and the engine flooding (§8) | 2 |
| The gearbox, condition, addons (§8) | 3 |
| The ledger, HUD, saving, the end (§9, §11) | 2 |
| Content, tuning, web performance, release | 3 |

So it runs as **three streams, each in its own local session and branch**. Khutir Road 0.3.0 was
built this way: `rigs/trucks` and `rigs/trailers` were made side by side and merged.

- **A, the land** (`land/*`): the map, the fog, earthworks, the water's level, crossings, gravel
  roads, the ravine fill, the quarry's pit.
- **B, the trucks** (`trucks/*`): the scout and the mixer, trucks on the map, loads on the
  trucks, the winch by mouse, truck to truck, found trucks, water and flooding, the gearbox,
  condition, addons.
- **C, the infrastructure** (`build/*`): placing, sites, production, fuel, the railhead, outposts
  as bases, the ledger, the goal and the end, saving. It starts on Khutir Road's 256 m map and
  moves onto A's map at the first merge.

The owner merges and plays each merge. That is the narrow part, so merges have fixed days.

| When | Milestone |
|---|---|
| Nov 14 (day 0) | Read the jam's FAQ (§0); stop if pre-jam code is not allowed. The fork and the renames (§2), the itch page drafted, the title screen. The three branches made. |
| Nov 15-19 | **A:** the 512 m map, the fog, rivers, slides, gap spans; web build time measured (≤ 8 s or fix it, §3); earthworks: `set_heights`, the loader and the tipper, volume, slump, limits. **B:** the scout and the mixer, trucks on the map, loads on the trucks, the winch by mouse, truck to truck. **C:** placing (P), sites, deliveries, fuel in litres, fuel stations, the railhead's yard, production on timers. |
| Nov 20 | **Merge.** Playable: scout, dig through L1, place a fuel station and pour the concrete into it before it sets. |
| Nov 21-23 | **A:** crossings and bridges, gravel roads, the ravine fill, the quarry's pit. **B:** water and flooding, the snorkel, condition and repair, found trucks. **C:** the sawmill felling trees, the quarry, the concrete plant and the mixer's clock, outposts, the ledger and waypoints, the goal and the end card, saving all of it. |
| Nov 24 | **Merge, and the cut decision** (below). Playable: from a new game to the village. |
| Nov 25-28 | Content along the critical path, playtests of the whole arc, tuning fuel and rates, web performance. Only if all that is done: the gearbox by hand, chains and the long winch, wear. |
| Nov 29 | **Release 0.1.0** (the `release-itch` skill), the itch page with screenshots and a GIF, **submitted to the jam**. |
| Nov 30 - Dec 1 | Buffer: fixes as 0.1.x. **Nothing new after Nov 30.** The deadline is Dec 1, 13:37 PST. |

**If it is late on Nov 24, cut in this order:**
1. The gearbox shifted by hand (auto stays as today; the theme still has the earthworks).
2. The ground wearing (churn).
3. Chains and the long winch (the snorkel stays, with the water).
4. The SE region: the river bridge, L2, the semi and the old fuel depot. The river stays, to
   drown in and to ford.
5. Concrete plants away from the railhead (the railhead's stays).
6. Outposts: the garage stays only at the railhead, and the tow always goes there.
7. Condition and repair: found trucks need only fuel, and a flooded engine just restarts out of
   the water.
8. Radio masts.
9. The ravine fill (keep the timber bridge: it is what the sawmill is for).
10. Map zoom.

**Never cut:**
- the scout and the fog, the goal and the end card;
- fuel that runs out, and fuel stations the player places;
- a sawmill in a forest the player picks, and the timber bridge over the ravine;
- the mixer and its concrete that sets;
- digging and tipping, one landslide, one gravel road;
- the winch aimed with the mouse, trucks staying on the map, water with the engine flooding.

Even that list is a lot for 15 days. If Nov 20's merge is not playable, the never-cut list itself
gets shorter, in the same order from its bottom.

**Stretch, after the jam:**
- real ruts in the heights from heavy wheels;
- a dozer blade on the 6x6;
- roads the player lays out: the scout drives the line with a key held and leaves stakes, and the
  stakes become a gravel road site;
- bridges placed anywhere a gap is short enough, not only at the old crossings;
- more materials and longer chains: logs and planks apart, cement, steel;
- what is where, shuffled from a seed for each new game;
- cranes and loose cargo, logs loaded by hand, cargo that can fall off;
- things that break: fences, poles, signs;
- a cab view;
- more tyres and addons, and addons for trailers;
- a working day, morning to dusk, as a "shift";
- a Ukrainian translation.

## 14. Decisions for the owner

1. **The name.** *Zsuv* is the working title (the Ukrainian for shift and for landslide, which is
   the game). Check itch.io for a clash before the page goes up.
2. **The jam's rules on pre-jam code and AI** (§0), on day 0. They decide whether the plan stands.
3. **The repository:** its name, public (required), and a licence if the jam expects one.
4. **The start:** the scout, the pickup with its trailer, the tractor with its tipper and the
   mixer at the railhead; the 6x6 and the semi found (§7). No money at all (§6). Is that right,
   or should some trucks be earned somehow?
5. **"Слідувати"** in the brief is read here as *to explore*: the scout reveals the map, and its
   track is kept for the haulers to follow. If it meant a truck that follows you on its own (a
   convoy), that is a separate system and a stretch.
6. **"Залив двигуна"** is read as the engine flooding in deep water (§8). If it meant something
   else, such as starting and stopping the engine by hand, say so.
7. **What from the genre is a must** for the jam: §8's table is a proposal, and the owner picks.
8. **The goal:** a truck brings the upper village fuel and parts by a road you made. Its name and
   what it asks for are the owner's.
9. **Five resources** (fuel, parts, gravel, timber, concrete) for the jam. Nails and the rest are
   "parts". More materials and longer chains come after the jam (§13).
10. **Production goes on while the player is away** (§5). The other way is that a building works
    only while the player is near it.
11. **Three streams in three local sessions** (§13), or one stream with a deeper cut.
12. **The mouse winch in Khutir Road first?** It touches only `winch.gd`, the HUD and the input
   (plus the trees' shape list in `world_builder.gd`). It can ship as Khutir Road 0.3.1 before
   the fork, so both games have it and the fork starts with it.
