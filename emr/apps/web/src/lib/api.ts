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
  list: (params?: { status?: string; search?: string; assigned_provider_id?: string; high_risk?: boolean; limit?: number; offset?: number }) =>
    api.get("/patients", { params }),
  get: (id: string) => api.get(`/patients/${id}`),
  create: (data: Record<string, unknown>) => api.post("/patients", data),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/patients/${id}`, data),
  riskBrief: (id: string) => api.get(`/patients/${id}/risk-brief`),
  discharge: (id: string, data: Record<string, unknown>) => api.post(`/patients/${id}/discharge`, data),
  dischargeSummary: (id: string) => api.get(`/patients/${id}/discharge-summary`),
};

// Visits
export const visitsApi = {
  list: (params?: { patient_id?: string; status?: string; limit?: number }) =>
    api.get("/visits", { params }),
  get: (id: string) => api.get(`/visits/${id}`),
  create: (data: Record<string, unknown>) => api.post("/visits", data),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/visits/${id}`, data),
  preBrief: (id: string) => api.get(`/visits/${id}/pre-brief`),
  start: (id: string) => api.post(`/visits/${id}/start`),
  submitNote: (id: string, data: { raw_note: string; finalize: boolean }) =>
    api.post(`/visits/${id}/submit-note`, data),
  addNote: (id: string, data: { raw_note: string; finalize?: boolean }) =>
    api.post(`/visits/${id}/notes`, data),
  photos: (id: string) => api.get(`/visits/${id}/photos`),
  uploadPhoto: (id: string, formData: FormData) =>
    api.post(`/visits/${id}/photos`, formData, { headers: { "Content-Type": "multipart/form-data" } }),
};

// Visit Photos
export const visitPhotosApi = {
  delete: (photoId: string) => api.delete(`/visit-photos/${photoId}`),
};

// Vitals
export const vitalsApi = {
  trend: (patientId: string, limit?: number) =>
    api.get(`/patients/${patientId}/vitals-trend`, { params: { limit } }),
};

// Conditions (HCC / Dx list)
export const conditionsApi = {
  list: (patientId: string, params?: { hcc_only?: boolean; unrecaptured?: boolean }) =>
    api.get(`/patients/${patientId}/conditions`, { params }),
  create: (patientId: string, data: Record<string, unknown>) =>
    api.post(`/patients/${patientId}/conditions`, data),
  get: (id: string) => api.get(`/conditions/${id}`),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/conditions/${id}`, data),
  delete: (id: string) => api.delete(`/conditions/${id}`),
};

// Lab Results
export const labResultsApi = {
  list: (patientId: string, params?: { loinc_code?: string; category?: string; limit?: number }) =>
    api.get(`/patients/${patientId}/lab-results`, { params }),
  create: (patientId: string, data: Record<string, unknown>) =>
    api.post(`/patients/${patientId}/lab-results`, data),
  get: (id: string) => api.get(`/lab-results/${id}`),
};

// Tasks / Clinician Inbox
export const tasksApi = {
  list: (params?: { assignee_id?: string; patient_id?: string; status?: string; priority?: string; category?: string; limit?: number }) =>
    api.get("/tasks", { params }),
  create: (data: Record<string, unknown>) => api.post("/tasks", data),
  get: (id: string) => api.get(`/tasks/${id}`),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/tasks/${id}`, data),
  complete: (id: string, notes?: string) => api.post(`/tasks/${id}/complete`, { notes }),
};

// Notifications
export const notificationsApi = {
  list: (params?: { unread_only?: boolean; limit?: number }) =>
    api.get("/notifications", { params }),
  unreadCount: () => api.get("/notifications/unread-count"),
  markRead: (id: string) => api.patch(`/notifications/${id}/read`, {}),
  markAllRead: () => api.post("/notifications/mark-all-read", {}),
};

// Care Plans
export const carePlansApi = {
  list: (patientId: string) => api.get(`/patients/${patientId}/care-plans`),
  create: (patientId: string, data: Record<string, unknown>) =>
    api.post(`/patients/${patientId}/care-plans`, data),
  get: (id: string) => api.get(`/care-plans/${id}`),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/care-plans/${id}`, data),
};

// Physician Orders
export const ordersApi = {
  list: (patientId: string, params?: { status?: string }) =>
    api.get(`/patients/${patientId}/orders`, { params }),
  create: (patientId: string, data: Record<string, unknown>) =>
    api.post(`/patients/${patientId}/orders`, data),
  get: (id: string) => api.get(`/orders/${id}`),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/orders/${id}`, data),
};

