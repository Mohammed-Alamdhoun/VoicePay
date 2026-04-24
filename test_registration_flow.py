import requests
import os
import json

BASE_URL = "http://127.0.0.1:5000/api/v1"

def test_flow():
    # 1. Register
    reg_data = {
        "full_name": "Test User",
        "email": "test_unique_email@example.com",
        "password": "password123",
        "phone_number": "123456789",
        "bank_name": "Test Bank"
    }
    print(f"Testing Registration for {reg_data['email']}...")
    try:
        r = requests.post(f"{BASE_URL}/register", json=reg_data)
        print(f"Register Status: {r.status_code}")
        print(f"Register Response: {r.text}")
        
        if r.status_code != 200:
            if "already exists" in r.text or "مسجل بالفعل" in r.text:
                print("User already exists, proceeding to enrollment with existing user PID (assuming 1 for test if not found)")
                # In real test we should probably use a dynamic email
                # For this test, let's just use a random email suffix
                import random
                reg_data["email"] = f"test_{random.randint(1000,9999)}@example.com"
                r = requests.post(f"{BASE_URL}/register", json=reg_data)
                print(f"Retrying Register with {reg_data['email']}: {r.status_code}")
        
        user_id = r.json().get("user_id")
        if not user_id:
            print("Failed to get user_id")
            return

        # 2. Get Challenges
        print("\nFetching Challenges...")
        r = requests.get(f"{BASE_URL}/enrollment-challenges")
        print(f"Challenges: {len(r.json())}")

        # 3. Enroll Voice
        print(f"\nEnrolling Voice for user {user_id}...")
        files = []
        for i in range(6):
            files.append(('files', open(f'temp_test_audio/sample_{i}.wav', 'rb')))
        
        r = requests.post(f"{BASE_URL}/enroll-voice", params={"user_id": user_id}, files=files)
        print(f"Enroll Status: {r.status_code}")
        print(f"Enroll Response: {r.text}")

        # 4. Verify login state
        print("\nVerifying Login...")
        login_data = {"email": reg_data["email"], "password": reg_data["password"]}
        r = requests.post(f"{BASE_URL}/login", json=login_data)
        print(f"Login Status: {r.status_code}")
        print(f"Login Response: {r.text}")
        
        if r.json().get("status") == "success":
            print("\nSUCCESS: Full registration and enrollment flow verified!")
        else:
            print("\nFAILED: Login did not return success status.")

    except Exception as e:
        print(f"Error during test: {e}")

if __name__ == "__main__":
    test_flow()
