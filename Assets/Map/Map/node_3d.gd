@tool
extends EditorScript

# ===========================================================================
#  REFLUX : GÉNÉRATEUR DE MONDE POUR TERRAIN3D
#
#  Ce qu'il fait, d'un seul clic (Fichier > Exécuter) :
#    - 3 biomes : le Calme (collines, rivières, lacs), le Gel (toundra, crêtes,
#      lac gelé) et la Rouille (mesas, canyons)
#    - la tour du Pendule au nord, sur un grand massif rocheux
#    - des montagnes tout autour de la carte (le joueur ne peut pas sortir)
#    - de l'érosion (thermique + gouttes d'eau) pour un relief naturel
#    - des zones plates pour les lieux importants (village, chapelle, ruines...)
#    - des routes qui relient les lieux, calculées en évitant les pentes
#    - la peinture automatique des textures (selon le biome, la pente, l'altitude)
#    - une teinte de couleur par biome (même avec peu de textures)
#    - un plan d'eau, des marqueurs pour chaque lieu, et une image d'aperçu
#
#  Tout est calculé en parallèle sur tous les coeurs du processeur.
#  Même graine (SEED) = exactement la même carte chez tout le monde.
# ===========================================================================


# ---------------------------------------------------------------------------
#  1. LES RÉGLAGES QUE TU VAS VRAIMENT TOUCHER
# ---------------------------------------------------------------------------

# Taille de la carte : 0 = BROUILLON (1024 m, ~30 s), 1 = NORMAL (2048 m),
# 2 = GRAND (4096 m, plusieurs minutes et beaucoup de mémoire)
const PRESET := 1

# Change ce nombre pour obtenir une carte complètement différente.
const SEED := 1789

# Hauteur des reliefs (1.0 = normal, 1.5 = plus dramatique, 0.7 = plus doux).
const RELIEF := 1.0

# Érosion par gouttes d'eau : plus c'est haut, plus il y a de ravines (et plus c'est long).
# Mets 0.0 pour la désactiver.
const EROSION_EAU := 1.0

# Rivières : 0.0 = aucune, 1.0 = normal, 2.0 = beaucoup
const RIVIERES := 1.0

# Crée le plan d'eau, les marqueurs des lieux et l'image d'aperçu.
const CREER_EAU := true
const CREER_MARQUEURS := true
const CREER_APERCU := true

# Numéros des textures dans le panneau Terrain3D (le slot 0 est le premier).
# Si une texture n'existe pas encore, le script prend une texture de remplacement.
# Textures, dans l'ordre des slots du panneau Terrain3D (le premier est le slot 0).
#   slot 0 : herbe       (Poly Haven : grass_ground)
#   slot 1 : roche       (Poly Haven : aerial_rocks_02)
#   slot 2 : neige       (Poly Haven : snow_02)
#   slot 3 : terre rouge (Poly Haven : red_dirt_mud_01)
#   slot 4 : chemin      (Poly Haven : dirt_floor)
# Mets ici le nombre de slots que tu as VRAIMENT remplis (0 = détection automatique).
# Si tu vois du blanc et du noir, c'est que ce nombre est trop grand.
const NB_TEXTURES := 5

const TEX_CALME := 0     # herbe
const TEX_ROCHE := 1     # roche (pentes raides et altitude)
const TEX_NEIGE := 2     # neige (le Gel)
const TEX_ROUILLE := 3   # terre rouge (la Rouille)
const TEX_CHEMIN := 4    # chemin de terre (les routes)
const TEX_GLACE := 2     # glace du lac gelé : on réutilise la neige


# ---------------------------------------------------------------------------
#  2. LA FORME DU MONDE (modifie si tu veux, sinon laisse tel quel)
# ---------------------------------------------------------------------------

const SIZES := [1024, 2048, 4096]
const HYDRO_DENSITY := [0.08, 0.06, 0.04]   # gouttes par m² selon le preset
const THERMAL_PASSES := 8

const WATER_LEVEL := 4.0

# Positions (u = ouest -1 / est +1, v = nord -1 / sud +1)
const CALME_POS := Vector2(0.0, 0.62)
const GEL_POS := Vector2(-0.60, 0.02)
const ROUILLE_POS := Vector2(0.60, -0.10)
const TOWER_POS := Vector2(0.10, -0.68)
const BIOME_WARP := 0.20       # à quel point les frontières des biomes sont tordues
const BIOME_SHARP := 5.5       # plus grand = frontières plus nettes

# Hauteurs (en mètres, avant RELIEF)
const CALME_BASE := 7.0
const CALME_HILLS := 22.0
const GEL_BASE := 20.0
const GEL_RIDGE := 36.0
const ROU_BASE := 14.0
const ROU_RANGE := 92.0
const ROU_STEPS := 6.0         # nombre d'étages des mesas
const BORDER_RIDGE := 28.0     # crêtes aux frontières entre les biomes
const TOWER_HEIGHT := 112.0
const TOWER_SHARP := 7.5       # plus grand = massif plus étroit
const RIM_START := 0.86        # début du mur de montagnes (0 à 1)
const RIM_BASE := 50.0
const RIM_PEAKS := 75.0

# Rivières
const RIVER_WIDTH := 0.075
const RIVER_BED := 2.2
const RIVER_MAX_ALT := 60.0

# Érosion
const TALUS := 0.62
const TALUS_ROUILLE := 1.7     # les falaises de la Rouille restent raides
const THERMAL_K := 0.22
const HYD_STEPS := 40
const HYD_INERTIA := 0.06
const HYD_CAPACITY := 5.0
const HYD_DEPOSIT := 0.25
const HYD_ERODE := 0.28
const HYD_EVAP := 0.012
const HYD_GRAVITY := 5.0

# Routes
const ROAD_WIDTH := 7.0
const ROAD_BLEND := 14.0
const ROAD_MAX_SLOPE := 0.16
const ROAD_SMOOTH := 40.0
const ROAD_SLOPE_COST := 20.0

const PREVIEW_SIZE := 768


