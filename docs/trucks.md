# Trucks and trailers (0.3.0)

The owner asked, 2026-10-29, for different trucks for different loads, and trailers, as in
SnowRunner (`media/comments.md`). The owner's decisions, 2026-10-30, all in one update, 0.3.0:

- **Four new rigs** beside today's pickup: a trailer for the pickup, a heavy 6x6, a tractor with a
  farm trailer, and a semi truck with a semi-trailer.
- **Bought in a garage at the depot**, once, from the one wallet the valleys are bought from, and
  kept for every valley: the trailer $800, the tractor with its trailer $2500, the 6x6 $3500, the
  semi truck with its semi-trailer $5000. At any depot the garage puts the truck picked there.
- **Hitching is done by hand**: the trailers wait at the depot; back the truck up to one and press
  C. C again unhitches, so a trailer can be left to winch the truck out.
- **The board shows every job**, each with the rig it needs ("6x6", "semi-trailer"...); one can be
  taken only with that rig, which is what makes a truck worth buying. Up to five jobs at a time.
- **Loads by rig**: the heavy load becomes 3500 kg of concrete rings, paying twice, on the 6x6
  only; the pickup keeps plain, timed and fragile loads and the stuck cars. A double load on the
  pickup and its trailer pays 1.5 times; a bulk load (grain, peat, hay) in the tractor's trailer
  1.8 times; a long load (logs, pipes, a turbine blade) on the semi-trailer 2.5 times.

## The rigs

Speeds as measured on the flat (the specs' rated top speeds are higher: all lose about a fifth to
drag and rolling), turning circles at full lock, as built (`tests/test_trucks.gd`,
`tests/test_trailer.gd`).

| Rig | Price | Wheels | Mass | Top speed | Turns in | Carries | Its way |
|---|---|---|---|---|---|---|---|
| Pickup | owned | 4: 4x2 / 4x4 | 2000 kg | 48 km/h | 5.3 m | plain, timed, fragile (900 kg); tows the trailer | bogs in deep snow in 4x2 |
| Trailer | $800 | 2, one axle | 400 kg | | | a double load: 900 kg in it, 900 on the bed | behind the pickup or the 6x6 |
| Heavy 6x6 | $3500 | 6: 6x4 / 6x6, big lugged tyres | 6500 kg | 40 km/h | 6.8 m | the pickup's loads and the heavy one (3500 kg of rings) | through deep snow and mud; 150 L, burns 1.8 times |
| Tractor | $2500 | 4: big lugged rears, 4x2 / 4x4 | 4000 kg | 25 km/h | 5.0 m | nothing itself: bulk in its trailer | crawls through bog and deep snow in 4x2 |
| Farm trailer | with the tractor | 4, tandem | 1500 kg | | | bulk: 4000 kg of grain, peat or hay | |
| Semi truck | $5000 | 6: 6x4, twin rear tyres | 7000 kg | 54 km/h | 9.9 m | nothing itself: long loads on its semi-trailer | fast on a road; sinks in mud; a hairpin is hard work |
| Semi-trailer | with the semi truck | 6, three axles | 3000 kg | | | long: 8000 kg of logs or pipes | 12 m; 37% of it on the fifth wheel |
| Scout (Zsuv) | owned | 4: always 4x4, 0.36 m tyres | 1200 kg | 64 km/h | 4.4 m | nothing; no hitch | the fastest, 45 L at half the burn, a 20 m winch: it finds the way |
| Mixer (Zsuv) | owned | 6: 6x4, the semi's chassis | 9000 kg, 15000 loaded | 46 km/h (41 loaded) | 9.9 m | concrete, 1 load, sets in 5 minutes | 200 L, burns 1.6 times, a 24 m winch |

The hitches meet: a towbar at 0.62-0.70 m and the trailer's ball at 0.64; the tractor's pin and
the farm trailer's eye at 0.72; the fifth wheel at 1.30 m and the kingpin, standing on its legs,
at 1.33.

## Where each rig gets to

A job goes only where its rig gets to, loaded, from the depot (a place's `no` in
`scripts/world/valley.gd`). Measured with a probe driving each rig from where the garage puts it,
its trailer hitched and full, in low range with the differentials locked, along the roads to every
place: the semi rig stops in deep snow, full mud and on the steepest climbs, and cannot follow the
Carpathian hairpins; the tractor rig with 4 t of grain stops on the steepest climbs; the 6x6 with
its rings only in the full mud below the Polissia forestry.

| Valley | Long (semi) | Bulk (tractor) | Heavy (6x6) |
|---|---|---|---|
| Khutir | none | Khutir | all |
| Steppe | elevator, wind farm | all | all |
| Zakarpattia | winery, wooden church, spring | all but the castle | all |
| Polissia | fish farm, peat works, apiary | all but the village and the forestry | all but the forestry |
| Carpathians | mountain rescue | all but the weather station and the village | all |

## How it is built

