from fastapi import FastAPI, Body
from db import db, init_db
from typing import Dict, Any

app = FastAPI(title="Karte Backend")

@app.on_event("startup")
async def startup_event():
    await init_db()

def serialize(doc):
    doc.pop("_id", None)
    return doc

# --- GET ENDPOINTS ---
@app.get("/api/health")
async def health():
    await db.command("ping")
    return {"ok": True, "db": db.name}

@app.get("/robotid")
async def get_robotid():
    docs = await db.RobotID.find({}).to_list(length=100)
    return [serialize(d) for d in docs]

@app.get("/packages")
async def get_packages():
    docs = await db.Packages.find({}).to_list(length=100)
    return [serialize(d) for d in docs]

@app.get("/robotstates")
async def get_robotstates():
    docs = await db.Robotstates.find({}).to_list(length=100)
    return [serialize(d) for d in docs]

@app.get("/stations")
async def get_stations():
    docs = await db.Stations.find({}).to_list(length=100)
    return [serialize(d) for d in docs]

@app.get("/trainid")
async def get_trainid():
    docs = await db.TrainID.find({}).to_list(length=100)
    return [serialize(d) for d in docs]

# --- POST ENDPOINTS ---

@app.post("/robotid")
async def add_robotid(data: dict = Body(...)):
    await db.RobotID.insert_one(data)
    return {"status": "success", "data": serialize(data)}

@app.post("/packages")
async def add_package(data: dict = Body(...)):
    await db.Packages.insert_one(data)
    return {"status": "success", "data": serialize(data)}

@app.post("/robotstates")
async def add_robotstate(data: dict = Body(...)):
    await db.Robotstates.insert_one(data)
    return {"status": "success", "data": serialize(data)}

@app.post("/stations")
async def add_station(data: dict = Body(...)):
    await db.Stations.insert_one(data)
    return {"status": "success", "data": serialize(data)}

@app.post("/trainid")
async def add_trainid(data: dict = Body(...)):
    await db.TrainID.insert_one(data)
    return {"status": "success", "data": serialize(data)}

# --- Startup Event ---
@app.on_event("startup")
async def startup_event():
    await init_db()  # Reset der Roboterstatus + Batterie

@app.put("/robotstates")
async def update_robotstate(data: dict = Body(...)):
    rid = data.get("roboter_id")
    new_status = data.get("status")
    new_battery = data.get("batterie")
    
    if rid is None:
        return {"status": "error", "message": "roboter_id is required"}

    # Build the update dict
    update_dict = {}
    if new_status is not None:
        update_dict["status"] = new_status
    if new_battery is not None:
        update_dict["batterie"] = new_battery

    if not update_dict:
        return {"status": "error", "message": "No valid fields to update"}

    # Update the document
    result = await db.Robotstates.update_one(
        {"roboter_id": rid},
        {"$set": update_dict}
    )

    if result.matched_count == 0:
        return {"status": "error", "message": f"No robot found with roboter_id {rid}"}

    return {
        "status": "success",
        "updated_roboter_id": rid,
        "updated_fields": update_dict
    }

# --- PlannedRoutes Endpoints ---
# Simulation

@app.get("/plannedroutes")
async def get_plannedroutes():
    docs = await db.PlannedRoutes.find({}).to_list(length=200)
    return [serialize(d) for d in docs]

@app.post("/plannedroutes")
async def add_plannedroute(data: dict = Body(...)):
    await db.PlannedRoutes.insert_one(data)
    return {"status": "success", "data": serialize(data)}

@app.put("/plannedroutes")
async def upsert_plannedroute(data: dict = Body(...)):
    rid = data.get("roboter_id")
    if rid is None:
        return {"status": "error", "message": "roboter_id is required"}

    result = await db.PlannedRoutes.update_one(
        {"roboter_id": rid},
        {"$set": data},
        upsert=True
    )
    return {"status": "success", "roboter_id": rid}

@app.post("/reset_db")
async def reset_database():
    # 1) Alle alten Daten löschen
    await db.Robotstates.delete_many({})
    await db.Packages.delete_many({})
    await db.RobotID.delete_many({})
    await db.Stations.delete_many({})
    await db.TrainID.delete_many({})
    await db.PlannedRoutes.delete_many({})

    # 2) Init Standarddaten wieder einfügen
    await init_db()

    return {"status": "success", "message": "Database reset to default"}

