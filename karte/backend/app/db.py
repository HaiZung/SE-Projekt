import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

load_dotenv()

MONGO_URL = os.getenv("MONGO_URL", "mongodb://127.0.0.1:27017")
MONGO_DB = os.getenv("MONGO_DB", "mapdb")

client = AsyncIOMotorClient(MONGO_URL)
db = client[MONGO_DB]

# --- TrainID Collection: 3 Züge ---
train_collection = db["TrainID"]
trains = [
    {"zugnummer": 1, "start": "08:00", "stop": "12:00", "von": "StationA", "bis": "StationB"},
    {"zugnummer": 2, "start": "09:00", "stop": "13:30", "von": "StationB", "bis": "StationC"},
    {"zugnummer": 3, "start": "10:00", "stop": "14:00", "von": "StationA", "bis": "StationC"}
]
train_collection.insert_many(trains)

# --- RobotID Collection: nur IDs oder Status referenzieren, keine Daten ---
robot_collection = db["RobotID"]
robots = [
    {"roboter_id": 1},
    {"roboter_id": 2},
    {"roboter_id": 3}
]
robot_collection.insert_many(robots)

# --- Packages Collection: Pakete mit Roboterzuordnung ---
packages_collection = db["Packages"]
packages = [
    {"paketnummer": 101, "gewicht": 5.0, "masse": "10x10x10", "roboter_id": 1},
    {"paketnummer": 102, "gewicht": 3.2, "masse": "8x8x8", "roboter_id": 2},
    {"paketnummer": 103, "gewicht": 4.5, "masse": "12x12x12", "roboter_id": 1}
]
packages_collection.insert_many(packages)

# --- Stations Collection ---
stations_collection = db["Stations"]
stations = [
    {"station": "StationA"},
    {"station": "StationB"},
    {"station": "StationC"}
]
stations_collection.insert_many(stations)

# --- JSONs Collection: Beispiel-Dateien ---
jsons_collection = db["JSONs"]
jsons = [
    {"dateiname": "file1.json", "inhalt": {"key": "value1"}},
    {"dateiname": "file2.json", "inhalt": {"key": "value2"}}
]
jsons_collection.insert_many(jsons)

# --- Robotstates Collection: Status der Roboter ---
robotstates_collection = db["Robotstates"]
robotstates = [
    {"roboter_id": 1, "status": "aktiv"},
    {"roboter_id": 2, "status": "inaktiv"},
    {"roboter_id": 3, "status": "wartung"}
]
robotstates_collection.insert_many(robotstates)

print("Alle Collections wurden mit Beispiel-Daten gefüllt.")