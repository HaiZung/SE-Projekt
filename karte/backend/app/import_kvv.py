import json
from pathlib import Path
import asyncio
from app.db import db

ROOT = Path(__file__).resolve().parents[2]  # .../karte
STOPS_FILE = ROOT / "KVV_Haltestellen_v2.json"

async def import_stops():
    data = json.loads(STOPS_FILE.read_text(encoding="utf-8"))

    docs = []
    for s in data:
        pos = s.get("coordPositionWGS84") or {}
        if "lat" not in pos or "long" not in pos:
            continue
        lat = float(pos["lat"])
        lon = float(pos["long"])

        docs.append({
            "name": s.get("name"),
            "triasID": s.get("triasID"),
            "triasName": s.get("triasName"),
            "location": {"type": "Point", "coordinates": [lon, lat]},
        })

    await db.stops.delete_many({})
    if docs:
        await db.stops.insert_many(docs)
    await db.stops.create_index([("location", "2dsphere")])

    print(f"Imported stops: {len(docs)}")

async def main():
    await import_stops()

if __name__ == "__main__":
    asyncio.run(main())