# ---------------------------------------------------------------------------
#  3. LE CODE (pas besoin d'y toucher)
# ---------------------------------------------------------------------------

class Noises:
	var bw_x: FastNoiseLite
	var bw_y: FastNoiseLite
	var base: FastNoiseLite
	var detail: FastNoiseLite
	var ridge: FastNoiseLite
	var micro: FastNoiseLite
	var river: FastNoiseLite
	var color: FastNoiseLite
	var shore: FastNoiseLite


var _size := 0
var _half := 0.0
var _bands := 0
var _rows := 16
var _serial := false          # pour les tests : calcul sans parallélisme
var _mx := Mutex.new()

var _h := PackedFloat32Array()
var _wts := PackedByteArray()          # poids des 3 biomes (Calme, Gel, Rouille)
var _roadw := PackedByteArray()
var _roadh := PackedFloat32Array()
var _out_h: Array = []
var _out_w: Array = []
var _out_c: Array = []
var _out_col: Array = []

var _pois: Array = []                  # dictionnaires des lieux
var _lakes: Array = []
var _pf := PackedFloat32Array()        # lieux : x, z, rayon, fondu, altitude
var _lk := PackedFloat32Array()        # lacs : x, z, rayon, profondeur, gelé
var _tex_flat := PackedInt32Array([0, 0, 0])   # texture plate de chaque biome
var _tex_rock := 0
var _tex_road := 0
var _tex_ice := 0
var _road_alpha := 0.9
var _timings: Array = []
var _t_last := 0


# ------------------------------- OUTILS ------------------------------------

func _make_noise(kind: int, freq: float, octaves: int, seed_off: int, warp: float = 0.0, warp_freq: float = 0.004) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = kind
	n.seed = SEED + seed_off
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.fractal_lacunarity = 2.0
	n.fractal_gain = 0.5
	if warp > 0.0:
		n.domain_warp_enabled = true
		n.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX
		n.domain_warp_amplitude = warp
		n.domain_warp_frequency = warp_freq
		n.domain_warp_fractal_type = FastNoiseLite.DOMAIN_WARP_FRACTAL_PROGRESSIVE
		n.domain_warp_fractal_octaves = 3
	return n


func _make_noises() -> Noises:
	var s := FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var nz := Noises.new()
	nz.bw_x = _make_noise(s, 0.0016, 3, 11)
	nz.bw_y = _make_noise(s, 0.0016, 3, 12)
	nz.base = _make_noise(s, 0.0034, 5, 21, 55.0, 0.0040)
	nz.detail = _make_noise(s, 0.021, 4, 22)
	nz.ridge = _make_noise(s, 0.0030, 5, 23, 70.0, 0.0035)
	nz.micro = _make_noise(s, 0.11, 2, 24)
	nz.river = _make_noise(s, 0.0017, 2, 25, 110.0, 0.0030)
	nz.color = _make_noise(s, 0.0055, 3, 26)
	nz.shore = _make_noise(s, 0.012, 2, 27)
	return nz


func _parallel(count: int, fn: Callable) -> void:
	if _serial:
		for i in count:
			fn.call(i)
		return
	var id := WorkerThreadPool.add_group_task(fn, count, -1, true, "reflux")
	WorkerThreadPool.wait_for_group_task_completion(id)


func _lap(label: String) -> void:
	var now := Time.get_ticks_msec()
	_timings.append([label, (now - _t_last) / 1000.0])
	print("   ", label, " : ", snappedf((now - _t_last) / 1000.0, 0.1), " s")
	_t_last = now


func _px(p: Vector2) -> Vector2:
	return Vector2(_half + p.x * _half, _half + p.y * _half)


func _sample(x: float, y: float) -> float:
	var xi := clampi(int(x), 0, _size - 2)
	var yi := clampi(int(y), 0, _size - 2)
	var fx := clampf(x - xi, 0.0, 1.0)
	var fy := clampf(y - yi, 0.0, 1.0)
	var i := yi * _size + xi
	return lerpf(lerpf(_h[i], _h[i + 1], fx), lerpf(_h[i + _size], _h[i + _size + 1], fx), fy)


