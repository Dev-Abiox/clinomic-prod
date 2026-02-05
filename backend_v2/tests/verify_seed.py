import requests
import sys

URL = "http://localhost:8000/api/v1/login/access-token"
PAYLOAD = {
    "username": "admin@test.com",
    "password": "Admin123!"
}

def verify_seed():
    print(f"Testing Login to {URL}...")
    try:
        resp = requests.post(URL, data=PAYLOAD)
        if resp.status_code == 200:
            print("✅ SUCCESS: Admin Login Confirmed.")
            print(f"Token: {resp.json().get('access_token')[:20]}...")
        else:
            print(f"❌ FAILED: Status {resp.status_code}")
            print(f"Response: {resp.text}")
            sys.exit(1)
    except Exception as e:
        print(f"❌ ERROR: {e}")
        sys.exit(1)

if __name__ == "__main__":
    verify_seed()
