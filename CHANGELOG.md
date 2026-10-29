# Changelog

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
