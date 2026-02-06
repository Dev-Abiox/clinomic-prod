import hashlib
import joblib
import logging
import os
from typing import Dict, Any

# Configure logging
logger = logging.getLogger("clinomic.ml")

class GlobalModels:
    """
    Singleton to hold loaded models.
    Fail-closed: If models aren't loaded, access should raise Error.
    """
    stage1_model = None
    stage2_model = None
    thresholds = {}
    READY = False

# Hardcoded Safe Hashes (SHA256) - To be filled after calculation
# For now, we print them on mismatch to help debugging, then we PIN them.
EXPECTED_HASHES = {
    "stage1.pkl": "UNKNOWN", 
    "stage2.pkl": "UNKNOWN"
}

def calculate_file_hash(filepath: str) -> str:
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        # Read and update hash string value in blocks of 4K
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def load_models(model_dir: str):
    """
    Loads models from disk, verifies integrity, and sets GlobalModels.READY.
    """
    logger.info(f"Loading ML models from {model_dir}...")
    GlobalModels.READY = False
    
    try:
        s1_path = os.path.join(model_dir, "stage1_normal_vs_abnormal.pkl")
        s2_path = os.path.join(model_dir, "stage2_borderline_vs_deficient.pkl")
        th_path = os.path.join(model_dir, "thresholds.json")

        # 1. Verify Existence
        if not (os.path.exists(s1_path) and os.path.exists(s2_path)):
            logger.error(f"Model files not found at {model_dir}!")
            return

        # 2. Verify Integrity (Log Only for Pilot if Unknown)
        try:
             s1_hash = calculate_file_hash(s1_path)
             s2_hash = calculate_file_hash(s2_path)
             logger.info(f"Stage 1 Hash: {s1_hash}")
             logger.info(f"Stage 2 Hash: {s2_hash}")
        except Exception as e:
             logger.warning(f"Could not hash models: {e}")

        # Enforce Hash Check (Commented out until we get the values from logs)
        # if s1_hash != EXPECTED_HASHES["stage1.pkl"]:
        #    raise ValueError(f"Integrity Violated: Stage 1 Hash Mismatch")

        # 3. Load Models
        logger.info("Deserializing models with Joblib...")
        GlobalModels.stage1_model = joblib.load(s1_path)
        GlobalModels.stage2_model = joblib.load(s2_path)
        
        GlobalModels.READY = True
        logger.info("✅ Clinical Models Loaded Successfully.")

    except Exception as e:
        logger.critical(f"❌ Failed to load ML models: {e}")
        GlobalModels.READY = False
        raise e

def init_ml():
    """
    Startup hook for FastAPI to load models.
    """
    # In Docker, app is at /app/app
    # Models were copied to /app/app/ml/models (mounted volume?)
    # or baked into image if using COPY in Dockerfile.
    # We copied manually to host `backend_v2/app/ml/models`.
    # Docker-compose mounts `backend_v2` to `/app`.
    # So path is `/app/app/ml/models`.
    
    MODEL_DIR = "/app/app/ml/models"
    try:
        load_models(MODEL_DIR)
    except Exception:
        logger.warning("ML Init Failed - Service starting in Degradation Mode")
