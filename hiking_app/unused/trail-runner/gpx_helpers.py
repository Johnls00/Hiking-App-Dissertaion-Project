# gpx_helpers.py
from math import sin, cos, asin, sqrt, pi
from xml.dom import minidom

R = 6371000.0  # meters

def _to_rad(x): return x * pi / 180.0

def geo_distance(lat1, lon1, lat2, lon2):
    dlat = _to_rad(lat2 - lat1)
    dlon = _to_rad(lon2 - lon1)
    a = sin(dlat/2)**2 + cos(_to_rad(lat1))*cos(_to_rad(lat2))*sin(dlon/2)**2
    return 2 * R * asin(sqrt(a))

def parse_gpx(xml_text: str):
    """
    Returns dict with:
      trkpts: [{lat,lon,ele?}]
      wpts:   [{lat,lon,ele?,name?,desc?}]
      metaName, metaDesc, gpxDifficulty (str|None), firstPoint {lat,lon}|None
    """
    doc = minidom.parseString(xml_text)

    trkpts = []
    for node in doc.getElementsByTagName("trkpt"):
        lat = node.getAttribute("lat")
        lon = node.getAttribute("lon")
        if not lat or not lon:
            continue
        ele_nodes = node.getElementsByTagName("ele")
        ele = float(ele_nodes[0].firstChild.nodeValue) if (ele_nodes and ele_nodes[0].firstChild) else None
        trkpts.append({"lat": float(lat), "lon": float(lon), "ele": ele})

    wpts = []
    for node in doc.getElementsByTagName("wpt"):
        lat = node.getAttribute("lat")
        lon = node.getAttribute("lon")
        if not lat or not lon:
            continue
        ele_nodes = node.getElementsByTagName("ele")
        name_nodes = node.getElementsByTagName("name")
        desc_nodes = node.getElementsByTagName("desc")
        ele = float(ele_nodes[0].firstChild.nodeValue) if (ele_nodes and ele_nodes[0].firstChild) else None
        name = name_nodes[0].firstChild.nodeValue.strip() if (name_nodes and name_nodes[0].firstChild) else None
        desc = desc_nodes[0].firstChild.nodeValue.strip() if (desc_nodes and desc_nodes[0].firstChild) else None
        wpts.append({"lat": float(lat), "lon": float(lon), "ele": ele, "name": name, "desc": desc})

    def _first_text(tag):
        nodes = doc.getElementsByTagName(tag)
        for n in nodes:
            if n.firstChild and n.firstChild.nodeValue and n.firstChild.nodeValue.strip():
                return n.firstChild.nodeValue.strip()
        return None

    meta_name = _first_text("name") or _first_text("trk") or None
    meta_desc = _first_text("desc") or None

    gpx_difficulty = _first_text("difficulty") or _first_text("type")
    if not gpx_difficulty:
        for ext in doc.getElementsByTagName("extensions"):
            diffs = ext.getElementsByTagName("difficulty")
            if diffs and diffs[0].firstChild:
                gpx_difficulty = diffs[0].firstChild.nodeValue.strip()
                break
    gpx_difficulty = gpx_difficulty.lower() if gpx_difficulty else None

    first_point = {"lat": trkpts[0]["lat"], "lon": trkpts[0]["lon"]} if trkpts else None

    return {
        "trkpts": trkpts,
        "wpts": wpts,
        "metaName": meta_name,
        "metaDesc": meta_desc,
        "gpxDifficulty": gpx_difficulty,
        "firstPoint": first_point,
    }

def total_distance_3d(pts, min_move=0.0):
    total = 0.0
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i+1]
        flat = geo_distance(a["lat"], a["lon"], b["lat"], b["lon"])
        if flat < min_move:
            continue
        ele_diff = abs((a.get("ele") or 0.0) - (b.get("ele") or 0.0))
        total += (flat*flat + ele_diff*ele_diff) ** 0.5
    return total

def elevation_gain(pts, threshold=2.0):
    gain = 0.0
    for i in range(len(pts) - 1):
        d = (pts[i+1].get("ele") or 0.0) - (pts[i].get("ele") or 0.0)
        if d > threshold:
            gain += d
    return gain

def naismith_minutes(distance_m, ascent_m, base_speed_kmh=5.1):
    hours = (distance_m / 1000.0) / base_speed_kmh + (ascent_m / 600.0)
    return int(round(hours * 60))

def classify_difficulty(distance_m, elevation_gain_m):
    km = distance_m / 1000.0
    if km <= 6 and elevation_gain_m <= 200:
        return "easy"
    if km <= 12 and elevation_gain_m <= 600:
        return "moderate"
    return "hard"

def waypoint_distances_nearest_vertex(trkpts, wpts):
    if not trkpts:
        return []
    cum = [0.0]
    for i in range(len(trkpts) - 1):
        cum.append(cum[-1] + geo_distance(
            trkpts[i]["lat"], trkpts[i]["lon"],
            trkpts[i+1]["lat"], trkpts[i+1]["lon"]
        ))
    out = []
    for w in wpts:
        best_idx, best_d = 0, float("inf")
        for i, p in enumerate(trkpts):
            d = geo_distance(w["lat"], w["lon"], p["lat"], p["lon"])
            if d < best_d:
                best_d, best_idx = d, i
        out.append({
            "name": w.get("name") or "Waypoint",
            "desc": w.get("desc") or "",
            "lat": float(w["lat"]),
            "lon": float(w["lon"]),
            "ele": float(w.get("ele") or 0.0),
            "distanceFromStart": cum[best_idx]
        })
    return out