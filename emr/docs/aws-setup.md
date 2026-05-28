# AWS Setup Guide — EMR + Claude Full Stack

Step-by-step guide from zero AWS experience to a fully wired system.
Covers Bedrock (Claude with HIPAA BAA), HealthLake (FHIR R4), Comprehend Medical (NLP), and S3.

---

## Part 1 — AWS Account & Billing

### Step 1: Create an AWS Account
1. Go to **aws.amazon.com** → click **"Create an AWS Account"**
2. Enter your email, create a root password, pick account name (e.g. `ConcertoCare EMR`)
3. Enter credit card (you won't be charged until you use services)
4. Verify phone number → choose **"Basic Support"** (free)
5. Sign in to the **AWS Management Console**

### Step 2: Secure the Root Account
1. Top-right corner → click your account name → **"Security credentials"**
2. Under **"Multi-factor authentication (MFA)"** → **"Assign MFA"** → use an authenticator app
3. **Never use the root account for day-to-day work** — use the IAM user created next

---

## Part 2 — IAM User (Your Admin Access)

### Step 3: Create an Admin User
1. Search for **"IAM"** in the AWS console
2. Left sidebar → **"Users"** → **"Create user"**
3. Username: `emr-admin` → check **"Provide user access to the AWS Management Console"** → Next
4. Select **"Attach policies directly"**
5. Search and add: `AdministratorAccess` (for initial setup; swap for `EMRAppPolicy` after)
6. Click through → **"Create user"**
7. **Download the CSV** — this has your console password

### Step 4: Create Access Keys (for the app to call AWS)
1. Click on your new user → **"Security credentials"** tab
2. Scroll to **"Access keys"** → **"Create access key"**
3. Select **"Application running outside AWS"** → Next
4. Description: `emr-app-local` → **"Create access key"**
5. **⚠️ Copy both keys NOW** — you cannot see the secret again:
   - `Access key ID` → `AWS_ACCESS_KEY_ID`
   - `Secret access key` → `AWS_SECRET_ACCESS_KEY`

---

## Part 3 — HIPAA Business Associate Agreement (BAA)

> **Required before storing any PHI on AWS. Do this first.**

### Step 5: Sign the AWS BAA
1. Click your account name (top right) → **"Account"**
2. Scroll to **"AWS Artifact"** → click **"Visit AWS Artifact"**
3. Left sidebar → **"Agreements"**
4. Find **"AWS Business Associate Addendum"** → **"Accept agreement"**
5. Read it, check all boxes, click **"Accept"**

This covers Bedrock, HealthLake, Comprehend Medical, and S3 under HIPAA.

---

## Part 4 — AWS Bedrock (Claude via HIPAA BAA)

### Step 6: Enable Bedrock Model Access
1. Search for **"Bedrock"** in the console
2. Left sidebar → **"Model access"**
3. Click **"Manage model access"**
4. Under **"Anthropic"**, check:
   - ✅ **Claude 3.5 Sonnet** (or Claude Sonnet 4 if available)
   - ✅ **Claude 3 Opus**
5. Click **"Request model access"** → Submit
6. Wait ~5 minutes → refresh → status should show **"Access granted"**

### Step 7: Set Up Bedrock Guardrails for PHI (Recommended)
Guardrails automatically mask PHI in AI inputs/outputs.

1. In Bedrock → left sidebar → **"Guardrails"** → **"Create guardrail"**
2. Name: `emr-phi-guardrail`
3. Under **"Sensitive information filters"** → enable **"PII"**
4. Check: SSN, Credit card, email, phone, address, name
5. Set **Action** to `Mask`
6. Click **"Create guardrail"**
7. Copy the **Guardrail ID** (e.g. `abc123def456`) and note version: **"DRAFT"**

---

## Part 5 — AWS HealthLake (FHIR R4 Store)

### Step 8: Create a HealthLake Datastore
1. Search for **"HealthLake"** in the console
2. Click **"Create FHIR datastore"**
3. Configure:
   - **Name**: `concertocare-emr`
   - **FHIR version**: R4
   - **Data encryption**: AWS managed key (default)
   - **Preloaded data**: Off
4. Click **"Create datastore"**
5. Wait ~10–15 minutes for status to become **"ACTIVE"**
6. Click on the datastore → copy the **"Datastore ID"**

The app auto-constructs the endpoint:
```
https://healthlake.{region}.amazonaws.com/datastore/{datastore-id}/r4
```

---

## Part 6 — Comprehend Medical

No manual setup needed — it's a per-call API. Permissions are granted in Step 10.

---

## Part 7 — S3 Bucket (Document Storage)

### Step 9: Create an S3 Bucket
1. Search for **"S3"** → **"Create bucket"**
2. **Bucket name**: `concertocare-emr-docs` (must be globally unique)
3. **Region**: Same as everything else (e.g. `us-east-1`)
4. **Block all public access**: ✅ Leave all boxes checked
5. **Versioning**: Enable
6. **Encryption**: SSE-S3 (Server-side encryption with Amazon S3 managed keys)
7. Click **"Create bucket"**

---

## Part 8 — IAM Permissions for the App

### Step 10: Create a Least-Privilege Policy
1. IAM → **"Policies"** → **"Create policy"** → **"JSON"** tab
2. Paste:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BedrockAccess",
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:ApplyGuardrail"
      ],
      "Resource": "*"
    },
    {
      "Sid": "HealthLakeAccess",
      "Effect": "Allow",
      "Action": [
        "healthlake:GetDatastore",
        "healthlake:CreateResource",
        "healthlake:ReadResource",
        "healthlake:SearchWithPost"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ComprehendMedicalAccess",
      "Effect": "Allow",
      "Action": [
        "comprehendmedical:DetectEntitiesV2",
        "comprehendmedical:InferICD10CM",
        "comprehendmedical:InferRxNorm"
      ],
      "Resource": "*"
    },
    {
      "Sid": "S3Access",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::concertocare-emr-docs",
        "arn:aws:s3:::concertocare-emr-docs/*"
      ]
    }
  ]
}
```

3. Name: `EMRAppPolicy` → **"Create policy"**

### Step 11: Attach the Policy to Your User
1. IAM → **"Users"** → `emr-admin` → **"Add permissions"**
2. **"Attach policies directly"** → search `EMRAppPolicy` → check it → **"Add permissions"**
3. Remove `AdministratorAccess` from the user now that setup is done

---

## Part 9 — Wire It Into the App

### Step 12: Create Your `.env` File

```bash
cd emr/apps/api
cp .env.example .env
```

Open `.env` and fill in your values:

```bash
# ── Database ──────────────────────────────────────────────────────────────────
DATABASE_URL=postgresql+asyncpg://emr:emr@localhost:5432/emr
REDIS_URL=redis://localhost:6379/0
SECRET_KEY=your-random-32-char-string-here

