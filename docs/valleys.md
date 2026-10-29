# Valleys and jobs for 0.2.0 (the plan)

Philip asked in AI Browser Game Jam 5 for "more maps and challenges" (`media/comments.md`). The
owner's decisions, 2026-10-29, one release: 0.2.0.

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

A job board at the depot offers two or three jobs at a time (what, where, kind, pay); the player
picks one with a key. Beside the plain delivery:

- **Against the clock:** gold, silver and bronze for an average along the road of about 30, 22
  and 15 km/h (the times follow from the route's length, one number to tune); a record per job.
- **Fragile:** the HUD shows the cargo's integrity (CARGO 100%); every hard knock or landing takes
  some off, by its force; it pays the reward times the integrity, nothing at 0 (broken).
- **Heavy:** 1800 kg instead of 900: the truck sits lower, sinks deeper and burns 1.5 times the
  fuel; pays 1.6 times.
- **A stuck car:** a car in a ditch beside a road; F hooks the winch onto it, Shift reels it in;
  paid once its wheels are on the road.

## Saved

The money, the valleys bought, the records and medals; in the browser too (`user://` is
IndexedDB there).