// OASIS Assessments
export const oasisApi = {
  list: (patientId: string) => api.get(`/patients/${patientId}/oasis`),
  create: (patientId: string, data: Record<string, unknown>) =>
    api.post(`/patients/${patientId}/oasis`, data),
  get: (id: string) => api.get(`/oasis/${id}`),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/oasis/${id}`, data),
};

// Plan of Care (CMS-485)
export const planOfCareApi = {
  list: (patientId: string) => api.get(`/patients/${patientId}/plans-of-care`),
  create: (patientId: string, data: Record<string, unknown>) =>
    api.post(`/patients/${patientId}/plans-of-care`, data),
  get: (id: string) => api.get(`/plans-of-care/${id}`),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/plans-of-care/${id}`, data),
};

// Reports & Analytics
export const reportsApi = {
  census: () => api.get("/reports/census"),
  visitUtilization: (params?: { limit?: number }) => api.get("/reports/visit-utilization", { params }),
  hccCapture: (params?: { year?: number; limit?: number }) => api.get("/reports/hcc-capture", { params }),
  hospitalizationRisk: (params?: { limit?: number }) => api.get("/reports/hospitalization-risk", { params }),
  staffProductivity: (params?: { limit?: number }) => api.get("/reports/staff-productivity", { params }),
};

// HIPAA Audit Log
export const auditApi = {
  list: (params?: { user_id?: string; resource_type?: string; resource_id?: string; action?: string; limit?: number }) =>
    api.get("/admin/audit", { params }),
};

// Insurance Eligibility
export const eligibilityApi = {
  list: (patientId: string) => api.get(`/patients/${patientId}/eligibility`),
  check: (patientId: string, data: Record<string, unknown>) =>
    api.post(`/patients/${patientId}/eligibility`, data),
};

// ADT Events (hospital admit/discharge/transfer feeds)
export const adtApi = {
  inbound: (data: Record<string, unknown>) => api.post("/adt/inbound", data),
  list: (params?: { patient_id?: string; event_type?: string; matched?: boolean; limit?: number }) =>
    api.get("/adt", { params }),
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

// AI Chat (HIPAA minimum necessary — state-scoped)
export const chatApi = {
  // Returns a streaming fetch Response — use ReadableStream for SSE
  stream: (message: string, history: { role: string; content: string }[]) => {
    const token = typeof window !== "undefined" ? localStorage.getItem("token") : null;
    return fetch(`${BASE_URL}/chat`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: JSON.stringify({ message, history }),
    });
  },
};

// Organizations (super_admin provisioning)
export const organizationsApi = {
  list: () => api.get("/admin/organizations"),
  create: (data: { name: string; slug: string; plan_tier?: string; max_users?: number; max_patients?: number }) =>
    api.post("/admin/organizations", data),
  update: (id: string, data: Record<string, unknown>) => api.patch(`/admin/organizations/${id}`, data),
  provisionAdmin: (orgId: string, data: { email: string; first_name: string; last_name: string; password?: string }) =>
    api.post(`/admin/organizations/${orgId}/provision-admin`, data),
};

// Engagement
export const engagementApi = {
  list: (params?: { patient_id?: string; status?: string; limit?: number }) =>
    api.get("/engagement/outreach", { params }),
  composeMessage: (params: { patient_id: string; outreach_type: string; channel: string }) =>
    api.post("/engagement/outreach/compose", null, { params }),
  bulkSchedule: (data: Record<string, unknown>) =>
    api.post("/engagement/outreach/bulk-schedule", data),
  send: (id: string) => api.post(`/engagement/outreach/${id}/send`),
};

// Auth (current staff user)
export const authApi = {
  me: () => api.get("/auth/me"),
};

// Integration API keys (org admin)
export const integrationApi = {
  listKeys: () => api.get("/integration/keys"),
  createKey: (data: { name: string; scopes?: string[]; organization_id?: string }) =>
    api.post("/integration/keys", data),
  revokeKey: (id: string) => api.delete(`/integration/keys/${id}`),
};

// Medication safety (drug-interaction + allergy check)
export const medicationSafetyApi = {
  check: (patientId: string) => api.get(`/patients/${patientId}/medication-safety`),
};
