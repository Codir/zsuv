class_name Garage
extends RefCounted
## What the garage at a depot sells, cheapest first: a trailer on its own, or a truck with the
## trailer it comes with, each once, from the wallet the valleys are bought from; and what a job
## needs of the rig in play (docs/trucks.md). The pickup is everyone's from the start.


## [{id, title, price, gives: the TruckSpec and TrailerSpec ids it adds, truck: its truck or ""}]
static func catalogue() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for t in TrailerSpec.all():
		if t.price > 0:
			items.append({"id": t.id, "title": t.title, "price": t.price, "gives": PackedStringArray([t.id]), "truck": ""})
	for s in TruckSpec.all():
		if s.price > 0:
			var gives := PackedStringArray([s.id])
			var title := s.title
			if s.comes_with != "":
				gives.append(s.comes_with)
				title += " + " + TrailerSpec.find(s.comes_with).title.to_lower()
			items.append({"id": s.id, "title": title, "price": s.price, "gives": gives, "truck": s.id})
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.price < b.price)
	return items


## The trailer a kind of load goes in ("" for a load on the truck's own bed). A double load goes
## half on the bed, half in the trailer.
static func trailer_for(kind: String) -> String:
	for t in TrailerSpec.all():
		if t.cargo_mass.has(kind):
			return t.id
	return ""


## The trucks that can take a job of kind: the ones that carry it on their bed, tow the trailer
## it goes in (and, for a double load, carry the other half), or, for a stuck car, any.
static func trucks_for(kind: String) -> Array[TruckSpec]:
	var out: Array[TruckSpec] = []
	var trailer := trailer_for(kind)
	for s in TruckSpec.all():
		var ok := true
		if kind == "stuck":
			ok = true
		elif trailer == "":
			ok = s.cargo_mass.has(kind)
		else:
			ok = trailer in s.tows and (kind != "double" or s.cargo_mass.has("plain"))
		if ok:
			out.append(s)
	return out
