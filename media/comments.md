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
All four picked on 2026-10-28 have shipped: the throttle fix (smokeyai) in 0.1.1, the controls
hint and the sound (Philip) in 0.1.2, the maps and challenges (Philip) in 0.2.2, five valleys and
a job board (`docs/valleys.md`); 0.1.2 had no build of its own, so 0.2.2 is the first players get
of the last three. The owner's trucks and trailers (2026-10-29, picked 2026-10-30) shipped in
0.3.0 (`docs/trucks.md`).

- [ ] **Sivash, the salt lakes** (the owner, 2026-10-29): a valley of pink lakes and salt flats
  that slide like ice, in place of the Oleshky Sands (a desert with pines did not look right, and
  there are five valleys for now).

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
