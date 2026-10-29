# Sound for 0.1.2

Philip asked in AI Browser Game Jam 5 for sound: "the engine struggling with gears or the tires
in the snow" (`media/comments.md`). The owner chose real CC0 recordings over synthesis
(2026-10-29), so the itch.io AI disclosure keeps "no Sounds".

Built: the recordings below sit in `sounds/source/` (a `.gdignore` keeps Godot from importing
them: they never ship); `tools/make_sounds.py` cuts them into the 27 sounds in `sounds/`;
`scripts/vehicle/truck_audio.gd` plays them; `tests/test_sound.gd` checks it. Left: the owner
listens (`./godot.sh soundcheck`, or the game), then release 0.1.2 (the last section).

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

## The cuts (`python tools/make_sounds.py`)

22,050 Hz mono OGG Vorbis (PSX), 280 KB in all. Needs Python with NumPy, SciPy and soundfile;
`--preview DIR` also writes each loop four times over as a WAV, to listen for the seam.

- `engine_idle.ogg`: 3.40 s of 1145 from 24.25 s, where the waveform repeats best (the 80 ms
  past the end correlate 0.95 with the start); that 80 ms is crossfaded into the start, so the
  last sample runs on into the first. `engine_labour.ogg`: the same samples, low mids
  (90–400 Hz) up, driven into tanh clipping, the fizz above 4.5 kHz taken off; filtered three
  times over and the middle kept, so the filters run on across the seam. Both -16 dB RMS.
- `winch.ogg`: 3.94 s of 0708 from 17.25 s, a 250 ms equal-power crossfade (a motor's whine is
  noise to a correlation: 0.37 at best).
- `snow_01`–`08.ogg`: the eight loudest footfalls of 2890 with none within 0.9 s, each from 10 ms
  before its onset to 0.35 s, faded out, above 120 Hz.
- `mud_01`–`16.ogg`: the 16 squelches whose sound lasts 0.12–0.4 s (a wheel's, not a boot's),
  trimmed to it. Hits are levelled to -16 dB RMS with no peak above -1 dB, so the peaky
  squelches land between -16 and -27 dB.

The loops' `.import` files say `loop=true`.

## What the game plays (`scripts/vehicle/truck_audio.gd`)

- **Engine:** both loops at once, at one pitch, rpm / 800. The gearbox exists only for the ear:
  high range 3.5 / 7 / 11.5 / 18 m/s, low range 2.5 / 5.5 m/s, reverse 5 m/s, each gear's top
  speed at 1800 rpm; up a gear past its top, down below 80% of the gear below's. The revs follow
  the truck's speed in its gear, or the fastest driven tread when a wheel spins (flaring to the
  2000 rpm limit); with the truck standing, the throttle alone lifts them to 1200 (a slipping
  clutch). Labour = throttle x (0.3 + 0.7 x (1 - speed / the gear's top)): held at full throttle
  in 4x4 it is 1.0 at 1200 rpm, the growl over the idle. On an empty tank the revs run down and
  the engine fades out in 1.25 s; it starts again with fuel.
- **Snow and mud:** each wheel on the ground whose tread moves faster than 0.3 m/s adds a crunch
  every 0.9 m (snow deeper than 5 cm) or a squelch every 1.3 m (mud wetter than the snow is
  deep, as the spray decides), at most 12 a second for all four. Spin counts: the tread is the
  wheel's. Each plays as loud as the snow is deep (full at 40 cm) or the mud wet, from an
  `AudioStreamRandomizer` (pitch x/÷ 1.15, ±2 dB), four at once at most.
- **Winch:** the motor runs while the cable reels in, fading in and out over 1/6 s; its pitch
  falls from 1.1 to 0.75 as the tension rises to the winch's 32 kN.
- **Players:** `AudioStreamPlayer3D` on the truck, panned to where it is from the camera but with
  no attenuation: the chase camera sits 4–25 m off and a tree can pull it to 2 m, and Godot caps
  a 3D player's volume plus its distance gain at `max_db` (+3 dB), which flattened every level
  when it came close. Engine on the Engine bus, the rest on Sfx (-4 dB).
- **The browser** (learnt on Crashcut 0.3.2): the buses live in `default_bus_layout.tres`
  (buses made while the game runs wired the browser into a feedback loop and it played
  silence); every player streams, `playback_type = AudioServer.PLAYBACK_TYPE_STREAM` (as
  browser samples, loops restarted 10–80 ms late). The single-threaded Web build mixes on the
  main thread, once a frame: a minimal Web export of these players (the engine loop with its
  pitch swept, crunches three a second) played -16 to -19 dB RMS without a gap in Chromium at
  60 fps. The whole game could not be heard there: the container's software WebGL drew 3 fps.
  If players hear crackling in the browser, raise `audio/driver/output_latency.web` (50 ms).
- Written without `D:\Projects\voxelrally\scripts\audio\car_audio.gd` (not reachable from the
  cloud session): worth a comparison.

## Levels (`./godot.sh soundcheck`)

`tests/soundcheck.gd` drives a script in real time (the audio thread mixes on the wall clock),
records the Master bus into `capture/soundcheck.wav` and prints each part's loudness. On
2026-10-29, peaks never above -3 dB:

| Part | RMS | Peak |
|---|---|---|
| idle at the depot | -22 dB | -12 dB |
| the east road in 2WD, into the puddle (stuck in it, wheels spinning) | -19 dB | -4 dB |
| deep snow in 4x4 (stuck, wheels spinning) | -17 dB | -6 dB |
| held at full throttle, 4x4 / 2WD | -16 / -17 dB | -8 / -10 dB |
| the winch | -20 dB | -3 dB |
| empty tank (the engine dies) | -34 dB | -17 dB |

The trailer capture (`./godot.sh capture`) mutes the sound: its frames come slower than real
time.

## Tests (`tests/test_sound.gd`)

Every player streams, on its bus; the loops loop; the two engine loops are one length; the
revs climb and drop at each shift (1→2: pitch 2.02 → 1.68, 2→3: 2.16 → 1.47) on the east road;
held at full throttle in 4x4 the labour is 1.0 at 1200 rpm and the growl is louder than the idle,
in 2WD the rear wheels spin to 2000 rpm, and it all settles back to idle when the throttle comes
up; no crunch standing in deep snow, 36 in 3 s rolling through it, 7 squelches through the
puddle; the engine stops on an empty tank and starts with fuel; the winch motor runs only
while reeling, its pitch down to 0.88 under the strain. The test runner frees the world before
it quits: a sound still playing at exit leaks its stream.

## Release 0.1.2

`release-itch`: the CHANGELOG and the devlog name Philip (the hint and the sound) and the sound
authors (Joseph SARDIN of BigSoundBank, rubberduck of OpenGameArt). The itch.io page: the AI
disclosure keeps "no Sounds", its reason no longer "the game has none" but CC0 recordings; a
line for the sound in the description. Then answer Philip (`player-comments`) about the hint
and the sound.
