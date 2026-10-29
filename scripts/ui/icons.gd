class_name Icons
extends RefCounted
## 12x12 pixel icons for the valleys screen, drawn from the rows below (one character a pixel, "."
## clear): a place by its kind, a peak of difficulty, the sky and the season.

const SIZE := 12
const PALETTE := {
	"#": Color(0.1, 0.1, 0.12), "w": Color(0.95, 0.95, 0.92), "r": Color(0.86, 0.2, 0.13),
	"o": Color(0.96, 0.56, 0.16), "y": Color(1.0, 0.85, 0.26), "g": Color(0.3, 0.64, 0.28),
	"d": Color(0.14, 0.4, 0.2), "b": Color(0.6, 0.38, 0.2), "n": Color(0.38, 0.24, 0.13),
	"s": Color(0.64, 0.64, 0.62), "k": Color(0.32, 0.32, 0.35), "u": Color(0.28, 0.48, 0.84),
	"l": Color(0.62, 0.82, 0.96), "p": Color(0.56, 0.26, 0.6), "c": Color(0.92, 0.85, 0.66),
}

const PLACES := {
	"depot": [
		"............",
		"..########..",
		"..#rrrrrr#..",
		"..#rwwwwr#.#",
		"..#rwwwwr#.#",
		"..#rrrrrr#.#",
		"..#rrrrrr##.",
		"..#rrrrrr#..",
		"..#rrrrrr#..",
		"..#rrrrrr#..",
		".##########.",
		"............"],
	"station": [
		"............",
		".kk.........",
		".kk...gggg..",
		".kkggggggg..",
		".gggggggggg.",
		".gggyyggggg.",
		".gggggggggg.",
		"..k.k..k.k..",
		".kkkkkkkkkk.",
		".k.k.k.k.k.k",
		"............",
		"............"],
	"house": [
		".....##.....",
		"....#RR#....",
		"...#RRRR#...",
		"..#RRRRRR#..",
		".#RRRRRRRR#.",
		"..#WWWWWW#..",
		"..#WyyWnn#..",
		"..#WyyWnn#..",
		"..#WWWWnn#..",
		"..########..",
		"............",
		"............"],
	"sawmill": [
		"....####....",
		"..##ssss##..",
		".#ss#ss#ss#.",
		".#sss##sss#.",
		"#ssss##ssss#",
		"#ss##..##ss#",
		"#ss##..##ss#",
		"#ssss##ssss#",
		".#sss##sss#.",
		".#ss#ss#ss#.",
		"..##ssss##..",
		"....####...."],
	"radio_tower": [
		".r...##...r.",
		"r.r.#rr#.r.r",
		".r..#ss#..r.",
		"....#ss#....",
		"....#rr#....",
		"...#ssss#...",
		"...#ssss#...",
		"...#rrrr#...",
		"..#ssssss#..",
		"..#ssssss#..",
		".#rrrrrrrr#.",
		".##########."],
	"elevator": [
		"....####....",
		"....#ss#....",
		".####ss####.",
		"#ssss##ssss#",
		"#ssss##ssss#",
		"#ssss##ssss#",
		"#ssss##ssss#",
		"#ssss##ssss#",
		"#ssss##ssss#",
		"#ssss##ssss#",
		"############",
		"............"],
	"sheepfold": [
		"............",
		"............",
		"...wwwww....",
		"..wwwwwww##.",
		".wwwwwwww#k#",
		".wwwwwwww###",
		".wwwwwwww#..",
		"..wwwwwww...",
		"...#.#.#.#..",
		"...#.#.#.#..",
		"............",
		"............"],
	"wind_farm": [
		".....w......",
		".....w......",
		".....w......",
		".....ww.....",
		"....wkwwwww.",
		"...w.w......",
		"..w..w......",
		".w...w......",
		".....w......",
		".....w......",
		".....w......",
		"....www....."],
	"winery": [
		"...g........",
		"..gpp.......",
		"..ppppp.....",
		"...ppp......",
		"....p.......",
		"..########..",
		".#bnbbbbnb#.",
		"#bbnbbbbnbb#",
		"#ssssssssss#",
		"#bbnbbbbnbb#",
		".#bnbbbbnb#.",
		"..########.."],
	"castle": [
		"s.s......s.s",
		"sss......sss",
		"sss.s..s.sss",
		"ssssssssssss",
		"ssksssssskss",
		"ssssssssssss",
		"sssss##sssss",
		"ssss#nn#ssss",
		"ssss#nn#ssss",
		"ssss#nn#ssss",
		"ssss#nn#ssss",
		"############"],
	"wooden_church": [
		".....y......",
		"....yyy.....",
		".....y......",
		"....#n#.....",
		"...#nnn#....",
		"....bbb.....",
		"..#nnnnn#...",
		"...bbbbb....",
		".#nnnnnnn#..",
		"..bbbbbbb...",
		"..bbbnbbb...",
		"..bbbnbbb..."],
	"village_church": [
		".....y......",
		"....yyy.....",
		".....y......",
		"....uuu.....",
		"...uuuuu....",
		"...uuuuu....",
		"...wwwww....",
		"..wwwwwww...",
		"..wwwkwww...",
		".wwwwkwwww..",
		".wwwwkwwww..",
		".wwwwwwwww.."],
	"fish_farm": [
		"............",
		"............",
		"............",
		"...llll...l.",
		"..llllll.ll.",
		".lkllllllll.",
		".llllllllll.",
		"..llllll.ll.",
		"...llll...l.",
		"............",
		"uuuuuuuuuuuu",
		".u.u.u.u.u.u"],
	"peat_works": [
		"............",
		".......oo...",
		"......o..o..",
		".....o....o.",
		".oooo.....k.",
		".ooyo....kk.",
		".oooo.......",
		"kkkkkk......",
		"k#k#k#......",
		"kkkkkk......",
		"nnnnnnnnnnnn",
		"nnnnnnnnnnnn"],
	"forestry": [
		"..d......k..",
		".ddd....kkk.",
		"..d.....k.k.",
		".ddd....k.k.",
		"ddddd...k.k.",
		".ddd....k.k.",
		"ddddddd.k.k.",
		".ddddd..k.k.",
		"ddddddd.k.k.",
		"...n....k.k.",
		"...n...kk.kk",
		"gggggggggggg"],
	"apiary": [
		"............",
		"....yyyy....",
		"...y####y...",
		"..yyyyyyyy..",
		"..########..",
		"..yyyyyyyy..",
		"..########..",
		"..yyykyyyy..",
		"..########..",
		"..yyyyyyyy..",
		"...n....n...",
		"...n....n..."],
	"lighthouse": [
		"....yyyy....",
		".y..#yy#..y.",
		"....####....",
		"....#ww#....",
		"....#rr#....",
		"...#wwww#...",
		"...#rrrr#...",
		"...#wwww#...",
		"..#rrrrrr#..",
		"..#wwwwww#..",
		"uu#rrrrrr#uu",
		"uuuuuuuuuuuu"],
	"koliba": [
		".......k....",
		"........k...",
		".......k....",
		".....#ww#...",
		"....#wwww#..",
		"...#wwwwww#.",
		"..#wwwwwwww#",
		".#wwwwwwwwww",
		"..#nnnnnnn#.",
		"..#nyynnnn#.",
		"..#nyynnnn#.",
		"..#########."],
	"weather_station": [
		".k...k...k..",
		".kkkkkkkkk..",
		".....k......",
		".....k......",
		".....k......",
		".....k......",
		"...wwwww....",
		"..wwwwwww...",
		"..wwwwwww...",
		".#wwwwwww#..",
		".#wwwwwww#..",
		".#########.."],
	"kurgan_dig": [
		"........u...",
		"........uu..",
		"........k...",
		"........k...",
		"....bbbbk...",
		"..bbbbbbbbb.",
		".bbbbnnbbbbb",
		"bbbbbnnbbbbb",
		"bbbbbbbbbbbb",
		"............",
		".ss..ss..ss.",
		".ss..ss..ss."],
	"pump_room": [
		".....y......",
		"...ggggg....",
		"..ggggggg...",
		".ggggggggg..",
		".wwwwwwwww..",
		"..w.w.w.w...",
		"..w.wlw.w...",
		"..w.wlw.w...",
		"..w.lll.w...",
		".wwwwwwwww..",
		"wwwwwwwwwww.",
		"............"],
	"rescue_base": [
		"............",
		"..########..",
		".#wwwwwwww#.",
		".#wwwrrwww#.",
		".#wwwrrwww#.",
		".#wrrrrrrw#.",
		".#wrrrrrrw#.",
		".#wwwrrwww#.",
		".#wwwrrwww#.",
		".#wwwwwwww#.",
		"..########..",
		"............"],
}

