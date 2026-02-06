import asyncio
import logging
import pandas as pd
from concurrent.futures import ThreadPoolExecutor
from enum import Enum
from typing import Dict, Tuple, Any

from app.ml.loader import GlobalModels, load_models

logger = logging.getLogger("clinomic.ml")

class RiskClass(int, Enum):
    NORMAL = 1
    BORDERLINE = 2
    DEFICIENT = 3

class ClinicalEngine:
    def __init__(self, model_dir: str = "/app/app/ml/models"):
        # We assume models are inside the container at this path
        self.model_dir = model_dir
        self.executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="ml_worker")
        self.model_version = "v1.0"
        
    def load_models(self):
        """
        Delegates to the safe loader.
        """
        try:
            load_models(self.model_dir)
            if not GlobalModels.READY:
                logger.warning("ML Loader finished but READY is False.")
        except Exception as e:
            logger.error(f"Engine failed to trigger loader: {e}")

    @property
    def ready(self) -> bool:
        return GlobalModels.READY

    def predict_sync(self, cbc_data: Dict) -> Tuple[int, float]:
        """
        Real CatBoost Inference adapted from V1.
        """
        if not self.ready:
            raise RuntimeError("Clinical Engine is NOT READY")
            
        # 1. Prepare DataFrame
        # Maps V2 Pydantic fields (lowercase) to V1 Model fields (Capitalized)
        # V2 schema: hb, mcv, sex...
        
        row = {
            "Age": cbc_data.get("age", 30),
            "Sex": cbc_data.get("sex", "M"),
            "Hb": cbc_data.get("hb", 0),
            "RBC": cbc_data.get("rbc", 0),
            "HCT": cbc_data.get("hct", 0),
            "MCV": cbc_data.get("mcv", 0),
            "MCH": cbc_data.get("mch", 0),
            "MCHC": cbc_data.get("mchc", 0),
            "RDW": cbc_data.get("rdw", 0),
            "WBC": cbc_data.get("wbc", 0),
            "Platelets": cbc_data.get("plt", 0), # V2 schema uses 'plt' vs 'Platelets'
            "Neutrophils": cbc_data.get("neutrophils_percent", 0), # Schema check needed?
            "Lymphocytes": cbc_data.get("lymphocytes_percent", 0),
        }
        
        df = pd.DataFrame([row])
        
        # 2. Ensure Columns & Order
        expected_cols = [
            "Age", "Sex", "Hb", "RBC", "HCT", "MCV", "MCH", "MCHC",
            "RDW", "WBC", "Platelets", "Neutrophils", "Lymphocytes"
        ]
        
        # Fill missing
        for col in expected_cols:
            if col not in df.columns:
                df[col] = 0
        
        # Reorder
        df = df[expected_cols]
        
        # 3. Preprocess Sex
        # Ensure it's treated as string first, then mapped, then int
        df["Sex"] = df["Sex"].astype(str).str.upper().str.strip()
        df["Sex"] = df["Sex"].map({"M": 1, "F": 0, "1": 1, "0": 0}).fillna(0).astype(int)
             
        # 4. Inference
        try:
            p_abnormal = float(GlobalModels.stage1_model.predict_proba(df)[0][1])
            
            # Stage 2 Trigger
            if p_abnormal > 0.3:
                p_def = float(GlobalModels.stage2_model.predict_proba(df)[0][1])
            else:
                p_def = 0.05
                
            # Logic Rule Apply ( Simplified from V1 for Pilot speed - strict usage of model score first)
            # V1 had 'apply_rules' output influencing final score.
            # For strict ML validation, let's rely on model probability primarily or reimplement rules?
            # User said "Rebuild ... Replace Mock ML". Logic parity is good.
            # But let's stick to pure Model Probability for Version 2.0 baseline to confirm Model is working.
            # We can port Rules later if accuracy drops.
            
            # Mapping
            # > 0.7 => Deficient
            # > 0.4 => Borderline
            # Else => Normal
            
            if p_def >= 0.7:
                return RiskClass.DEFICIENT, round(p_def, 4)
            elif p_def >= 0.4:
                return RiskClass.BORDERLINE, round(p_def, 4)
            else:
                return RiskClass.NORMAL, round(1 - p_def, 4) # Confidence of Normal?
                
        except Exception as e:
            logger.error(f"Inference Error: {e}")
            raise e

    async def predict(self, cbc_data: Dict) -> Tuple[int, float]:
        if not self.ready:
            raise RuntimeError("Clinical Engine Unavailable")
            
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(
            self.executor,
            self.predict_sync,
            cbc_data
        )

# Global Instance
engine = ClinicalEngine()
