# Valleys and jobs (0.2.2)

Philip asked in AI Browser Game Jam 5 for "more maps and challenges" (`media/comments.md`). The
owner's decisions, 2026-10-29, built for 0.2.2 (the v0.2.0 and v0.2.1 tags went onto earlier commits by mistake and were never built): `scripts/world/valley.gd` (the valleys as data),
`scripts/world/weather.gd` (the skies), `scripts/ui/start_screen.gd` and `scripts/ui/icons.gd`
(the valleys screen), `scripts/systems/profile.gd` (what is saved), `scripts/systems/contracts.gd`
(the jobs), `scripts/vehicle/stuck_car.gd`.

## Five valleys

Each 256 m square like today's, its own places, ground, time of day and weather, with more
places to deliver to as they go: 3, 4, 4, 5, 5. A start screen picks the valley (Esc in a valley
goes back to it), with a picture of each and a card in icons (season and sky, difficulty, the
depot and its places; the mouse over one names it), so the player sees what awaits. They open in
order of difficulty, bought from one wallet: the money earned in any valley is spent on the next.
The Oleshky Sands were tried and dropped (a desert with pines did not look right); Sivash's salt
lakes are a candidate for later (`media/comments.md`).

| # | Valley | Its own weather | Ground | Depot | Deliveries | Price |
|---|---|---|---|---|---|---|
| 1 | The khutir valley (today's) | winter dusk, snowfall | snow, mud puddles | depot | Khutir, Sawmill, Radio Tower | free |
| 2 | The steppe (Slobozhanshchyna) | sunny autumn | dry dirt roads, gullies, a little mud in the lows | the motor yard | grain elevator, sheepfold in a gully, wind farm on a hill, a dig on a kurgan | $1500 |
| 3 | Zakarpattia | sunny spring after rain | vineyards on the slopes, meltwater mud in the lows, snow on the peaks | narrow-gauge station | winery, castle on a hill, wooden church higher up, mineral spring | $2500 |
| 4 | Polissia | spring thaw, grey morning, fog | mud, bog, ice on a lake | old farm | fish farm across the ice, peat works in the bog, village with a church, apiary, forestry | $4000 |
| 5 | The Carpathian pass | night, blizzard | switchbacks, deep snow, a ridge | village in the valley | koliba on the polonyna, weather station on the ridge, mountain rescue on the pass, logging camp, mountain village | $6000 |

The start screen can switch a valley's weather: sun / overcast / snow or rain / night, its own
one first.

## Jobs

E at the depot opens a board of three jobs, each to a different place and of a different kind,
with what it pays; 1, 2 or 3 takes one, loads it and fills the tank. With a job in hand, E there
fills the tank and opens the board too, and a new job taken drops the one in hand. A place pays
its reward times the valley's pay (1, 1.2, 1.4, 1.7, 2.4), and by kind:

- **Plain:** as it is.
- **Against the clock:** gold, silver and bronze for 30, 22 and 15 km/h along the shortest way
  by road from the depot (the straight line and 30% for a place off the roads), paying 1.5, 1.25
  and 1 times, 0.6 without a medal. The best time of each job is kept and shown on the board.
- **Fragile:** the HUD shows the load's integrity; every jolt over 38 m/s2, measured over 50 ms,
  breaks 0.6% of it per m/s2 above (driving the roads stays under 33; a drop of 2 m costs about
  7%, 4 m about 75%); a tow or setting the truck upright is no jolt. Pays 1.3 times what is
  left; at nothing left it is gone.
- **Heavy:** 1800 kg of concrete rings instead of 900 kg of crates: the truck sits lower, drags
  deeper and burns 1.5 times the fuel; pays 1.6 times.
- **A stuck car:** a car slid nose first into the ditch beside one of the roads (each road has
  one, 7 m off its middle, clear of the road on a bend, of its other legs and of trees: a trench
  1.4 m below the road beside it, cut into a slope above the road or banked up on one below, so
  the car stays put until it is pulled). F hooks the winch on its towing eye, Shift reels it right
  up to the bumper, and the truck holds on its brake while the car comes. Out of the ditch at the
  road's level and at rest (on its roof counts), it pays $300 times the valley's pay; a car the
  winch never had pays nothing.

## Roads in the hills

A road is a shelf level across. In the hills (Zakarpattia, the steppe, the pass) its profile is
averaged over 14-24 m and kept to 20-22% (or what a climb needs, never a step), cut into the
slope above and filled below, except for 14 m at each end where it crosses a place; two roads
blend where they meet; hairpins are U turns at the ends of legs that climb across the slope.
Every road of every valley drives both ways in 4x4 (`tests/test_valleys.gd`).

## Saved

`user://khutir_road.cfg` (IndexedDB in a browser): the money, the valleys bought, the sky picked
for each, the records, the last valley. Saved on every change.
