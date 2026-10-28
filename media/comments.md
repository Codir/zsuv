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
All four picked on 2026-10-28.

- [x] **W let go outside the browser's frame stays held** (smokeyai, jam). Reproduced on 0.1.0 with
  a headless script: after the focus-out notifications `accelerate` is still pressed and the fuel
  goes 80 -> 77.5 L in 5 s with nothing held. Fix as in Crashcut 0.3.3: let go of every pressed
  action on `NOTIFICATION_APPLICATION_FOCUS_OUT` / `NOTIFICATION_WM_WINDOW_FOCUS_OUT`, with a test.
  An hour. **Done on `main`, not released yet** (2026-10-28): `test_losing_focus_lets_go_of_the_keys`;
  in Chrome, the Web build in an iframe on localhost, W held, a click outside the frame, W let go
  there: 0.1.0 kept burning fuel (68 -> 64 L in 8 s at 0 km/h), the fix holds it at 78 L.
- [x] **The controls on screen, but not over it** (Philip, jam). The help card is 190x150 of the
  480x270 frame, top right, until F1 hides it. A one-line key hint instead, the full card on F1.
  An hour.
- [x] **Sound: the engine labouring through the gears, the tyres in the snow** (Philip, jam). The
  game has no sound at all. A CC0 diesel loop pitched by revs and load (low range lower and
  harder), a snow crunch and a mud squelch by wheel slip. A day.
- [x] **More maps and challenges** (Philip, jam). A release of its own.

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
  `NOTIFICATION_APPLICATION_FOCUS_OUT`. **Open**.

### Playtest & Feedback Exchange Jam #9

No comments yet (read 2026-10-28).

### The game

No comments yet (read 2026-10-28).
