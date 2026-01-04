from fastapi import FastAPI
from app.db import db

app = FastAPI(title="Karte Backend")

@app.get("/api/health")
async def health():
    await db.command("ping")
    return {"ok": True, "db": db.name}
