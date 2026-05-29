import axios from "axios";

const BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000/api/v1";

export const api = axios.create({
  baseURL: BASE_URL,
  headers: { "Content-Type": "application/json" },
});

api.interceptors.request.use((config) => {
  const token = typeof window !== "undefined" ? localStorage.getItem("token") : null;
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401 && typeof window !== "undefined") {
      localStorage.removeItem("token");
      window.location.href = "/login";
    }
    return Promise.reject(err);
  }
);

// Portal API instance (uses portal_token from localStorage)
export const portalApi = axios.create({
  baseURL: BASE_URL,
  headers: { "Content-Type": "application/json" },
});

portalApi.interceptors.request.use((config) => {
  const token = typeof window !== "undefined" ? localStorage.getItem("portal_token") : null;
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

portalApi.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401 && typeof window !== "undefined") {
      localStorage.removeItem("portal_token");
      window.location.href = "/portal/login";
    }
    return Promise.reject(err);
  }
);

// Patients
export const patientsApi = {
  list: (params?: { status?: string; search?: string; limit?: number; offset?: number }) =>
    api.get("/patients", { params }),
  get: (id: string) => api.get(`/patients/${id}`),
  create: (data: Record<string, unknown>) => api.post("/patients", data),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/patients/${id}`, data),
  riskBrief: (id: string) => api.get(`/patients/${id}/risk-brief`),
};

// Visits
export const visitsApi = {
  get: (id: string) => api.get(`/visits/${id}`),
  create: (data: Record<string, unknown>) => api.post("/visits", data),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/visits/${id}`, data),
  preBrief: (id: string) => api.get(`/visits/${id}/pre-brief`),
  start: (id: string) => api.post(`/visits/${id}/start`),
  submitNote: (id: string, data: { raw_note: string; finalize: boolean }) =>
    api.post(`/visits/${id}/submit-note`, data),
};

// Workflows
export const workflowsApi = {
  list: (params?: { status?: string }) => api.get("/workflows", { params }),
  get: (id: string) => api.get(`/workflows/${id}`),
  create: (data: Record<string, unknown>) => api.post("/workflows", data),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/workflows/${id}`, data),
  activate: (id: string) => api.post(`/workflows/${id}/activate`),
  testRun: (id: string, payload: Record<string, unknown>) =>
    api.post(`/workflows/${id}/test-run`, payload),
  runs: (id: string) => api.get(`/workflows/${id}/runs`),
  stepCatalog: () => api.get("/workflows/step-types/catalog"),
};

// Ingestion
export const ingestionApi = {
  listDocuments: (params?: { patient_id?: string; status?: string }) =>
    api.get("/ingestion/documents", { params }),
  getDocument: (id: string) => api.get(`/ingestion/documents/${id}`),
  assignToPatient: (docId: string, patientId: string) =>
    api.post(`/ingestion/documents/${docId}/assign`, null, { params: { patient_id: patientId } }),
  upload: (formData: FormData) =>
    api.post("/ingestion/upload", formData, { headers: { "Content-Type": "multipart/form-data" } }),
};

// Engagement
export const engagementApi = {
  list: (params?: { patient_id?: string; status?: string }) =>
    api.get("/engagement/outreach", { params }),
  composeMessage: (params: { patient_id: string; outreach_type: string; channel: string }) =>
    api.post("/engagement/outreach/compose", null, { params }),
  bulkSchedule: (data: Record<string, unknown>) =>
    api.post("/engagement/outreach/bulk-schedule", data),
  send: (id: string) => api.post(`/engagement/outreach/${id}/send`),
};
