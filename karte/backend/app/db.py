import os
from motor.motor_asyncio import AsyncIOMotorClient
from dotenv import load_dotenv

load_dotenv()

MONGO_URL = os.getenv("MONGO_URL", "mongodb://127.0.0.1:27017")
MONGO_DB = os.getenv("MONGO_DB", "mapdb")

client = AsyncIOMotorClient(MONGO_URL)
db = client[MONGO_DB]


async def init_db():
    # --- TrainID Collection ---
    train_collection = db["TrainID"]
    if await train_collection.count_documents({}) == 0:
        await train_collection.insert_many([
            {"zugnummer": 1, "start": "08:00", "stop": "12:00", "von": "StationA", "bis": "StationB"},
            {"zugnummer": 2, "start": "09:00", "stop": "13:30", "von": "StationB", "bis": "StationC"},
            {"zugnummer": 3, "start": "10:00", "stop": "14:00", "von": "StationA", "bis": "StationC"}
        ])

    # --- RobotID Collection ---
    robot_collection = db["RobotID"]
    if await robot_collection.count_documents({}) == 0:
        await robot_collection.insert_many([
            {"roboter_id": 1},
            {"roboter_id": 2},
            {"roboter_id": 3},
            {"roboter_id": 4}
        ])

    # --- Packages Collection ---
    packages_collection = db["Packages"]
    if await packages_collection.count_documents({}) == 0:
        await packages_collection.insert_many([
            {"paketnummer": 101, "gewicht": 5.0, "masse": "10x10x10", "roboter_id": 1},
            {"paketnummer": 102, "gewicht": 3.2, "masse": "8x8x8", "roboter_id": 2},
            {"paketnummer": 103, "gewicht": 4.5, "masse": "12x12x12", "roboter_id": 1}
        ])

    # --- Stations Collection ---
    stations_collection = db["Stations"]
    if await stations_collection.count_documents({}) == 0:
        await stations_collection.insert_many([
            {"station": "StationA"},
            {"station": "StationB"},
            {"station": "StationC"}
        ])

    # --- JSONs Collection ---
    jsons_collection = db["JSONs"]
    if await jsons_collection.count_documents({}) == 0:
        await jsons_collection.insert_many([
            {"dateiname": "file1.json", "inhalt": {"key": "value1"}},
            {"dateiname": "file2.json", "inhalt": {"key": "value2"}}
        ])

    # --- Robotstates Collection ---
    robotstates_collection = db["Robotstates"]
    if await robotstates_collection.count_documents({}) == 0:
        await robotstates_collection.insert_many([
            {"roboter_id": 1, "status": "aktiv"},
            {"roboter_id": 2, "status": "inaktiv"},
            {"roboter_id": 3, "status": "wartung"},
            {"roboter_id": 4, "status": "charging"}
        ])

    print("Database initialized (only missing collections were seeded).")

    # --- PlannedRoutes Collection ---
    # Simulation
    #muss korregiert werden
    planned_collection = db["PlannedRoutes"]
    if await planned_collection.count_documents({}) == 0:
        await planned_collection.insert_many([
            {
                "roboter_id": 1,
                "line_id": "S1",
                "stations": ["de:08216:32187", "de:08216:32184", "...", "de:08212:7"],
                "note": "HBF -> Karlsruhe Schloss Rüppurr"
            },
            {
                "roboter_id": 2,
                "line_id": "2",
                "stations": ["de:08212:240", "de:08212:239", "...", "de:08212:4500"],
                "note": "HBF -> Mühlburger Tor"
            },
            {
                "roboter_id": 3,
                "line_id": "3",
                "stations": ["de:08212:308", "de:08212:307", "...", "de:08212:314"],
                "note": "HBF -> Kronenplatz"
            },
            {
                "roboter_id": 4,
                "line_id": "HBF",
                "stations": [],
                "note": "Bleibt zum Laden am HBF"
            }
        ])


