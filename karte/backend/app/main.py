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