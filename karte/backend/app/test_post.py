import requests

BASE_URL = "http://127.0.0.1:8000"

def test_posts():
    # Data to be sent
    test_data = {
        "/robotid": {"roboter_id": 99},
    }

    print("--- Testing POST Endpoints ---")
    
    for endpoint, payload in test_data.items():
        response = requests.post(f"{BASE_URL}{endpoint}", json=payload)
        
        if response.status_code == 200:
            print(f"[SUCCESS] {endpoint}: {response.json()}")
        else:
            print(f"[FAILED]  {endpoint}: {response.status_code} - {response.text}")

    print("\n--- Verifying with GET ---")
    # Verify by calling one of the GET endpoints
    get_res = requests.get(f"{BASE_URL}/robotid")
    print(f"Current Stations: {get_res.json()}")

if __name__ == "__main__":
    try:
        test_posts()
    except requests.exceptions.ConnectionError:
        print("Error: Could not connect to the server. Make sure main.py is running on port 8000.")