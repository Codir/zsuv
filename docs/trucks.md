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
  nothing jerks; the two do not collide while hitched. The tow (T) and setting upright (R) carry a
  hitched trailer along, straight behind.
- `scripts/systems/garage.gd`: what the garage sells and what a job needs. `Profile` keeps the
  rigs bought and the truck picked; `Contracts` tags the jobs, sells, and swaps the truck through
  `scripts/main.gd`, which also parks the trailers bought on level, clear ground by the depot.
