import axios from "axios";

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || "http://localhost:8000";

// API Instance pointing to V2 Base URL
const API = axios.create({
  baseURL: `${BACKEND_URL}/api/v1`,
});

// Interceptor: Add Auth Token
API.interceptors.request.use((config) => {
  const token = localStorage.getItem("access_token");
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Interceptor: Handle 401 (Logout)
API.interceptors.response.use(
  (res) => res,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem("access_token");
      window.location.href = "/login";
    }
    return Promise.reject(error);
  }
);

export const AuthService = {
  login: async (username, password) => {
    // V2 uses OAuth2 Standard (Form Data)
    const formData = new URLSearchParams();
    formData.append("username", username);
    formData.append("password", password);

    const res = await API.post("/login/access-token", formData, {
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
    });

    // Store Token
    localStorage.setItem("access_token", res.data.access_token);

    // Return User Profile (Mock or Decode Token)
    // V2 implementation doesn't return user info/role in login response, only token.
    // We can fetch /auth/me or just return dummy structure to satisfy frontend.
    // Ideally we should decode the token to get role/org.
    // For Pilot: Return success.
    return {
      id: "current-user",
      name: username,
      role: "ADMIN", // Assuming Admin for Pilot login
      mfaRequired: false
    };
  },

  logout: async () => {
    localStorage.removeItem("access_token");
  },

  getMe: async () => {
<<<<<<< HEAD
    // Optional: implement /me endpoint in backend if needed
    return { name: "Pilot User" };
  }
=======
    const res = await API.get("/auth/me");
    return res.data;
  },
};

export const MFAService = {
  getStatus: async () => {
    const res = await API.get("/mfa/status");
    return res.data;
  },
  
  setup: async (email) => {
    const res = await API.post("/mfa/setup", { email });
    return res.data;
  },
  
  verifySetup: async (code) => {
    const res = await API.post("/mfa/verify-setup", { code });
    return res.data;
  },
  
  disable: async (code) => {
    const res = await API.post("/mfa/disable", { code });
    return res.data;
  },
  
  regenerateBackupCodes: async (code) => {
    const res = await API.post("/mfa/backup-codes/regenerate", { code });
    return res.data;
  },
};

export const ConsentService = {
  getStatus: async (patientId) => {
    try {
      const res = await API.get(`/screening/consent/status/${patientId}`);
      return res.data;
    } catch (e) {
      return { hasConsent: false };
    }
  },

  record: async (patientId, consentData) => {
    const res = await API.post("/screening/consent/record", consentData);
    return res.data;
  },
>>>>>>> origin/v3_final
};

export const LisService = {
  // Legacy function kept for compatibility or removal
  uploadPdf: async (file) => {
    console.warn("PDF Upload not supported in V2 Pilot");
    return {};
  },

  predictB12: async (cbcData, patient, consentId = null) => {
    // 1. Create Patient (or Find?)
    // V2 Flow: Create Patient -> Get ID -> Create Screening
    // Frontend 'predictB12' usually does it all in one, or assumes patient exists?
    // Let's assume we create a new patient for every screening in this Pilot UI flow 
    // unless we refactor the UI to select patient first.

    // Step A: Create Patient
    const patientPayload = {
      lab_id: patient.labId || "P-Gen",
      name: patient.patientName || "Unknown",
      age: parseInt(patient.age) || 30,
      sex: patient.sex || "M",
      phone: "555-0123"
    };

    const patientRes = await API.post("/patients/", patientPayload);
    const patientId = patientRes.data.id;

    // Step B: Create Screening
    const screeningPayload = {
      patient_id: patientId,
      hb: parseFloat(cbcData.hb),
      mcv: parseFloat(cbcData.mcv),
      extra_data: cbcData // Send full CBC as extra
    };

    const res = await API.post("/screenings/", screeningPayload);

    // Map V2 Response to Frontend Format
    return {
      label: res.data.risk_class === 3 ? "High Risk" : "Low Risk",
      probabilities: { [res.data.risk_class]: res.data.confidence_score },
      indices: [],
      recommendation: res.data.risk_class === 3 ? "Follow up required" : "Routine check",
      interpretation: `Confidence: ${res.data.confidence_score}`
    };
  },

  getLabs: async () => [],
  getDoctors: async () => [],
  getPatientRecords: async () => [],
  getStats: async () => ({})
};

// Admin Services (Stubbed/Limited for V2 Pilot)
export const AdminService = {
  getAuditSummary: async () => [],
  verifyAuditChain: async () => ({ valid: true, chain: [] }),
  exportAuditLogs: async () => [],
  getSystemHealth: async () => ({ status: "ok" }),
  getSystemConfig: async () => ({})
};

// MFA Service (Stubbed - Not in V2)
export const MFAService = {
  getStatus: async () => ({ enabled: false }),
  setup: async () => { },
  verifySetup: async () => { },
  disable: async () => { },
  regenerateBackupCodes: async () => { }
};

export const ConsentService = {
  getStatus: async () => ({ hasConsent: true }),
  record: async () => { }
};
