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

| Rig | Price | Wheels | Mass | Top speed | Carries | Note |
|---|---|---|---|---|---|---|
| Pickup (today's truck) | owned | 4, 4x2 / 4x4 | 2000 kg | 65 km/h | plain, timed, fragile; tows the trailer | |
| Trailer | $800 | 2 (one axle) | 400 kg | | a double load | hitched to the pickup (or the 6x6) |
| 6x6 | $3500 | 6, 6x4 / 6x6 | 6500 kg | 50 km/h | plain, timed, fragile, heavy | big tyres, deep snow and mud, thirsty |
| Tractor + trailer | $2500 | 4 (big rear) + 4 | 4000 + 1500 kg | 30 km/h | bulk, in the trailer | bog and deep snow, the slowest |
| Semi truck + semi-trailer | $5000 | 6 + 6 | 7000 + 3000 kg | 70 km/h | long, on the semi-trailer | turns wide: a hairpin is hard work |

## How it is built

- `scripts/vehicle/truck_spec.gd`: a rig as data, as `Valley` is a valley: its wheels (mount,
  radius, steered, driven in 2WD), springs, engine, top speeds, fuel, mass, where a load sits,
  its hitch, the look its body is built from, what it carries, the camera's distance and the
  engine's pitch. `TruckSpec.all()` lists them; `TrailerSpec` the same for the trailers.
- `scripts/vehicle/chassis.gd`: the raycast wheels shared by trucks and trailers (suspension,
  anti-roll per axle, tyres on snow, mud and ice, wheel spin and spray). `Vehicle` extends it with
  the engine, the drive train and the winch; `Trailer` with brakes that follow the truck's.
- The hitch is a joint between the truck's hitch point and the trailer's coupler, free to turn
  and to pitch, held in roll, with the two bodies not colliding with each other.
- `Profile` keeps the rigs bought and the truck picked; `Contracts` asks a job's rig of the truck
  in play and its hitched trailer.
