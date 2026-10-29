# Valleys and jobs for 0.2.0 (the plan)

Philip asked in AI Browser Game Jam 5 for "more maps and challenges" (`media/comments.md`). The
owner's decisions, 2026-10-29, one release: 0.2.0.

## Six valleys

Each 256 m square like today's, its own locations, surfaces, time of day and weather. A start
screen picks the valley (Esc in a valley goes back to it), with a preview of each so the player
sees what awaits. They open in order of difficulty, bought from one wallet: the money earned in
any valley is spent on the next.

| # | Valley | Its own weather | Ground | Depot | Deliveries | Price |
|---|---|---|---|---|---|---|
| 1 | The khutir valley (today's) | winter dusk, snowfall | snow, mud puddles | depot | Khutir, Sawmill, Radio Tower | free |
| 2 | The steppe (Slobozhanshchyna) | sunny autumn | dry dirt roads, gullies, dust under the wheels, a little mud in the lows | the collective farm's motor yard | grain elevator, sheepfold in a gully, wind farm on a hill | $1500 |
| 3 | Zakarpattia | sunny spring after rain | vineyards on the slopes, meltwater and mud in the lows, snow only on the peaks | narrow-gauge railway station | winery among the vineyards, castle on a hill, village with a wooden church higher up | $2500 |
| 4 | Polissia | spring thaw, grey morning, fog | mud, bog, ice on a lake | old farm | fish farm on the lake shore (across the ice), peat works in the bog, village on a hill with a church | $4000 |
| 5 | Oleshky Sands | summer sun | dunes, sand (a new surface: it sinks the wheels unlike snow), pine plantations, the sea in the distance | village at the edge | forestry in the pines, apiary between the dunes, lighthouse on the shore | $6000 |
| 6 | The Carpathian pass | night, blizzard | switchbacks, deep snow, a ridge | village in the valley | shepherds' hut (koliba) on the polonyna, weather station on the ridge (the highest point), mountain rescue base on the pass | $8500 |

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
