# Zsuv

*Зсув*: Ukrainian for a shift, and for a landslide.

It is spring after the floods. Landslides have shifted the hillsides onto the roads, the river
took the bridges, and the upper village, high in the mountains, is cut off. You are the road crew
sent from the railhead: scout the land nobody has mapped since, dig through the slides, fill the
washouts, lay gravel, put up fuel stations and sawmills where you choose, pour concrete before it
sets, and build bridges until a truck gets through to the village.

Made for [GitHub Game Off 2026](https://itch.io/jam/game-off-2026), theme **SHIFT**.

**Built on Khutir Road** (October 2026, by the same author): the driving, the trucks, the sound
and the PSX look come from it. What was made for Game Off is everything since the tag
`base-khutir-road-0.3.0`:

```bash
git diff base-khutir-road-0.3.0..main --stat
```

The plan for the jam, and what it changes, is in [docs/plan.md](docs/plan.md). Made with an AI
coding agent (Claude Code) writing the code, the text and the procedural art. The sounds are CC0
recordings by people (see Credits).

Godot 4.7.2 (GL Compatibility, Jolt Physics), everything procedural; runs on Windows, Linux,
macOS and in the browser.

**In development** for Game Off 2026.

## Controls

| Key | |
|---|---|
| W / S | throttle / brake, reverse |
| A / D | steer |
| Space | handbrake |
| Q | all-wheel drive (4x4) |
| X | differential lock |
| G | low range |
| N | gearbox auto or manual; in manual , and . shift down and up (first gear of low range crawls where auto spins) |
| H | headlights |
| E | at a site, bring it the loads it needs; at a building, unload what it takes, fill the tank, or open the list of what can be loaded (stopped); beside your parked truck, step across into it, or pour fuel into it from barrels |
| 1 - 9 | pick from the list on screen: what to build, what to load, the truck to drive |
| P | place a building (stopped): pick it, the footprint follows the mouse, green or red with the reason; the wheel turns it, left click stakes it, Esc cancels; beside a site with nothing brought, take it down |
| Tab | at the railhead or an outpost: the garage; U there turns to the workshop (upgrades, repair) |
| C | hitch the trailer behind you, or unhitch it |
| B / V | the tractor: hold B to dig with the bucket (into its tipper), hold V to tip; creeping forward spreads gravel into a road |
| F | aim the winch with the mouse, left click hooks the tree, rock, building or truck under the cursor; F again hooks the nearest ahead; Esc cancels; hold Shift to reel in |
| M | paper map, with the ledger of every building and site; click a parked truck's mark to drive it, anywhere else for a waypoint (click it again to clear it) |
| Z, wheel on the map | the whole map, or the biome you are in |
| T | tow to the nearest base (the load on the truck is lost) |
| R | flip upright |
| Right mouse + drag, wheel | orbit and zoom the camera |
| F1 | the help: a short hint in the corner, then every key, then none |
| Esc | close what is open; back to the title |

Keys are physical, so they sit in the same place on any keyboard layout.

## Run from source

```bash
./godot.sh run                    # downloads Godot 4.7.2 into tools/godot/ the first time
GODOT=/path/to/Godot_v4.7.2-stable_win64_console.exe ./godot.sh run   # use a Godot you have
./godot.sh editor
```

## Tests

```bash
./godot.sh check        # every script parses, every shader compiles
./godot.sh test         # tests/test_*.gd against one shared world, headless and silent, at a fixed 60 fps
./godot.sh soundcheck   # record the game's mix on a scripted drive into capture/soundcheck.wav
```

The tests build the real world and drive it. Any error the engine logs during a test fails it,
and a watchdog ends a run that hangs.

## Export

```bash
./godot.sh export          # Web, Windows, Linux and macOS into builds/ (fetches the export templates once, ~600 MB)
./godot.sh export Web      # or Windows | Linux | macOS
./godot.sh web             # export Web and serve it on http://localhost:8060
```

macOS: a universal `.app` in a zip, ad-hoc signed, not notarized: open it the first time with
right-click > Open. Web: single-threaded (no SharedArrayBuffer), so it runs on itch.io without
COOP/COEP headers.

## Release to itch.io

Every push to `main` runs `.github/workflows/godot.yml`: the tests, then all four exports (the
Web build is kept as a 3-day artifact). A `vX.Y.Z` tag also creates a GitHub Release, and each
export is pushed by butler to its channel of https://codirs.itch.io/zhuv (`html5`, `windows`,
`linux`, `mac`), with the Windows, Linux and macOS files attached to the release.

Needs the `BUTLER_API_KEY` repository secret (an itch.io API key: https://itch.io/user/settings/api-keys);
the `ITCH_TARGET` repository variable overrides `codirs/zhuv`. The version is the top entry of
[CHANGELOG.md](CHANGELOG.md) = `config/version` in `project.godot` = the tag. The `release-itch`
skill (`.claude/skills/`) walks the whole procedure. On the first release, mark the `html5`
upload on itch.io as "played in the browser" (viewport 960x540; it scales).

## Store media

```bash
./godot.sh capture                           # scripts/capture/director.gd films the scenes into capture/trailer/ (a window, no sound)
python tools/make_media.py --ffmpeg ffmpeg   # the trailer, screenshots, cover and GIF into media/
```

`make_media.py` needs Python 3 with Pillow and NumPy, and FFmpeg (or Blender 4.5) for the MP4. Copy
for the itch.io page is in [media/itch-page.md](media/itch-page.md).

## Sound

```bash
python tools/make_sounds.py    # cut sounds/source/ (CC0 recordings, never shipped) into sounds/
```

Needs Python 3 with NumPy, SciPy and soundfile. [docs/sound.md](docs/sound.md) has the
recordings, the cuts, how the truck plays them and how loud. [docs/trucks.md](docs/trucks.md) has
the rigs.

## Credits

Font: [Inconsolata](https://github.com/googlefonts/Inconsolata) by Raph Levien and the Inconsolata
Project Authors, SIL Open Font License 1.1 ([fonts/OFL.txt](fonts/OFL.txt)).

Sounds: CC0 recordings by Joseph SARDIN of [BigSoundBank](https://bigsoundbank.com) (a diesel
truck engine, footsteps in snow, an electric winch) and by rubberduck
([25 CC0 mud sfx](https://opengameart.org/content/25-cc0-mud-sfx), OpenGameArt).
