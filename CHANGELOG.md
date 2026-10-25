# Changelog

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