# ── AI: use bedrock for HIPAA BAA coverage ────────────────────────────────────
AI_PROVIDER=bedrock
ANTHROPIC_API_KEY=           # leave blank when AI_PROVIDER=bedrock

# ── AWS credentials (from Step 4) ─────────────────────────────────────────────
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_SESSION_TOKEN=           # leave blank for long-term IAM user keys
AWS_REGION=us-east-1

# ── Bedrock model IDs ─────────────────────────────────────────────────────────
BEDROCK_MODEL_ID=us.anthropic.claude-sonnet-4-5-20251001-v1:0
BEDROCK_MODEL_ID_OPUS=us.anthropic.claude-3-opus-20240229-v1:0

# ── Bedrock Guardrails (from Step 7) ──────────────────────────────────────────
BEDROCK_GUARDRAILS_ID=abc123def456
BEDROCK_GUARDRAILS_VERSION=DRAFT

# ── HealthLake (from Step 8) ──────────────────────────────────────────────────
HEALTHLAKE_DATASTORE_ID=your-datastore-id-here
HEALTHLAKE_ENDPOINT=         # leave blank — auto-constructed

# ── Comprehend Medical ────────────────────────────────────────────────────────
USE_COMPREHEND_MEDICAL=true

# ── S3 ────────────────────────────────────────────────────────────────────────
S3_BUCKET=concertocare-emr-docs

# ── Twilio (for fax/SMS outreach) ─────────────────────────────────────────────
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
FAX_INBOX_NUMBER=

CORS_ORIGINS=["http://localhost:3000"]
```

### Step 13: Verify the Connection

```bash
cd emr/apps/api
pip install -r requirements.txt

# Check Bedrock can see Anthropic models
python3 -c "
import boto3
client = boto3.client('bedrock', region_name='us-east-1')
models = client.list_foundation_models(byProvider='Anthropic')
for m in models['modelSummaries'][:5]:
    print(m['modelId'])
"

# Check HealthLake datastore is ACTIVE
python3 -c "
import boto3, os
hl = boto3.client('healthlake', region_name='us-east-1')
ds = hl.describe_fhir_datastore(DatastoreId=os.environ['HEALTHLAKE_DATASTORE_ID'])
print('Status:', ds['DatastoreProperties']['DatastoreStatus'])
"
```

Both should run without errors.

---

## Checklist

| # | Step | Done |
|---|------|------|
| 1 | Create AWS account | ☐ |
| 2 | Enable root MFA | ☐ |
| 3 | Create IAM user `emr-admin` | ☐ |
| 4 | Create access keys → save both | ☐ |
| **5** | **Sign HIPAA BAA — do this before any PHI** | **☐** |
| 6 | Enable Bedrock model access (Sonnet + Opus) | ☐ |
| 7 | Create Bedrock Guardrail | ☐ |
| 8 | Create HealthLake datastore → wait for ACTIVE | ☐ |
| 9 | Create S3 bucket | ☐ |
| 10 | Create `EMRAppPolicy` | ☐ |
| 11 | Attach policy, remove AdministratorAccess | ☐ |
| 12 | Fill in `.env` from `.env.example` | ☐ |
| 13 | Run smoke tests — both pass | ☐ |

---

## Cost Estimates (approximate)

| Service | Pricing model | Rough cost |
|---------|--------------|------------|
| Bedrock (Claude Sonnet) | Per token | ~$3 / 1M input tokens |
| HealthLake | Per resource + data stored | ~$0.033/resource created |
| Comprehend Medical | Per character | ~$0.01 / 100 chars |
| S3 | Per GB stored + requests | ~$0.023/GB/month |

For a small home care org (~100 patients), expect **< $100/month** until you scale.

---

## Troubleshooting

**Bedrock returns `AccessDeniedException`**
→ Model access is still pending — check the "Model access" page in Bedrock console.

**HealthLake returns `403 Forbidden`**
→ Check `EMRAppPolicy` is attached to your IAM user and the region matches.

**Comprehend Medical returns `ResourceNotFoundException`**
→ The service is region-specific; make sure `AWS_REGION` matches where you enabled it.

**App falls back to local DB even with HealthLake configured**
→ `HEALTHLAKE_DATASTORE_ID` is blank or has extra whitespace in `.env`.
