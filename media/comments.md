# Player comments

The ledger of what players wrote on itch.io, what it asked for and what became of it. Kept by the
`player-comments` skill (`.claude/skills/player-comments/`): it reads the sources, adds what is new,
proposes the changelog candidates and records every reply.

## Sources

| Page | URL |
|---|---|
| The game | https://codirs.itch.io/psxrunner |
| AI Browser Game Jam 5 | https://itch.io/jam/ai-jam-5/rate/5228452 |
| Playtest & Feedback Exchange Jam #9 | https://itch.io/jam/playtest-feedback-exchange-jam-9/rate/5228452 |

The owner's account is **Codirs**: a post by Codirs is an answer.

## Next release: candidates

Changes players asked for. `[x]` is in the plan for the next release (the owner's pick), `[ ]` is
not yet. When a picked one ships, its CHANGELOG line names who asked, and it leaves this list.
All four picked on 2026-10-28; the throttle fix (smokeyai) shipped in 0.1.1. The owner's order:
the hint and the sound in 0.1.2, then the maps and challenges in 0.2.0.

- [x] **The controls on screen, but not over it** (Philip, jam). The help card is 190x150 of the
  480x270 frame, top right, until F1 hides it. A one-line key hint instead, the full card on F1.
  An hour.
- [x] **Sound: the engine labouring through the gears, the tyres in the snow** (Philip, jam). The
  game has no sound at all. A CC0 diesel loop pitched by revs and load (low range lower and
  harder), a snow crunch and a mud squelch by wheel slip. A day.
- [x] **More maps and challenges** (Philip, jam). A release of its own, 0.2.0. The owner's plan
  (2026-10-29): three valleys of the same size, each with its own locations, time of day and
  weather, picked on a valley screen: today's khutir valley, a spring thaw in Polissia (mud, bog,
  ice on a lake) and a Carpathian pass (switchbacks, deep snow, a ridge). The next valley opens
  for money earned in the one before (about $1500), saved, in the browser too. New jobs beside
  the plain delivery: against the clock with gold / silver / bronze and a record per job; fragile
  cargo that hard knocks and landings break, paying less; heavy cargo that sits the truck low,
  sinks it deeper and drinks more fuel; a stuck car to winch out of a ditch back onto the road.

## Comments

Newest first within each page. Status: **new** (not read into this file's lists yet), **open**
(read, an answer is owed), **promised** (answered with a promise not kept yet), **answered**.

### AI Browser Game Jam 5

- **#post-17719006, Philip** (2026-10-26, on 0.1.0): "realy love the feeling of the car and the 4x4
  power!"; would like to keep seeing the controls "but not over the whole screen :D"; sound, to
  hear the engine struggling with the gears and the tyres in the snow; can't wait for more maps
  and challenges. **Open**.
- **#post-17711061, smokeyai** (2026-10-25, an AI agent's playtest of the web build with scripted
  keyboard input): loading at the depot and grinding out into the snow with the winch in reach
  "feels right"; liked the help card listing every key up front. The input bug he reported on
  Crashcut, reproduced 2 of 2 here: hold W, let the focus leave the game (a click on the page
  outside the frame), release W there, and the game never sees the release: bogged at 0 km/h, the
  fuel 80 -> 74 L in about 9 s with nothing pressed. Suggests releasing the input actions on
  `NOTIFICATION_APPLICATION_FOCUS_OUT`. **Answered**: fixed in 0.1.1 as he suggested (checked in
  Chrome: 0.1.0 burnt 68 -> 64 L in 8 s after the click outside, 0.1.1 holds the fuel); Codirs
  told him in #post-17740758 (2026-10-29).

### Playtest & Feedback Exchange Jam #9

No comments yet (read 2026-10-28).

### The game

No comments yet (read 2026-10-28).
