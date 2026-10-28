# Sound for 0.1.2 (work in progress)

Philip asked in AI Browser Game Jam 5 for sound: "the engine struggling with gears or the tires
in the snow" (`media/comments.md`). The owner chose real CC0 recordings over synthesis
(2026-10-29), so the itch.io AI disclosure keeps "no Sounds".

Done so far: the five recordings below, approved and downloaded, are in `sounds/source/`
(a `.gdignore` keeps Godot from importing them: they never ship), and `default_bus_layout.tres`
holds the buses. Next: cut the loops and hits, write the truck's audio, its tests, release 0.1.2.

## Sources (all "CC0 (public domain)", checked on each page on 2026-10-29)

| File in `sounds/source/` | Title, author | Page |
|---|---|---|
| `bsb-1145-truck-engine.ogg` | Truck engine (Iveco Daily 3.0 diesel), Joseph SARDIN | https://bigsoundbank.com/truck-engine-s1145.html |
| `bsb-1146-truck-engine-small-accelerations.ogg` | Truck engine, small accelerations, Joseph SARDIN | https://bigsoundbank.com/truck-engine-small-accelerations-s1146.html |
| `bsb-2890-footstep-in-the-snow-2.ogg` | Footstep in the Snow #2 (Foley), Joseph SARDIN | https://bigsoundbank.com/footstep-in-the-snow-2-s2890.html |
| `bsb-0708-little-electric-winch.ogg` | Little electric winch (SUV / ATV), Joseph SARDIN | https://bigsoundbank.com/little-electric-winch-s0708.html |
| `mud/mud_01.ogg` … `mud_25.ogg` | 25 CC0 mud sfx, rubberduck | https://opengameart.org/content/25-cc0-mud-sfx |

CC0 needs no credit, but the CHANGELOG and the devlog name them anyway, as Crashcut does.

## What the recordings hold (measured)

- **1145, the engine:** a steady idle from 1 s to 33 s, -15 dBFS RMS, the strongest partial at
  57 Hz the whole way; start at 0–1 s, stop after 33 s. The base loop: a few seconds from the
  middle, crossfaded end into start, played at pitch 1 for idle.
- **1146:** the same idle at -25 dB with throttle blips to -18 dB that wander 40–76 Hz; no
  sustained revs, so it is no load layer. Spare: a blip as a one-shot, or nothing.
- **2890, snow:** a footstep about every 1.25 s, each crunch peaking -24 to -30 dB over a -55 dB
  floor. Cut each crunch into its own short hit (onset to about 0.35 s, faded).
- **0708, the winch:** on/off at 0–5 s, then a steady motor from 5 s to 40 s at -21 dB, its
  whine at 320–340 Hz. The loop: a few seconds from 15–25 s.
- **Mud:** 25 squelches, 0.19–0.84 s, peaks at 0 dBFS, RMS -15 to -28 dB: normalise them.

Tools that work here: Python with numpy, scipy and soundfile (it writes OGG Vorbis); no ffmpeg.
Resample to 22,050 Hz mono (PSX), OGG, into `sounds/` (shipped), the cutting script into
`tools/make_sounds.py` reading `sounds/source/`.

## The plan

- **Engine**, two loops from the same 1145 cut, so they never drift apart: the clean idle and
  a "labouring" copy (driven into soft clipping, low mids up). Pitch from a sound-only gearbox:
  high range about four gears over 0–18 m/s, low range two over 0–5.5 m/s (more revs for the
  speed: it sounds like the truck is working), idle about 800 rpm = pitch 1. The labouring layer
  rises with the throttle and with how little the truck moves for it (bogged in snow at full
  throttle: low revs, full growl); wheel spin flares the revs. No fuel: the engine dies away.
- **Snow and mud:** hits, not loops: each wheel in contact triggers crunches (snow) or
  squelches (mud) at a rate that follows its rolling speed and its slip, volume by the surface's
  depth; an `AudioStreamRandomizer` with random pitch, `max_polyphony` a few.
- **Winch:** the motor loop while it reels in, its pitch falling as the tension climbs.
- **Godot in the browser** (learnt on Crashcut 0.3.2): the buses live in
  `default_bus_layout.tres` (buses made while the game runs wired the browser into a feedback
  loop and it played silence); every loop plays with
  `playback_type = AudioServer.PLAYBACK_TYPE_STREAM` (as browser samples they restarted
  10–80 ms late). Read `D:\Projects\voxelrally\scripts\audio\car_audio.gd` for the model.
- **Tests:** the pitch climbs with speed and drops at a shift; at full throttle and no speed the
  labouring layer is up; no crunch at rest, crunches when rolling in snow, squelches in mud;
  silence on an empty tank; the winch only while reeling; every loop is a stream.
- **Then** release 0.1.2 (`release-itch`): the CHANGELOG and devlog name Philip and the sound
  authors; then answer Philip (`player-comments`) about the hint and the sound.