func _assemble_f(src: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for b in _bands:
		out.append_array(src[b])
	return out


func _assemble_b(src: Array) -> PackedByteArray:
	var out := PackedByteArray()
	for b in _bands:
		out.append_array(src[b])
	return out


func _make_pois() -> Array:
	return [
		{"key": "village", "name": "Village du départ", "p": Vector2(0.02, 0.80), "r": 45.0, "blend": 55.0},
		{"key": "chapelle", "name": "Chapelle du Calme", "p": Vector2(-0.14, 0.46), "r": 40.0, "blend": 50.0},
		{"key": "gel", "name": "Ruines du Gel", "p": Vector2(-0.60, 0.12), "r": 110.0, "blend": 90.0},
		{"key": "rouille", "name": "Ville de la Rouille", "p": Vector2(0.58, -0.12), "r": 100.0, "blend": 80.0},
		{"key": "tour", "name": "Tour du Pendule", "p": TOWER_POS, "r": 45.0, "blend": 120.0},
	]


func _make_lakes() -> Array:
	return [
		{"name": "Lac du Calme", "p": Vector2(0.30, 0.55), "r": 170.0, "depth": 7.0, "frozen": false},
		{"name": "Lac gelé", "p": Vector2(-0.38, -0.30), "r": 190.0, "depth": 3.0, "frozen": true},
	]


func _roads_links() -> Array:
	return [["village", "chapelle"], ["chapelle", "gel"], ["gel", "rouille"], ["rouille", "tour"]]


func _resolve_texture(wanted: int, fallback: int, tex_count: int) -> int:
	if wanted >= 0 and wanted < tex_count:
		return wanted
	return fallback


# ------------------------- ÉTAPE 1 : RELIEF DE BASE -------------------------

func _stage_base(b: int) -> void:
	var nz := _make_noises()
	var y0 := b * _rows
	var y1 := mini(y0 + _rows, _size)
	var n := (y1 - y0) * _size
	var hh := PackedFloat32Array()
	hh.resize(n)
	var ww := PackedByteArray()
	ww.resize(n * 3)
	var k := 0
	var inv_half := 1.0 / _half
	for y in range(y0, y1):
		var fy := float(y)
		for x in _size:
			var fx := float(x)
			var u := (fx - _half) * inv_half
			var v := (fy - _half) * inv_half

			# --- les biomes (frontières tordues pour paraître naturelles) ---
			var pu := u + nz.bw_x.get_noise_2d(fx, fy) * BIOME_WARP
			var pv := v + nz.bw_y.get_noise_2d(fx, fy) * BIOME_WARP
			var eC := exp(-((pu - CALME_POS.x) * (pu - CALME_POS.x) + (pv - CALME_POS.y) * (pv - CALME_POS.y)) * BIOME_SHARP)
			var eG := exp(-((pu - GEL_POS.x) * (pu - GEL_POS.x) + (pv - GEL_POS.y) * (pv - GEL_POS.y)) * BIOME_SHARP)
			var eR := exp(-((pu - ROUILLE_POS.x) * (pu - ROUILLE_POS.x) + (pv - ROUILLE_POS.y) * (pv - ROUILLE_POS.y)) * BIOME_SHARP)
			var sw := eC + eG + eR + 0.000001
			var wC := eC / sw
			var wG := eG / sw
			var wR := eR / sw

			# --- les bruits ---
			var base := clampf(nz.base.get_noise_2d(fx, fy) * 1.45 * 0.5 + 0.5, 0.0, 1.0)
			var det := nz.detail.get_noise_2d(fx, fy)
			var nr := nz.ridge.get_noise_2d(fx, fy)
			var rg := pow(clampf(1.0 - absf(nr) * 1.7, 0.0, 1.0), 2.0)    # crêtes fines
			var rb := pow(clampf(1.0 - absf(nr) * 1.5, 0.0, 1.0), 1.1)    # crêtes larges (montagnes)

			# --- relief de chaque biome ---
			var hC := CALME_BASE + pow(base, 1.35) * CALME_HILLS + det * 2.2 + rb * rb * 8.0
			var hG := GEL_BASE + pow(base, 1.2) * 26.0 + pow(rb, 1.6) * GEL_RIDGE + det * 3.0
			var tt := (base * 0.62 + rg * 0.38) * ROU_STEPS
			var ft := floorf(tt)
			var terr := (ft + smoothstep(0.62, 0.92, tt - ft)) / ROU_STEPS
			var hR := ROU_BASE + terr * ROU_RANGE + det * 1.2
			var ht := (hC * wC + hG * wG + hR * wR) * RELIEF

			# --- crêtes aux frontières entre biomes ---
			var bd := 1.0 - maxf(wC, maxf(wG, wR))
			ht += smoothstep(0.22, 0.48, bd) * pow(rb, 1.5) * BORDER_RIDGE * RELIEF

			# --- le massif de la tour ---
			var tdx := u - TOWER_POS.x
			var tdy := v - TOWER_POS.y
			var tm := exp(-(tdx * tdx + tdy * tdy) * TOWER_SHARP)
			ht += (tm * TOWER_HEIGHT + tm * rb * 30.0) * RELIEF

			# --- le mur de montagnes autour de la carte ---
			var ds := maxf(absf(u), absf(v))
			var rim := smoothstep(RIM_START, 1.0, ds)
			ht += rim * (RIM_BASE + pow(rb, 1.3) * RIM_PEAKS) * RELIEF + rim * rim * 50.0

			# --- petits cailloux : donne du détail de près ---
			ht += nz.micro.get_noise_2d(fx, fy) * 0.45

			hh[k] = ht
			ww[k * 3] = int(wC * 255.0 + 0.5)
			ww[k * 3 + 1] = int(wG * 255.0 + 0.5)
			ww[k * 3 + 2] = int(wR * 255.0 + 0.5)
			k += 1
	_mx.lock()
	_out_h[b] = hh
	_out_w[b] = ww
	_mx.unlock()


# ------------------- ÉTAPE 2 : ÉROSION THERMIQUE (éboulis) ------------------

func _stage_thermal(b: int, src: PackedFloat32Array) -> void:
	var y0 := b * _rows
	var y1 := mini(y0 + _rows, _size)
	var out := PackedFloat32Array()
	out.resize((y1 - y0) * _size)
	var k := 0
	for y in range(y0, y1):
		for x in _size:
			var i := y * _size + x
			var hc := src[i]
			var tc := TALUS + float(_wts[i * 3 + 2]) * (1.0 / 255.0) * TALUS_ROUILLE
			var delta := 0.0
			for dir in 4:
				var j := -1
				if dir == 0 and x > 0:
					j = i - 1
				elif dir == 1 and x < _size - 1:
					j = i + 1
				elif dir == 2 and y > 0:
					j = i - _size
				elif dir == 3 and y < _size - 1:
					j = i + _size
				if j < 0:
					continue
				var tn := TALUS + float(_wts[j * 3 + 2]) * (1.0 / 255.0) * TALUS_ROUILLE
				var tal := 0.5 * (tc + tn)
				var d := hc - src[j]
				if d > tal:
					delta -= (d - tal) * THERMAL_K
				elif -d > tal:
					delta += (-d - tal) * THERMAL_K
			out[k] = hc + delta
			k += 1
	_mx.lock()
	_out_h[b] = out
	_mx.unlock()


# ---------------- ÉTAPE 3 : ÉROSION PAR GOUTTES D'EAU (ravines) -------------

func _hydraulic(drops: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED * 7 + 3
	var size := _size
	var lim := float(size) - 3.0
	for _d in drops:
		var px := rng.randf_range(2.0, lim)
		var py := rng.randf_range(2.0, lim)
		var dx := 0.0
		var dy := 0.0
		var speed := 1.0
		var water := 1.0
		var sediment := 0.0
		for _s in HYD_STEPS:
			var ix := int(px)
			var iy := int(py)
			var fx := px - ix
			var fy := py - iy
			var i := iy * size + ix
			var h00 := _h[i]
			var h10 := _h[i + 1]
			var h01 := _h[i + size]
			var h11 := _h[i + size + 1]
			var gx := (h10 - h00) * (1.0 - fy) + (h11 - h01) * fy
			var gy := (h01 - h00) * (1.0 - fx) + (h11 - h10) * fx
			dx = dx * HYD_INERTIA - gx * (1.0 - HYD_INERTIA)
			dy = dy * HYD_INERTIA - gy * (1.0 - HYD_INERTIA)
			var l := sqrt(dx * dx + dy * dy)
			if l < 0.000001:
				break
			dx /= l
			dy /= l
			var nx := px + dx
			var ny := py + dy
			if nx < 1.0 or nx > lim or ny < 1.0 or ny > lim:
				break
			var hold := h00 * (1.0 - fx) * (1.0 - fy) + h10 * fx * (1.0 - fy) + h01 * (1.0 - fx) * fy + h11 * fx * fy
			var jx := int(nx)
			var jy := int(ny)
			var gx2 := nx - jx
			var gy2 := ny - jy
			var j := jy * size + jx
			var hnew := _h[j] * (1.0 - gx2) * (1.0 - gy2) + _h[j + 1] * gx2 * (1.0 - gy2) + _h[j + size] * (1.0 - gx2) * gy2 + _h[j + size + 1] * gx2 * gy2
			var dh := hnew - hold
			var cap := maxf(-dh, 0.01) * speed * water * HYD_CAPACITY
			var w00 := (1.0 - fx) * (1.0 - fy)
			var w10 := fx * (1.0 - fy)
			var w01 := (1.0 - fx) * fy
			var w11 := fx * fy
			if sediment > cap or dh > 0.0:
				var dep := minf(dh, sediment) if dh > 0.0 else (sediment - cap) * HYD_DEPOSIT
				sediment -= dep
				_h[i] += dep * w00
				_h[i + 1] += dep * w10
				_h[i + size] += dep * w01
				_h[i + size + 1] += dep * w11
			else:
				var er := minf((cap - sediment) * HYD_ERODE, -dh)
				_h[i] -= er * w00
				_h[i + 1] -= er * w10
				_h[i + size] -= er * w01
				_h[i + size + 1] -= er * w11
				sediment += er
			speed = sqrt(maxf(speed * speed - dh * HYD_GRAVITY, 0.0))
			water *= 1.0 - HYD_EVAP
			px = nx
			py = ny


func _stage_smooth(b: int, src: PackedFloat32Array) -> void:
	var y0 := b * _rows
	var y1 := mini(y0 + _rows, _size)
	var out := PackedFloat32Array()
	out.resize((y1 - y0) * _size)
	var k := 0
	var last := _size - 1
	for y in range(y0, y1):
		var ya := maxi(y - 1, 0) * _size
		var yb := y * _size
		var yc := mini(y + 1, last) * _size
		for x in _size:
			var xa := maxi(x - 1, 0)
			var xc := mini(x + 1, last)
			out[k] = (src[ya + xa] + 2.0 * src[ya + x] + src[ya + xc] + 2.0 * src[yb + xa] + 4.0 * src[yb + x] + 2.0 * src[yb + xc] + src[yc + xa] + 2.0 * src[yc + x] + src[yc + xc]) * 0.0625
			k += 1
	_mx.lock()
	_out_h[b] = out
	_mx.unlock()


# ------- ÉTAPE 4 : RIVIÈRES, LACS ET LIEUX PLATS (village, ruines, tour) -----

func _poi_altitude(p: Vector2, r: float) -> float:
	var c := _px(p)
	var sum := 0.0
	var cnt := 0
	for a in 16:
		var ang := TAU * float(a) / 16.0
		for rr in [0.0, 0.4, 0.8]:
			sum += _sample(c.x + cos(ang) * r * rr, c.y + sin(ang) * r * rr)
			cnt += 1
	return maxf(sum / float(cnt), WATER_LEVEL + 3.0)


func _stage_features(b: int) -> void:
	var nz := _make_noises()
	var y0 := b * _rows
	var y1 := mini(y0 + _rows, _size)
	var out := PackedFloat32Array()
	out.resize((y1 - y0) * _size)
	var k := 0
	var n_lakes := _lk.size() / 5
	var n_pois := _pf.size() / 5
	for y in range(y0, y1):
		var fy := float(y)
		for x in _size:
			var fx := float(x)
			var i := y * _size + x
			var hv := _h[i]
			var wC := float(_wts[i * 3]) * (1.0 / 255.0)
			var wG := float(_wts[i * 3 + 1]) * (1.0 / 255.0)

			# rivières : une vallée douce + un chenal, dans les basses terres du Calme
			if RIVIERES > 0.0:
				var rv := absf(nz.river.get_noise_2d(fx, fy))
				var width := RIVER_WIDTH * RIVIERES
				var low := clampf(wC + 0.15 * wG, 0.0, 1.0) * (1.0 - smoothstep(RIVER_MAX_ALT * 0.5, RIVER_MAX_ALT, hv))
				if low > 0.0:
					var valley := (1.0 - smoothstep(0.0, width * 3.5, rv)) * low
					var chan := (1.0 - smoothstep(0.0, width * 0.55, rv)) * low
					hv = lerpf(hv, WATER_LEVEL + (hv - WATER_LEVEL) * 0.45, valley * 0.85)
					hv = lerpf(hv, minf(hv, WATER_LEVEL - RIVER_BED * 0.7), smoothstep(0.0, 1.0, chan))

			# lacs
			for l in n_lakes:
				var lx := _lk[l * 5]
				var lz := _lk[l * 5 + 1]
				var lr := _lk[l * 5 + 2]
				var d := sqrt((fx - lx) * (fx - lx) + (fy - lz) * (fy - lz)) / lr + nz.shore.get_noise_2d(fx, fy) * 0.34
				if d < 2.0:
					var outer := 1.0 - smoothstep(1.0, 2.0, d)
					var inner := 1.0 - smoothstep(0.55, 1.0, d)
					var shore := WATER_LEVEL + 2.2
					var floor_h := WATER_LEVEL + 0.35 if _lk[l * 5 + 4] > 0.5 else WATER_LEVEL - _lk[l * 5 + 3]
					hv = lerpf(hv, shore, outer * 0.95)
					hv = lerpf(hv, floor_h, inner)

			# lieux plats
			for q in n_pois:
				var r := _pf[q * 5 + 2]
				var bl := _pf[q * 5 + 3]
				var d2 := sqrt((fx - _pf[q * 5]) * (fx - _pf[q * 5]) + (fy - _pf[q * 5 + 1]) * (fy - _pf[q * 5 + 1]))
				d2 += nz.shore.get_noise_2d(fx, fy) * 0.30 * (r + bl)
				if d2 < r + bl:
					var wgt := 1.0 - smoothstep(r * 0.8, r + bl, d2)
					var alt := _pf[q * 5 + 4]
					var keep := smoothstep(r * 0.6, r + bl, d2) * 0.55
					hv = lerpf(hv, alt + (hv - alt) * keep, wgt)

			out[k] = hv
			k += 1
	_mx.lock()
	_out_h[b] = out
	_mx.unlock()


# ------------------------------ ÉTAPE 5 : ROUTES -----------------------------

func _build_roads() -> int:
	_roadw = PackedByteArray()
	_roadw.resize(_size * _size)
	_roadh = PackedFloat32Array()
	_roadh.resize(_size * _size)

	var cell := maxi(4, int(float(_size) / 256.0))
	var n := int(float(_size) / cell)
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, n, n)
	astar.cell_size = Vector2(cell, cell)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.update()
	var cf := float(cell)
	for cy in n:
		for cx in n:
			var wx := (cx + 0.5) * cf
			var wy := (cy + 0.5) * cf
			var hx := _sample(wx + cf, wy) - _sample(wx - cf, wy)
			var hz := _sample(wx, wy + cf) - _sample(wx, wy - cf)
			var slope := sqrt(hx * hx + hz * hz) / (2.0 * cf)
			var cost := 1.0 + slope * ROAD_SLOPE_COST
			var hc := _sample(wx, wy)
			if hc < WATER_LEVEL + 0.2:
				cost += 25.0
			var ds := maxf(absf(wx - _half), absf(wy - _half)) / _half
			if ds > 0.9:
				astar.set_point_solid(Vector2i(cx, cy), true)
			else:
				astar.set_point_weight_scale(Vector2i(cx, cy), cost)

	var by_key := {}
	for p in _pois:
		by_key[p.key] = p

	var roads_done := 0
	for link in _roads_links():
		if not by_key.has(link[0]) or not by_key.has(link[1]):
			continue
		var a: Vector2 = _px(by_key[link[0]].p)
		var bpos: Vector2 = _px(by_key[link[1]].p)
		var ida := Vector2i(clampi(int(a.x / cf), 0, n - 1), clampi(int(a.y / cf), 0, n - 1))
		var idb := Vector2i(clampi(int(bpos.x / cf), 0, n - 1), clampi(int(bpos.y / cf), 0, n - 1))
		var ids: Array[Vector2i] = astar.get_id_path(ida, idb)
		if ids.size() < 2:
			push_warning("Aucune route possible entre " + str(link[0]) + " et " + str(link[1]))
			continue
		var pts := PackedVector2Array()
		pts.append(a)
		for id in ids:
			pts.append(Vector2((id.x + 0.5) * cf, (id.y + 0.5) * cf))
		pts.append(bpos)
		pts = _chaikin(_chaikin(pts))
		var line := _resample(pts, 2.0)
		_stamp_road(line)
		roads_done += 1
	return roads_done


func _chaikin(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array()
	out.append(pts[0])
	for i in range(pts.size() - 1):
		var p0 := pts[i]
		var p1 := pts[i + 1]
		out.append(p0 * 0.75 + p1 * 0.25)
		out.append(p0 * 0.25 + p1 * 0.75)
	out.append(pts[pts.size() - 1])
	return out


func _resample(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.append(pts[0])
	var carry := 0.0
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		if seg < 0.0001:
			continue
		var pos := step - carry
		while pos <= seg:
			out.append(a.lerp(b, pos / seg))
			pos += step
		carry = seg - (pos - step)
	out.append(pts[pts.size() - 1])
	return out


func _stamp_road(line: PackedVector2Array) -> void:
	var count := line.size()
	var prof := PackedFloat32Array()
	prof.resize(count)
	for i in count:
		prof[i] = _sample(line[i].x, line[i].y)
	# lissage du profil de hauteur (la route ne suit pas chaque bosse)
	var win := maxi(2, int(ROAD_SMOOTH / 2.0))
	for _pass in 2:
		var sm := prof.duplicate()
		for i in count:
			var s := 0.0
			var c := 0
			for j in range(maxi(0, i - win), mini(count, i + win + 1)):
				s += prof[j]
				c += 1
			sm[i] = s / float(c)
		sm[0] = prof[0]
		sm[count - 1] = prof[count - 1]
		prof = sm
	# pente maximale
	var maxd := ROAD_MAX_SLOPE * 2.0
	for i in range(1, count):
		prof[i] = clampf(prof[i], prof[i - 1] - maxd, prof[i - 1] + maxd)
	for i in range(count - 2, -1, -1):
		prof[i] = clampf(prof[i], prof[i + 1] - maxd, prof[i + 1] + maxd)

	var rr := ROAD_WIDTH * 0.5 + ROAD_BLEND
	var half_w := ROAD_WIDTH * 0.5
	for i in count:
		var cx := line[i].x
		var cy := line[i].y
		var x0 := maxi(0, int(floor(cx - rr)))
		var x1 := mini(_size - 1, int(ceil(cx + rr)))
		var y0 := maxi(0, int(floor(cy - rr)))
		var y1 := mini(_size - 1, int(ceil(cy + rr)))
		for yy in range(y0, y1 + 1):
			var row := yy * _size
			var dy := yy - cy
			for xx in range(x0, x1 + 1):
				var dx := xx - cx
				var d := sqrt(dx * dx + dy * dy)
				if d < rr:
					var wgt := int((1.0 - smoothstep(half_w, rr, d)) * 255.0 + 0.5)
					if wgt > _roadw[row + xx]:
						_roadw[row + xx] = wgt
						_roadh[row + xx] = prof[i]


func _stage_apply_roads(b: int) -> void:
	var y0 := b * _rows
	var y1 := mini(y0 + _rows, _size)
	var out := PackedFloat32Array()
	out.resize((y1 - y0) * _size)
	var k := 0
	for y in range(y0, y1):
		for x in _size:
			var i := y * _size + x
			var w := float(_roadw[i]) * (1.0 / 255.0)
			out[k] = lerpf(_h[i], _roadh[i], w) if w > 0.0 else _h[i]
			k += 1
	_mx.lock()
	_out_h[b] = out
	_mx.unlock()


# ------- ÉTAPE 6 : TEXTURES PEINTES + COULEURS (control map et color map) ----

func _stage_paint(b: int) -> void:
	var nz := _make_noises()
	var y0 := b * _rows
	var y1 := mini(y0 + _rows, _size)
	var n := (y1 - y0) * _size
	var ctrl := PackedInt32Array()
	ctrl.resize(n)
	var col := PackedByteArray()
	col.resize(n * 4)
	var k := 0
	var last := _size - 1
	var n_lakes := _lk.size() / 5
	var inv := 1.0 / 255.0
	for y in range(y0, y1):
		var fy := float(y)
		for x in _size:
			var fx := float(x)
			var i := y * _size + x
			var hc := _h[i]
			var xl := _h[i - 1] if x > 0 else hc
			var xr := _h[i + 1] if x < last else hc
			var zu := _h[i - _size] if y > 0 else hc
			var zd := _h[i + _size] if y < last else hc
			var sx := (xr - xl) * 0.5
			var sz := (zd - zu) * 0.5
			var slope := sqrt(sx * sx + sz * sz)

			var w0 := float(_wts[i * 3]) * inv
			var w1 := float(_wts[i * 3 + 1]) * inv
			var w2 := float(_wts[i * 3 + 2]) * inv
			var d1 := 0
			var m1 := w0
			if w1 > m1:
				d1 = 1
				m1 = w1
			if w2 > m1:
				d1 = 2
				m1 = w2
			var d2 := 0
			var m2 := -1.0
			if d1 != 0 and w0 > m2:
				d2 = 0
				m2 = w0
			if d1 != 1 and w1 > m2:
				d2 = 1
				m2 = w1
			if d1 != 2 and w2 > m2:
				d2 = 2
				m2 = w2
			var biome_mix := clampf(m2 / (m1 + m2 + 0.00001), 0.0, 0.5)

			# roche : sur les pentes raides et en haute altitude
			var vr := nz.color.get_noise_2d(fx * 3.0, fy * 3.0) * 0.12
			var thr := 0.52 * w0 + 0.60 * w1 + 0.34 * w2 + vr
			var rock := smoothstep(thr, thr + 0.40, slope)
			rock = maxf(rock, smoothstep(105.0, 135.0, hc) * 0.85)

			var base_t := _tex_flat[d1]
			var over_t := _tex_flat[d2]
			var blend := biome_mix
			if rock > blend:
				over_t = _tex_rock
				blend = rock

			# routes
			var road := float(_roadw[i]) * inv
			if road > blend and road > 0.02:
				over_t = _tex_road
				blend = road * _road_alpha

			# lac gelé : glace
			var ice := 0.0
			for l in n_lakes:
				if _lk[l * 5 + 4] > 0.5:
					var d := sqrt((fx - _lk[l * 5]) * (fx - _lk[l * 5]) + (fy - _lk[l * 5 + 1]) * (fy - _lk[l * 5 + 1])) / _lk[l * 5 + 2] + nz.shore.get_noise_2d(fx, fy) * 0.34
					ice = maxf(ice, 1.0 - smoothstep(0.55, 0.85, d))
			if ice > 0.5:
				base_t = _tex_ice
				over_t = _tex_ice
				blend = 0.0

			# fond des rivières et rives : cailloux
			var wet := 1.0 - smoothstep(WATER_LEVEL - 1.0, WATER_LEVEL + 1.2, hc)
			if wet > 0.0 and ice < 0.5 and wet * 0.7 > blend:
				over_t = _tex_rock
				blend = wet * 0.7

			ctrl[k] = ((base_t & 31) << 27) | ((over_t & 31) << 22) | ((int(blend * 255.0 + 0.5) & 255) << 14)

			# couleur : teinte par biome + variation douce (casse la répétition)
			var mv := 0.86 + 0.24 * (nz.color.get_noise_2d(fx, fy) * 0.5 + 0.5)
			var cr := (0.93 * w0 + 0.86 * w1 + 1.00 * w2) * mv
			var cg := (1.00 * w0 + 0.93 * w1 + 0.74 * w2) * mv
			var cb := (0.86 * w0 + 1.00 * w1 + 0.58 * w2) * mv
			if road > 0.05:
				var rt := road * 0.6
				cr = lerpf(cr, 1.0 * mv, rt)
				cg = lerpf(cg, 0.90 * mv, rt)
				cb = lerpf(cb, 0.76 * mv, rt)
			if ice > 0.0:
				cr = lerpf(cr, 0.80, ice)
				cg = lerpf(cg, 0.93, ice)
				cb = lerpf(cb, 1.00, ice)
			var alpha := 0.5 - wet * 0.18 - ice * 0.25
			col[k * 4] = int(clampf(cr, 0.0, 1.0) * 255.0 + 0.5)
			col[k * 4 + 1] = int(clampf(cg, 0.0, 1.0) * 255.0 + 0.5)
			col[k * 4 + 2] = int(clampf(cb, 0.0, 1.0) * 255.0 + 0.5)
			col[k * 4 + 3] = int(clampf(alpha, 0.0, 1.0) * 255.0 + 0.5)
			k += 1
	_mx.lock()
	_out_c[b] = ctrl.to_byte_array()
	_out_col[b] = col
	_mx.unlock()


# ------------------------------ APERÇU (PNG) ---------------------------------

func _make_preview() -> Image:
	var ps := PREVIEW_SIZE
	var img := Image.create_empty(ps, ps, false, Image.FORMAT_RGB8)
	var step := float(_size) / float(ps)
	var cC := Color(0.30, 0.52, 0.22)
	var cG := Color(0.82, 0.90, 0.97)
	var cR := Color(0.74, 0.40, 0.20)
	var light := Vector3(-1.0, 1.4, -1.0).normalized()
	var s2 := int(maxf(1.0, step))
	for py in ps:
		for pxx in ps:
			var x := clampi(int(pxx * step), s2, _size - s2 - 1)
			var y := clampi(int(py * step), s2, _size - s2 - 1)
			var i := y * _size + x
			var hc := _h[i]
			var w0 := float(_wts[i * 3]) / 255.0
			var w1 := float(_wts[i * 3 + 1]) / 255.0
			var w2 := float(_wts[i * 3 + 2]) / 255.0
			var c := cC * w0 + cG * w1 + cR * w2
			var sx := (_h[i + s2] - _h[i - s2]) / (2.0 * s2)
			var sz := (_h[i + s2 * _size] - _h[i - s2 * _size]) / (2.0 * s2)
			var slope := sqrt(sx * sx + sz * sz)
			c = c.lerp(Color(0.45, 0.42, 0.40), smoothstep(0.5, 1.0, slope))
			c = c.lerp(Color(0.96, 0.96, 0.98), smoothstep(120.0, 190.0, hc) * 0.75)
			var nrm := Vector3(-sx * 2.2, 1.0, -sz * 2.2).normalized()
			var shade := clampf(0.35 + 0.85 * maxf(0.0, nrm.dot(light)), 0.25, 1.15)
			c = Color(c.r * shade, c.g * shade, c.b * shade)
			if hc < WATER_LEVEL:
				c = Color(0.10, 0.30, 0.52)
			for l in range(_lk.size() / 5):
				if _lk[l * 5 + 4] > 0.5:
					var dd := sqrt((x - _lk[l * 5]) * (x - _lk[l * 5]) + (y - _lk[l * 5 + 1]) * (y - _lk[l * 5 + 1])) / _lk[l * 5 + 2]
					if dd < 0.62:
						c = c.lerp(Color(0.62, 0.86, 0.95), 0.8)
			var rw := float(_roadw[i]) / 255.0
			if rw > 0.4:
				c = c.lerp(Color(0.66, 0.54, 0.34), 0.85)
			img.set_pixel(pxx, py, c)
	# les lieux : un rond rouge cerclé de blanc
	for p in _pois:
		var cp := _px(p.p) / step
		for dy in range(-7, 8):
			for dx in range(-7, 8):
				var dd := sqrt(float(dx * dx + dy * dy))
				var ix := int(cp.x) + dx
				var iy := int(cp.y) + dy
				if ix < 0 or iy < 0 or ix >= ps or iy >= ps:
					continue
				if dd <= 4.0:
					img.set_pixel(ix, iy, Color(0.9, 0.1, 0.1))
				elif dd <= 6.5:
					img.set_pixel(ix, iy, Color(1, 1, 1))
	return img


# ------------------------------- CHEF D'ORCHESTRE ----------------------------

func _generate(tex_count: int) -> Dictionary:
	_t_last = Time.get_ticks_msec()
	var t_start := _t_last
	_timings = []
	_size = SIZES[PRESET]
	_half = _size * 0.5
	_rows = 16
	_bands = int(float(_size) / _rows)
	_pois = _make_pois()
	_lakes = _make_lakes()

	# textures disponibles (avec remplacement automatique)
	var rock := _resolve_texture(TEX_ROCHE, 0, tex_count)
	var snow := _resolve_texture(TEX_NEIGE, rock, tex_count)
	var red := _resolve_texture(TEX_ROUILLE, rock, tex_count)
	_tex_rock = rock
	_tex_flat = PackedInt32Array([_resolve_texture(TEX_CALME, 0, tex_count), snow, red])
	_tex_road = _resolve_texture(TEX_CHEMIN, rock, tex_count)
	_road_alpha = 0.9 if TEX_CHEMIN < tex_count else 0.5
	_tex_ice = _resolve_texture(TEX_GLACE, snow, tex_count)

	print("[1/7] Relief de base (", _size, " x ", _size, " m, biomes, montagnes)...")
	_out_h = []
	_out_h.resize(_bands)
	_out_w = []
	_out_w.resize(_bands)
	_parallel(_bands, func(b: int): _stage_base(b))
	_h = _assemble_f(_out_h)
	_wts = _assemble_b(_out_w)
	_lap("relief de base")

	print("[2/7] Érosion thermique (éboulis)...")
	for _p in THERMAL_PASSES:
		_out_h = []
		_out_h.resize(_bands)
		var src := _h
		_parallel(_bands, func(b: int): _stage_thermal(b, src))
		_h = _assemble_f(_out_h)
	_lap("érosion thermique")

	var drops := int(float(_size) * float(_size) * float(HYDRO_DENSITY[PRESET]) * EROSION_EAU)
	if drops > 0:
		print("[3/7] Érosion par gouttes d'eau (", drops, " gouttes)...")
		_hydraulic(drops)
		_lap("érosion par gouttes")
	_out_h = []
	_out_h.resize(_bands)
	var src2 := _h
	_parallel(_bands, func(b: int): _stage_smooth(b, src2))
	_h = _assemble_f(_out_h)

	print("[4/7] Rivières, lacs et lieux plats...")
	_pf = PackedFloat32Array()
	for p in _pois:
		var c := _px(p.p)
		var alt := _poi_altitude(p.p, p.r)
		p["alt"] = alt
		_pf.append_array(PackedFloat32Array([c.x, c.y, p.r, p.blend, alt]))
	_lk = PackedFloat32Array()
	for l in _lakes:
		var c2 := _px(l.p)
		_lk.append_array(PackedFloat32Array([c2.x, c2.y, l.r, l.depth, 1.0 if l.frozen else 0.0]))
	_out_h = []
	_out_h.resize(_bands)
	_parallel(_bands, func(b: int): _stage_features(b))
	_h = _assemble_f(_out_h)
	_lap("rivières, lacs, lieux")

	print("[5/7] Routes entre les lieux...")
	var roads := _build_roads()
	_out_h = []
	_out_h.resize(_bands)
	_parallel(_bands, func(b: int): _stage_apply_roads(b))
	_h = _assemble_f(_out_h)
	_lap("routes (" + str(roads) + ")")

	print("[6/7] Peinture des textures et des couleurs...")
	_out_c = []
	_out_c.resize(_bands)
	_out_col = []
	_out_col.resize(_bands)
	_parallel(_bands, func(b: int): _stage_paint(b))
	var ctrl_bytes := _assemble_b(_out_c)
	var col_bytes := _assemble_b(_out_col)
	_lap("textures et couleurs")

	print("[7/7] Préparation des images...")
	var res := {}
	res["height"] = Image.create_from_data(_size, _size, false, Image.FORMAT_RF, _h.to_byte_array())
	res["control"] = Image.create_from_data(_size, _size, false, Image.FORMAT_RF, ctrl_bytes)
	res["color"] = Image.create_from_data(_size, _size, false, Image.FORMAT_RGBA8, col_bytes)
	if CREER_APERCU:
		res["preview"] = _make_preview()
	var hmin := 1.0e9
	var hmax := -1.0e9
	for v in _h:
		hmin = minf(hmin, v)
		hmax = maxf(hmax, v)
	res["min"] = hmin
	res["max"] = hmax
	res["size"] = _size
	res["pois"] = _pois
	res["lakes"] = _lakes
	res["roads"] = roads
	res["seconds"] = (Time.get_ticks_msec() - t_start) / 1000.0
	_lap("images")
	return res


# ----------------------- BRANCHEMENT SUR L'ÉDITEUR GODOT ---------------------

func _find_terrain(node: Node) -> Node:
	if node.get_class() == "Terrain3D":
		return node
	for c in node.get_children():
		var r := _find_terrain(c)
		if r != null:
			return r
	return null


func _clear_children(parent: Node) -> void:
	for c in parent.get_children():
		parent.remove_child(c)
		c.queue_free()


func _run() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		push_error("Ouvre d'abord la scène qui contient ton Terrain3D (onglet 3D), puis relance.")
		return
	var terrain = _find_terrain(root)
	if terrain == null:
		push_error("Aucun nœud Terrain3D trouvé dans la scène.")
		return

	var tex_count := 0
	if terrain.assets != null:
		tex_count = terrain.assets.get_texture_count()
	if NB_TEXTURES > 0:
		tex_count = NB_TEXTURES
	print("Textures utilisées par le script : ", tex_count)
	var region_size: int = terrain.region_size
	var vspacing: float = terrain.vertex_spacing
	var size: int = SIZES[PRESET]
	if size % region_size != 0 or size > region_size * 32:
		push_error("La taille " + str(size) + " ne convient pas à ta region_size (" + str(region_size) + ").")
		return

	print("=== REFLUX : génération du monde (", size, " m, ", tex_count, " textures détectées) ===")
	print("Godot va sembler figé pendant la génération : c'est normal, attends la fin.")
	var res := _generate(tex_count)

	# on efface les anciennes régions, puis on envoie la nouvelle carte
	var data = terrain.data
	if data.has_method("get_regions_all"):
		var old: Dictionary = data.get_regions_all()
		for loc in old.keys():
			data.remove_regionl(loc, false)
	var images: Array[Image] = []
	images.resize(3)
	images[0] = res["height"]
	images[1] = res["control"]
	images[2] = res["color"]
	var origin := -float(size) * 0.5 * vspacing
	data.import_images(images, Vector3(origin, 0.0, origin), 0.0, 1.0)

	var half := float(size) * 0.5
	if CREER_EAU:
		_make_water(root, size * vspacing)
	if CREER_MARQUEURS:
		_make_markers(root, res["pois"], half * vspacing)
	if CREER_APERCU:
		var path := "res://reflux_apercu_carte.png"
		res["preview"].save_png(path)
		print("Image d'aperçu : ", path, " (rond rouge = les lieux)")

	print("--------------------------------------------------")
	print("Terminé en ", snappedf(res["seconds"], 0.1), " secondes. Altitude : ", snappedf(res["min"], 0.1), " m à ", snappedf(res["max"], 0.1), " m.")
	print("Carte centrée sur (0, 0). Nord = -Z, Est = +X. Lieux (x, z, altitude) :")
	for p in res["pois"]:
		print("   ", p.name, " : (", int(p.p.x * half * vspacing), ", ", int(p.p.y * half * vspacing), ", ", snappedf(p.alt, 0.1), ")")
	print("Fais Ctrl+S pour enregistrer le terrain.")


func _make_water(root: Node, span: float) -> void:
	var w := root.find_child("Eau", true, false) as MeshInstance3D
	if w == null:
		w = MeshInstance3D.new()
		w.name = "Eau"
		root.add_child(w)
		w.owner = root
	var pm := PlaneMesh.new()
	pm.size = Vector2(span, span)
	w.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.28, 0.38, 0.74)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.06
	mat.metallic = 0.1
	w.material_override = mat
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.position = Vector3(0.0, WATER_LEVEL, 0.0)


func _make_markers(root: Node, pois: Array, half: float) -> void:
	var holder := root.find_child("Lieux", true, false) as Node3D
	if holder == null:
		holder = Node3D.new()
		holder.name = "Lieux"
		root.add_child(holder)
		holder.owner = root
	_clear_children(holder)
	for p in pois:
		var m := Marker3D.new()
		m.name = "Lieu_" + str(p.key)
		holder.add_child(m)
		m.owner = root
		m.position = Vector3(p.p.x * half, p.alt, p.p.y * half)
