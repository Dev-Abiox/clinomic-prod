import requests
import json
import logging

# Configuration
API_URL = "http://localhost:8000/api/v1"
LOGIN_URL = f"{API_URL}/login/access-token"
SCREENING_URL = f"{API_URL}/screenings"

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("ml_verify")

def verify_ml():
    # 1. Login
    session = requests.Session()
    login_data = {"username": "admin@test.com", "password": "Admin123!"}
    
    try:
        resp = session.post(LOGIN_URL, data=login_data)
        if resp.status_code != 200:
            logger.error(f"Login Failed: {resp.text}")
            return
        token = resp.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}
        logger.info("✅ Login Successful")
    except Exception as e:
        logger.error(f"Login Exception: {e}")
        return

    # 2. Create High Risk Payload (High MCV > 115)
    # Expected: Deficient or Borderline
    high_risk_payload = {
        "patient_id": "00000000-0000-0000-0000-000000000000", # Dummy UUID, verifying logic not DB constraints? 
        # Actually create screening usually requires valid patient_id or it 404s? 
        # Let's hope validation is on Service layer not Pydantic for existence?
        # Re-reading services: ScreeningService checks repo.get(patient_id).
        # We need a valid patient.
        # Let's use the UI flow or create a patient first?
        # Simpler: Create Patient First.
    }
    
    # 2a. Create Patient
    patient_payload = {
        "name": "ML Verify Bot",
        "date_of_birth": "1980-01-01",
        "age": 45,
        "sex": "M",
        "lab_id": "lab_123", # Dummy lab ID if validation requires it, or maybe it's strict?
        # Error said "lab_id" required in body.
        "contact_number": "555-0199"
    }
    try:
        p_resp = session.post(f"{API_URL}/patients/", json=patient_payload, headers=headers)
        if p_resp.status_code not in [200, 201]:
             logger.error(f"Patient Create Failed: {p_resp.text}")
             return
        patient_id = p_resp.json()["id"]
        logger.info(f"✅ Patient Created: {patient_id}")
    except Exception as e:
        logger.error(f"Patient Creation Error: {e}")
        return

    # 3. Create Screening (Real ML Test)
    # Note: API expects 'extra_data' for non-core fields if using strict schema
    screening_payload = {
        "patient_id": patient_id,
        "hb": 8.5,
        "mcv": 115.0,
        "extra_data": {
            "rbc": 2.5,
            "hct": 30.0,
            "rdw": 18.0,
            "wbc": 5.0,
            "plt": 200.0,
            "neutrophils_percent": 60.0,
            "lymphocytes_percent": 30.0,
            "age": 45,
            "sex": "M" 
        }
    }

    try:
        s_resp = session.post(SCREENING_URL, json=screening_payload, headers=headers)
        if s_resp.status_code != 200:
            logger.error(f"Screening Failed: {s_resp.text}")
            return
            
        result = s_resp.json()
        logger.info(f"🔍 ML Output: {json.dumps(result, indent=2)}")
        
        # Validation Logic
        risk_class = result.get("risk_level", result.get("riskClass")) # Check schema key
        confidence = result.get("confidence_score", 0)
        
        # Real ML usually returns 3 (Deficient) for this payload
        # Mock ML returned constant 0.99
        
        if confidence == 0.99 or confidence == 0.95:
             logger.warning("⚠️  WARNING: Confidence looks like MOCK DATA (0.99/0.95)")
        else:
             logger.info("✅ Confidence looks organic (Real Model likely active)")
             with open("verification_result.txt", "w") as f:
                 f.write(json.dumps(result, indent=2))
                 f.write(f"\nRAW CONFIDENCE: {confidence}")
             
    except Exception as e:
        logger.error(f"Screening Error: {e}")
        with open("verification_result.txt", "w") as f:
            f.write(f"ERROR: {e}")

if __name__ == "__main__":
    verify_ml()
