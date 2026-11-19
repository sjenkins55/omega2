export interface Patient {
  id: string;
  mrn: string;
  first_name: string;
  last_name: string;
  date_of_birth: string;
  gender?: string;
  phone?: string;
  email?: string;
  address?: Record<string, string>;
  status: "active" | "inactive" | "discharged" | "pending";
  insurance_type?: string;
  insurance_id?: string;
  primary_dx?: string;
  diagnoses?: string[];
  medications?: Medication[];
  allergies?: string[];
  care_team?: CareTeamMember[];
  ai_risk_score?: number;
  ai_risk_factors?: RiskFactor[];
  ai_last_reviewed?: string;
  created_at: string;
}

export interface Medication {
  name: string;
  dose: string;
  frequency: string;
  route?: string;
}

export interface CareTeamMember {
  name: string;
  role: string;
  npi?: string;
  phone?: string;
}

export interface RiskFactor {
  factor: string;
  weight: number;
  description: string;
}

export interface Visit {
  id: string;
  patient_id: string;
  clinician_id?: string;
  visit_type: string;
  status: "scheduled" | "in_progress" | "completed" | "cancelled" | "missed";
  scheduled_at?: string;
  started_at?: string;
  completed_at?: string;
  raw_note?: string;
  subjective?: string;
  objective?: string;
  assessment?: string;
  plan?: string;
  vital_signs?: VitalSigns;
  action_items?: ActionItem[];
  note_finalized: boolean;
  ai_processing_status: string;
  pre_visit_brief?: PreVisitBrief;
  created_at: string;
}

export interface VitalSigns {
  bp?: string;
  hr?: string;
  rr?: string;
  temp?: string;
  o2_sat?: string;
  weight?: string;
  pain_score?: string;
}

export interface ActionItem {
  priority: "urgent" | "high" | "normal";
  type: string;
  description: string;
  due_in_hours: number;
}

export interface PreVisitBrief {
  priority_focus_areas: string[];
  clinical_alerts: Array<{ severity: "high" | "medium" | "low"; message: string }>;
  medication_review_needed: boolean;
  medications_to_review: string[];
  care_gaps: string[];
  recent_changes: string[];
  recommended_assessments: string[];
  conversation_starters: string[];
  risk_summary: string;
  visit_goals: string[];
}

export interface Document {
  id: string;
  patient_id?: string;
  doc_type: string;
  status: string;
  source?: string;
  source_fax_number?: string;
  sender_name?: string;
  file_name: string;
  page_count?: number;
  ai_summary?: string;
  extracted_data?: Record<string, unknown>;
  requires_action: boolean;
  received_at: string;
}

export interface Workflow {
  id: string;
  name: string;
  description?: string;
  status: "draft" | "active" | "paused" | "archived";
  trigger_type: string;
  trigger_config: Record<string, unknown>;
  steps: WorkflowStep[];
  conditions: WorkflowCondition[];
  run_count: number;
  last_run_at?: string;
  created_at: string;
}

export interface WorkflowStep {
  id: string;
  type: string;
  label?: string;
  config: Record<string, unknown>;
  next_steps: string[];
  next_steps_true?: string[];
  next_steps_false?: string[];
  is_root?: boolean;
  position?: { x: number; y: number };
}

export interface WorkflowCondition {
  field: string;
  operator: string;
  value: unknown;
}

export interface OutreachRecord {
  id: string;
  patient_id: string;
  outreach_type: string;
  channel: string;
  status: string;
  message_content?: string;
  scheduled_at?: string;
  sent_at?: string;
  created_at: string;
}