- `scripts/vehicle/truck_spec.gd`: a truck as data, as `Valley` is a valley: its wheels (mount,
  radius, steered, driven in 2WD, tread), springs, engine, top speeds, fuel, mass, the loads it
  carries, its winch and hitch, the look its body is built from, the camera's distance and the
  engine's pitch and place. `TruckSpec.all()` lists them; `TrailerSpec` the same for the trailers.
- `scripts/vehicle/chassis.gd`: the raycast wheels shared by trucks and trailers (suspension,
  anti-roll per axle, tyres on snow, mud and ice, how much a tyre sinks and how its tread bites,
  wheel spin and spray). `Vehicle` extends it with the engine, the drive train, the winch and the
  hitch; `Trailer` with brakes that follow the truck's, a stand, and the hold of a parked trailer.
- The hitch (C, in reach of a trailer's coupler, slow) is a 6DOF joint at the truck's hitch: it
  turns 85 degrees either way, pitches 30, rolls 10; the trailer is swung onto the hitch first so
  nothing jerks; the two do not collide while hitched. Setting upright (R) carries a hitched
  trailer along, straight behind or else swung as it was; if a building or a tree is in the way
  of both, it lets the trailer go where it stands and sets the truck down clear of it and of
  anything else there (ahead or to a side). The tow (T) unhitches the trailer and brings it back
  to the depot, with any trailer left on its side or out in the valley (more than 30 m off).
- Each trailer has a spot of its own by the depot: on the map, that nothing stands on, clear of the
  trucks' spawn and of the other trailers' spots, with a lane ahead of its coupler kept clear for
  the longest truck that tows it to back up into reach. The nearest of a grid about the spawn
  (3 m apart, 63 m to either side, 48 m along), facing the way the truck does there, else across
  it, else back, of the best there is: level and off the roads; fairly level or a gentle slope (up
  to 1.7 m along it, 8 degrees along a semi-trailer) off them; the ground even enough under it for
  all its wheels to touch and, ahead of the coupler, even with it (no more than 0.15 m above it for
  the first 3 m, where a truck's back goes in under a semi-trailer's deck); anywhere clear only if
  none of those is about. Measured with all three in every valley: each finds a level spot off the
  roads, but the semi-trailer in Khutir and the steppe a fairly level one; and each truck backs up
  to its trailer there, steering for the coupler, and hitches it (tests/test_garage.gd). A
  trailer keeps its spot while the spot stays level or a gentle slope and clear: the tow puts it
  back there (the truck being towed off and the trailers it brings back, the one left on the
  spawn among them, are not in its way), and sets the truck down on the spawn.
- The semi truck's frame behind the cab stands lower than its fifth wheel, so it goes in under a
  standing semi-trailer's deck with about 0.3 m to spare. Unhitched (C), a trailer winds its stand
  to the ground (up to 0.8 m further down than its own, or shorter over a hump) and stays as high
  as the hitch held it, as a semi-trailer's legs do: let go in a dip, it does not come down on the
  truck's frame, nor is it thrown up over a hump. Its stand stands on the ground, not on a truck
  backing in under it. The two pass through each other while they touch, but for the truck's
  frame under its hitch once the trailer stands, unless they overlapped when let go (over a
  crest); after that the truck backs into it, not through it. C does not let go a trailer hung
  on the hitch over a crest with most of its wheels in the air (it would see-saw). A truck's
  wheels do not take a trailer for ground: it backs in under a deck, not up onto it. R with no
  trailer hitched sets the truck down clear of any trailer under it.
- `scripts/systems/garage.gd`: what the garage sells and what a job needs. `Profile` keeps the
  rigs bought and the truck picked; `Contracts` tags the jobs, sells, and swaps the truck through
  `scripts/main.gd`, which also parks the trailers bought by the depot.

## Zsuv's additions (rounds 1-3)

- **The gearbox** is Vehicle's: four gears in high range, two in low (shares of the range's top
  speed), auto by default, shifting by the fastest driven tread smoothed over 0.8 s; N for
  manual, `,` and `.` to shift, 0 neutral. A spinning tread runs at most to its gear's top
  speed (Chassis.spin_limit) and in mud loses grip 2.5 m/s past the ground, to 0.75 of it 4 m/s
  on: in the Polissia bog the pickup in 2WD makes 12.0 m in 12 s in manual L1, 8.3 m in auto (L2).
- **Fuel, tuned** (tests/test_fuel.gd): the pickup's tank goes 1.9 km of the forest's road in
  4x4, the scout's 2.4 km; on a flat at a road pace every heavy rig's tank goes about as far as
  the pickup's (3.0-3.4 km): the semi now burns 5.6 times the pickup, the mixer 3.0.
- **Condition:** one knock costs at most 15% (Vehicle.KNOCK_MAX), a flood 25%, rolling over 10%.
- **Upgrades** (Upgrades, the garage's workshop, U): snorkel, chains, long winch (+10 m, 1.3
  times the pull), the 6x6's tank, flatbed and tipper bodies; one load of parts each.