const PEAK := [
	"............",
	"............",
	".....w......",
	"....www.....",
	"....XXX.....",
	"...XXXXX....",
	"..XXXXXXX...",
	"..XXXXXXX...",
	".XXXXXXXXX..",
	"XXXXXXXXXXX.",
	"............",
	"............"]

const SKIES := {
	"sun": [
		".....y......",
		"..y..y..y...",
		"...yyyyy....",
		"..yyyyyyy...",
		"yyyyyyyyyyy.",
		"..yyyyyyy...",
		"...yyyyy....",
		"..y..y..y...",
		".....y......"],
	"dusk": [
		"............",
		"............",
		"............",
		".....o......",
		"..o..o..o...",
		"...ooooo....",
		"..ooooooo...",
		"oooooooooooo",
		"kkkkkkkkkkkk",
		".kkkkkkkkkk."],
	"moon": [
		"............",
		"....yyy.....",
		"...yyy......",
		"..yyy.......",
		"..yyy.......",
		"..yyy.......",
		"..yyyy......",
		"...yyyyyy...",
		"....yyyy...."],
	"cloud": [
		"............",
		"............",
		"....www.....",
		"...wwwww.ww.",
		".wwwwwwwwwww",
		"wwwwwwwwwwww",
		"wwwwwwwwwwww",
		".wwwwwwwwww."],
	"fog": [
		"............",
		".ssssssss...",
		"............",
		"...sssssssss",
		"............",
		"ssssssss....",
		"............",
		"..ssssssssss"],
	"snow": [
		".....w......",
		"...w.w.w....",
		"....www.....",
		".w..www..w..",
		"..wwwwwww...",
		".w..www..w..",
		"....www.....",
		"...w.w.w....",
		".....w......"],
	"rain": [
		"....www.....",
		"..wwwwwww...",
		".wwwwwwwww..",
		"..wwwwwww...",
		"............",
		"..l...l...l.",
		".l...l...l..",
		"............",
		"...l...l....",
		"..l...l....."],
	"wind": [
		"............",
		".wwwwwww....",
		"........w...",
		".wwwwwwww...",
		"............",
		"wwwwwwwwww..",
		"..........w.",
		".wwwwwwwww.."],
	"winter": [
		".....w......",
		"....wdw.....",
		"...wdddw....",
		"....ddd.....",
		"...wddddw...",
		"..ddddddd...",
		"..wdddddw...",
		".ddddddddd..",
		".....n......",
		".....n......"],
	"spring": [
		"............",
		"....yyy.....",
		"...yy.yy....",
		"....yyy.....",
		".....g......",
		"..gg.g......",
		"...ggg.gg...",
		".....ggg....",
		".....g......",
		"..nnnnnnn..."],
	"summer": [
		"....rrrr....",
		"..rrwwrrww..",
		".rwwrrwwrrw.",
		"......n.....",
		"......n.....",
		"......n.....",
		"......n.....",
		"cccccccccccc"],
	"autumn": [
		".....o......",
		"....oro.....",
		".o..oro..o..",
		".oo.oro.oo..",
		"..oooroooo..",
		".ooooroooo..",
		"..ooorooo...",
		"....oro.....",
		".....n......",
		"....n.......",
		"...n........"],
}

