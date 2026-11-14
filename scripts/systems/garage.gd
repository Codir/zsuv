class_name Garage
extends RefCounted
## What the garage at the railhead lists besides the pickup: the trailers on their own, then the
## trucks with the trailer each comes with. It sells nothing (docs/plan.md §6): a rig is driven
## from it once it is the player's.


## [{id, title, gives: the TruckSpec and TrailerSpec ids it adds, truck: its truck or ""}]
static func catalogue() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for t in TrailerSpec.all():
		if t.price > 0:
			items.append({"id": t.id, "title": t.title, "gives": PackedStringArray([t.id]), "truck": ""})
	for s in TruckSpec.all():
		if s.id == "pickup":
			continue
		var gives := PackedStringArray([s.id])
		var title := s.title
		if s.comes_with != "":
			gives.append(s.comes_with)
			title += " + " + TrailerSpec.find(s.comes_with).title.to_lower()
		items.append({"id": s.id, "title": title, "gives": gives, "truck": s.id})
	return items
