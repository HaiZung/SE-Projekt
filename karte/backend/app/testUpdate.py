import requests

BASE_URL = "http://127.0.0.1:8000"

def test_robot_update():
    # 2. The Payload you specified
    payload = {"roboter_id": 1000, "status": "defective"}
    
    print(f"Sending update: {payload}")
    
    # 3. Perform the PUT request
    response = requests.put(f"{BASE_URL}/robotstates", json=payload)
    
    if response.status_code == 200:
        print("Response from server:", response.json())
        
        # 4. Verification: Fetch all states to see the change
        get_res = requests.get(f"{BASE_URL}/robotstates")
        states = get_res.json()
        updated_robot = next((r for r in states if r.get("roboter_id") == 99), None)
        print(f"Verified state in DB: {updated_robot}")
    else:
        print(f"Failed: {response.status_code} - {response.text}")

if __name__ == "__main__":
    test_robot_update()