static var _cache := {}


## A place's icon by its kind (the world builder's), the depot's pump for any depot.
static func place(kind: String) -> Texture2D:
	match kind:
		"depot", "yard":
			return _icon("depot", PLACES.depot)
		"khutir":
			return _icon("khutir", PLACES.house, {"R": "b", "W": "c"})
		"village_edge":
			return _icon("village_edge", PLACES.house, {"R": "u", "W": "w"})
	return _icon(kind, PLACES.get(kind, PLACES.house), {"R": "r", "W": "w"})


## A peak, lit for each step of difficulty and dark for the rest.
static func peak(lit: bool) -> Texture2D:
	return _icon("peak_%s" % lit, PEAK, {"X": "o" if lit else "k"})


## The icons of a sky: the light (sun, dusk, moon, cloud) and what is in the air (fog, snow,
## rain, wind), after the season when with_season.
static func sky(w: Weather, season: String, with_season := false) -> Array[Texture2D]:
	var names: Array[String] = []
	if with_season:
		names.append(season)
	if w.night:
		names.append("moon")
	elif w.sun_energy >= 0.8:
		names.append("sun")
	elif w.name.contains("dusk"):
		names.append("dusk")
	else:
		names.append("cloud")
	if w.fog_density >= 0.025 and w.fall == "none":
		names.append("fog")
	if w.fall != "none":
		names.append(w.fall)
	if w.wind > 1.5:
		names.append("wind")
	var out: Array[Texture2D] = []
	for n in names:
		out.append(_icon(n, SKIES[n]))
	return out


static func _icon(key: String, rows: Array, recolor := {}) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in mini(rows.size(), SIZE):
		var row: String = rows[y]
		for x in mini(row.length(), SIZE):
			var ch := row[x]
			ch = recolor.get(ch, ch)
			if PALETTE.has(ch):
				img.set_pixel(x, y, PALETTE[ch])
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex
