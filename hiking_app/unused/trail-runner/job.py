# job.py
import os
import sys
import json
import time
import traceback
import requests
from typing import Optional

from google.cloud import firestore, storage
from gpx_helpers import (
    parse_gpx, total_distance_3d, elevation_gain,
    naismith_minutes, classify_difficulty,
    waypoint_distances_nearest_vertex
)

# ---------- Config via env ----------
COLLECTION          = os.getenv("TRAILS_COLLECTION", "trails")
QUERY_STATUS_IN     = os.getenv("QUERY_STATUS_IN", "pending,recompute").split(",")
BATCH_LIMIT         = int(os.getenv("BATCH_LIMIT", "20"))
BASE_SPEED_KMH      = float(os.getenv("BASE_SPEED_KMH", "5.1"))
GCS_BUCKET_OVERRIDE = os.getenv("GCS_BUCKET")  # default: <project>.appspot.com
GEOCODING_API_KEY   = os.environ.get("GEOCODING_API_KEY")
REGION_HINT         = os.getenv("REGION_HINT", "europe-west1")  # just for logging

def reverse_geocode(lat: float, lon: float) -> Optional[str]:
    if not GEOCODING_API_KEY:
        return None
    url = (
        "https://maps.googleapis.com/maps/api/geocode/json"
        f"?latlng={lat},{lon}&key={GEOCODING_API_KEY}"
    )
    try:
        r = requests.get(url, timeout=8)
        r.raise_for_status()
        data = r.json()
        if not data.get("results"):
            return None
        first = data["results"][0]
        parts = {}
        for comp in first.get("address_components", []):
            for t in comp.get("types", []):
                parts[t] = comp.get("long_name", "")
        locality = parts.get("locality") or parts.get("postal_town") or parts.get("sublocality")
        admin = parts.get("administrative_area_level_1") or parts.get("administrative_area_level_2")
        if locality and admin:
            return f"{locality}, {admin}"
        return first.get("formatted_address")
    except Exception:
        return None

def process_one(doc_ref, doc_data, storage_client, project_id):
    trail_id = doc_ref.id
    gpx_path = doc_data.get("gpxPath")
    if not gpx_path:
        raise ValueError("Missing gpxPath")

    # Mark computing (idempotent; job may be retried)
    doc_ref.set({"status": "computing", "errorMessage": None}, merge=True)

    # Bucket
    bucket_name = GCS_BUCKET_OVERRIDE or f"{project_id}.appspot.com"
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(gpx_path)
    gpx_bytes = blob.download_as_bytes()
    xml_text = gpx_bytes.decode("utf-8")

    # Parse + compute
    parsed = parse_gpx(xml_text)
    trkpts = parsed["trkpts"]
    if not trkpts:
        raise ValueError("No trackpoints in GPX.")

    distance_m = round(total_distance_3d(trkpts, 0.0))
    ascent_m = round(elevation_gain(trkpts, 2.0))
    time_min = naismith_minutes(distance_m, ascent_m, BASE_SPEED_KMH)

    difficulty = parsed["gpxDifficulty"] or classify_difficulty(distance_m, ascent_m)

    if parsed["wpts"]:
        waypoints = waypoint_distances_nearest_vertex(trkpts, parsed["wpts"])
    else:
        start = {
            "name": "Start of trail",
            "lat": trkpts[0]["lat"],
            "lon": trkpts[0]["lon"],
            "ele": trkpts[0].get("ele", 0.0),
        }
        waypoints = waypoint_distances_nearest_vertex(trkpts, [start])

    name = parsed["metaName"] or doc_data.get("name") or "Trail"
    description = parsed["metaDesc"] or doc_data.get("description") or ""

    location = doc_data.get("location")
    if parsed["firstPoint"]:
        lat, lon = parsed["firstPoint"]["lat"], parsed["firstPoint"]["lon"]
        nice = reverse_geocode(lat, lon)
        location = nice or f"{lat:.5f},{lon:.5f}"

    # Save
    doc_ref.set({
        "name": name,
        "description": description,
        "difficulty": difficulty,
        "location": location,
        "distanceMeters": distance_m,
        "elevationGainMeters": ascent_m,
        "timeMinutes": time_min,
        "waypoints": waypoints,
        "trackpoints": trkpts,
        "lastComputedAt": firestore.SERVER_TIMESTAMP,
        "status": "ready",
        "errorMessage": None
    }, merge=True)

def main():
    print(f"[trail-runner] region={REGION_HINT} statuses={QUERY_STATUS_IN} limit={BATCH_LIMIT}")
    db = firestore.Client()
    storage_client = storage.Client()

    # Query batch
    q = db.collection(COLLECTION).where("status", "in", QUERY_STATUS_IN).limit(BATCH_LIMIT)
    docs = list(q.stream())

    if not docs:
        print("[trail-runner] nothing to do.")
        return 0

    project_id = db.project
    ok, fail = 0, 0
    for snap in docs:
        try:
            print(f"[trail-runner] processing {snap.reference.path}")
            process_one(snap.reference, snap.to_dict() or {}, storage_client, project_id)
            ok += 1
        except Exception as e:
            fail += 1
            tb = traceback.format_exc()
            print(f"[trail-runner] ERROR {snap.reference.path}: {e}\n{tb}")
            # best-effort mark as error
            try:
                snap.reference.set({"status": "error", "errorMessage": str(e)}, merge=True)
            except Exception:
                pass

    print(f"[trail-runner] done. ok={ok} fail={fail}")
    # Non-zero exit if any failures (helps with retries/alerting)
    return 0 if fail == 0 else 2

if __name__ == "__main__":
    sys.exit(main())