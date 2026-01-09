from fastapi import FastAPI
from db import db, init_db
app = FastAPI(title="Karte Backend")

@app.on_event("startup")
async def startup_event():
    await init_db()


@app.get("/api/health")
async def health():
    await db.command("ping")
    return {"ok": True, "db": db.name}


@app.get("/robotid")
async def robotid():
    # Fetch all documents
    docs = await db.RobotID.find({}).to_list()
    
    # Optional: print to console
    print("DB Return: ", docs)
    
    # Serialize _id fields for JSON
    serialized_docs = [serialize(d) for d in docs]
    
    # Return JSON list
    return serialized_docs


@app.get("/packages")
async def packages():
    # Fetch all documents
    docs = await db.Packages.find({}).to_list()
    
    # Optional: print to console
    print("DB Return: ", docs)
    
    # Serialize _id fields for JSON
    serialized_docs = [serialize(d) for d in docs]
    
    # Return JSON list
    return serialized_docs


@app.get("/robotstates")
async def robotstates():
    # Fetch all documents
    docs = await db.Robotstates.find({}).to_list()
    
    # Optional: print to console
    print("DB Return: ", docs)
    
    # Serialize _id fields for JSON
    serialized_docs = [serialize(d) for d in docs]
    
    # Return JSON list
    return serialized_docs


@app.get("/stations")
async def robotstates():
    # Fetch all documents
    docs = await db.Stations.find({}).to_list()
    
    # Optional: print to console
    print("DB Return: ", docs)
    
    # Serialize _id fields for JSON
    serialized_docs = [serialize(d) for d in docs]
    
    # Return JSON list
    return serialized_docs


@app.get("/trainid")
async def trainid():
    # Fetch all documents
    docs = await db.TrainID.find({}).to_list()
    
    # Optional: print to console
    print("DB Return: ", docs)
    
    # Serialize _id fields for JSON
    serialized_docs = [serialize(d) for d in docs]
    
    # Return JSON list
    return serialized_docs

def serialize(doc):
    
    # Remove _id tag
    doc.pop("_id", None)
    return doc
