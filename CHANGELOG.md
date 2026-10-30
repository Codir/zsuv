# Changelog

## 0.3.0 — 2026-10-30 — Trucks and trailers

- Four new rigs beside the pickup, as in SnowRunner: a trailer for the pickup; a heavy 6x6 (an
  army truck with big lugged tyres, through deep snow and mud where the pickup bogs); a farm
  tractor with a tipper trailer, slow and sure through bog; a semi truck with a 12 m flatbed
  semi-trailer, fast on a road and hard work in a hairpin. Each looks, pulls, turns and sounds its
  own way.
- A garage at the depot: Tab on the job board. The trailer $800, the tractor with its trailer
  $2500, the 6x6 $3500, the semi truck with its semi-trailer $5000, bought once from the wallet
  the valleys are bought from and kept in every valley; a truck bought is driven from any depot.
- Trailers wait beside the depot: back up to one and press C to hitch it, C again to leave it.
  It follows on a hitch that turns and pitches, brakes with the truck, and comes along on the tow.
- The board offers five jobs, at least two for the truck in play; the others say what they need.
  The heavy load is the 6x6's now, 3500 kg of rings paying twice; new loads: a double load on the
  pickup and its trailer (1.5 times), grain, peat or hay in the farm trailer (1.8), logs or pipes
  on the semi-trailer (2.5).
- The dashboard names the drive by wheels (4x2, 6x6); the camera stands back for a trailer.
- Tests for the trucks (each drives, the 6x6 and the tractor through snow and mud, the 6x6
  loaded up the steepest road), the trailers and the hitch (standing, hitching, pulling, braking,
  turning, the tow), the garage and the jobs by rig.

## 0.2.2 — 2026-10-29 — Five valleys

- Four new valleys beside the khutir valley, as Philip asked in AI Browser Game Jam 5 for more
  maps: a sunny autumn steppe of dry dirt roads, gullies, a hill of wind turbines and a dig on a
  kurgan; Zakarpattia in the spring sun, vineyards, a castle on its hill, a wooden church, a
  mineral spring and snow on the peaks; Polissia in a foggy thaw, bogs, a road across a frozen
  lake, a fish farm, peat works, a village, an apiary and a forestry; the Carpathian pass at
  night in a blizzard, switchbacks through deep snow to a weather station on the ridge, a koliba,
  a mountain rescue base, a logging camp and a mountain village. More places to deliver to in
  each: 3, 4, 4, 5, 5.
- The valleys screen: a picture of each and a card in icons of what awaits (season and sky,
  difficulty, the places; the mouse names them). They open in order for the money earned, $1500
  to $6000. Each valley's sky can be switched to sun, overcast, snow or rain, or night. Esc in a
  valley goes back to the screen. Money, valleys, skies and records are saved, in the browser too.
- A job board at the depot, as Philip asked for challenges: three jobs at a time, plain, against
  the clock (gold, silver, bronze and a record each), fragile (it breaks on hard knocks and
  landings and pays for what is whole), heavy (concrete rings that sit the truck low and drink
  fuel, for more pay), and a car stuck in a ditch to winch back onto the road. A new job taken at
  the depot drops the one in hand.
- The winch hooks a stuck car and pulls it right up to the bumper while the truck holds; the
  car pays once the winch has pulled it out of the ditch. The test autopilot slows for the bend
  ahead.
- The first build with 0.1.2's sound and controls hint in it: 0.1.2 never had one of its own.
- Tests for the valleys (each builds, nothing on a road, every road drives both ways), the
  skies, the valleys screen and the profile, the jobs and the stuck car; `./godot.sh previews`
  renders the screen's pictures. A tag whose version is not the one in project.godot and the
  CHANGELOG fails in CI before anything is released.

## 0.2.1 — 2026-10-29 — Tagged by mistake

- The v0.2.1 tag went onto the five valleys' first merge, before the fixes from their review
  were merged; its build was stopped before its tests. What 0.2.1 was to be shipped as 0.2.2.

## 0.2.0 — 2026-10-29 — Tagged by mistake

- The v0.2.0 tag went onto 0.1.2's commit before the five valleys were merged; its build was
  stopped before it reached itch.io. What 0.2.0 was to be shipped as 0.2.2.

## 0.1.2 — 2026-10-29 — Hear it work

- The truck is heard, as Philip asked in AI Browser Game Jam 5: the diesel climbs through its
  gears and drops at each shift, more revs for the speed in low range; held at full throttle
  where it can't move, it growls; a spinning wheel flares the revs. The tyres crunch snow and
  squelch mud as they roll, louder the deeper it is; the winch motor whines, lower under the
  strain; on an empty tank the engine dies. Real CC0 recordings: a diesel truck, footsteps in
  snow and an electric winch by Joseph SARDIN (BigSoundBank), mud squelches by rubberduck
  (OpenGameArt).
- The controls stay on screen without covering it, as Philip asked in the jam: a three-line hint
  of the keys a drive needs in the top right corner instead of the full card; F1 steps to the
  card of every key, then to nothing.
- Tests for the sound, and `./godot.sh soundcheck`, which records the game's mix on a scripted
  drive and prints how loud each part was.

## 0.1.1 — 2026-10-28 — Hands off

- In the browser, W let go after a click outside the game's frame no longer leaves the truck on
  the throttle, burning fuel with nothing pressed (smokeyai's report in AI Browser Game Jam 5):
  the game lets go of every key when it loses the keyboard.
- GitHub Actions run on Node 24.

## 0.1.0 — 2026-10-25 — Khutir Road

- The game has a name, Khutir Road, and speaks English: HUD, prompts, help, map, signs and code
  comments. The farmstead on the west road is the khutir the title is about.
- Bundled font (Inconsolata, OFL), so the Web, Linux and macOS builds draw the same crisp HUD as
  Windows did with Consolas, fuel gauge included.
- The road out of the depot no longer drops off a 9 m cliff, and the climb to the khutir is no
  longer a 36-degree wall: the ground around a location now ramps down over a distance that grows
  with the height of the step.
- The truck's hold-on-a-slope brake lets go while the winch reels in, so the winch can pull.
- The winch cable is thicker, so it shows at 480x270.
- A Web export next to Windows, Linux and macOS, and GitHub Actions: tests on every push, the four
  exports, and on a `v*` tag a GitHub Release plus butler pushes to itch.io.
- Tests: the world, driving, fuel, ruts, snow and mud, the delivery loop, the tow, the winch, and
  English everywhere.
- Store media: a scripted capture (`./godot.sh capture`) and `tools/make_media.py` for the trailer,
  screenshots, the itch.io cover and a GIF.
- A game icon, and the Windows exe carries it with the game's name and version.
