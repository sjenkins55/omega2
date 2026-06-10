# AWS Pilot Deployment Guide — ConcertoCare EMR

Step-by-step setup for a first pilot (1–2 agencies, up to ~50 users) on a
HIPAA-eligible AWS stack. Estimated time: 2–3 hours. Estimated cost:
**$60–100/month**.

## Architecture (pilot scale)

```
Clinicians ──► AWS Amplify Hosting (Next.js frontend, HTTPS + CDN)
                     │  API calls
                     ▼
              AWS App Runner (FastAPI container, auto-HTTPS)
                     │
        ┌────────────┼──────────────┬─────────────────┐
        ▼            ▼              ▼                 ▼
   RDS PostgreSQL   S3 bucket   AWS Bedrock      Secrets Manager
   (patient data)   (docs/photos) (Claude, HIPAA)  (keys)
```

Why App Runner instead of ECS for the pilot: built-in HTTPS, no load
balancer ($18/mo) or NAT gateway ($35/mo) to pay for, scales to zero
config. Move to ECS Fargate + Aurora when you pass ~5 agencies (see
"Scaling up" at the end).

---

## Step 0 — Account + HIPAA BAA (15 min)

1. Create an AWS account at https://aws.amazon.com (business email, credit card).
2. **Sign the Business Associate Addendum** — required before any PHI:
   - Console → **AWS Artifact** → Agreements → Account agreements
   - Accept the **AWS Business Associate Addendum (BAA)**. It's self-service and free.
3. Enable MFA on the root account (IAM → root user → MFA), then create an
   IAM admin user for daily use — never use root again.
4. Pick **us-east-1** (N. Virginia) as your region for everything below
   (it has the best Bedrock model availability).

## Step 1 — Database: RDS PostgreSQL (20 min)

Console → RDS → Create database:

| Setting | Value |
|---|---|
| Engine | PostgreSQL 16 |
| Template | Free tier (or Dev/Test) |
| Instance | `db.t4g.micro` |
| Storage | 20 GB gp3, **enable storage autoscaling** |
| Multi-AZ | No (pilot) — turn on before real production |
| DB name | `emr` |
| Master username | `emr` |
| Password | auto-generate, save it |
| **Encryption** | **Enabled** (default KMS key) — required for HIPAA |
| Public access | **No** |
| VPC | default VPC |

After creation, note the endpoint, e.g.
`concertocare-db.xxxx.us-east-1.rds.amazonaws.com`.

Your `DATABASE_URL` will be:

```
postgresql+asyncpg://emr:PASSWORD@concertocare-db.xxxx.us-east-1.rds.amazonaws.com:5432/emr
```

> Networking note: App Runner needs a **VPC connector** to reach a private
> RDS instance. App Runner → your service → Networking → Outgoing traffic →
> Custom VPC → select the default VPC subnets + the RDS security group.
> Then edit the RDS security group to allow inbound 5432 from that
> security group.

## Step 2 — Container registry: push the API image (15 min)

On any machine with Docker and the AWS CLI (`aws configure` with your IAM
admin keys):

```bash
# Create the repo
aws ecr create-repository --repository-name concertocare-api --region us-east-1

# Log in, build, push
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

cd emr/apps/api
docker build -t concertocare-api .
docker tag concertocare-api:latest <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/concertocare-api:latest
docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/concertocare-api:latest
```

(The Dockerfile already exists at `emr/apps/api/Dockerfile`.)

## Step 3 — Bedrock: enable Claude (5 min)

1. Console → **Amazon Bedrock** → Model access → Modify model access
2. Request access to **Anthropic Claude** models (Sonnet at minimum).
   Approval is usually instant.
3. No API key needed — the App Runner instance role grants access (Step 4).

This is the HIPAA-compliant path to Claude: Bedrock is covered by the AWS
BAA; the direct Anthropic API is not.

## Step 4 — S3 + IAM role (10 min)

```bash
# Document/photo bucket — pick a globally unique name
aws s3api create-bucket --bucket concertocare-emr-docs-<yourorg> --region us-east-1
aws s3api put-bucket-encryption --bucket concertocare-emr-docs-<yourorg> \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"aws:kms"}}]}'
aws s3api put-public-access-block --bucket concertocare-emr-docs-<yourorg> \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Create an IAM role for the API (IAM → Roles → Create role → Custom trust
policy for `tasks.apprunner.amazonaws.com`) with this inline policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::concertocare-emr-docs-<yourorg>",
        "arn:aws:s3:::concertocare-emr-docs-<yourorg>/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"],
      "Resource": "*"
    }
  ]
}
```

## Step 5 — App Runner: deploy the API (20 min)

Console → App Runner → Create service:

| Setting | Value |
|---|---|
| Source | Container registry → ECR → `concertocare-api:latest` |
| Deployment | Automatic (redeploys on new image push) |
| CPU / memory | 0.5 vCPU / 1 GB |
| Port | 8000 |
| Health check | HTTP, path `/health` |
| Instance role | the IAM role from Step 4 |
| Networking → Outgoing | Custom VPC (see Step 1 note) |

Environment variables (these map 1:1 to `app/core/config.py`):

| Variable | Value |
|---|---|
| `ENVIRONMENT` | `production` |
| `DATABASE_URL` | from Step 1 |
| `SECRET_KEY` | run `python -c "import secrets; print(secrets.token_hex(32))"` |
| `AI_PROVIDER` | `bedrock` |
| `AWS_REGION` | `us-east-1` |
| `S3_BUCKET` | `concertocare-emr-docs-<yourorg>` |
| `CORS_ORIGINS` | `["https://YOUR-FRONTEND-DOMAIN"]` (fill in after Step 6) |
| `ADT_API_KEY` | random value if a hospital will send ADT; else leave unset |

> The app refuses to boot in production with the default `SECRET_KEY` —
> that's intentional.

Create the service; you'll get a URL like
`https://xxxx.us-east-1.awsapprunner.com`. Verify:

```bash
curl https://xxxx.us-east-1.awsapprunner.com/health
# {"status":"ok","version":"0.1.0"}
```

Tables are created automatically on first boot. To seed the first
super-admin, run the seed script once against the production DB (from a
machine that can reach RDS, or temporarily via an App Runner job):

```bash
DATABASE_URL=postgresql+asyncpg://... python -m app.db.seed
# Prints the generated admin password ONCE — store it in a password manager
```

## Step 6 — Frontend: Amplify Hosting (20 min)

1. Console → **AWS Amplify** → Create new app → GitHub → select this repo
   and branch.
2. Set the app root to `emr/apps/web` (monorepo setting).
3. Build settings (Amplify usually autodetects Next.js; confirm):

```yaml
version: 1
applications:
  - appRoot: emr/apps/web
    frontend:
      phases:
        preBuild:
          commands: ["npm ci"]
        build:
          commands: ["npm run build"]
      artifacts:
        baseDirectory: .next
        files: ["**/*"]
      cache:
        paths: ["node_modules/**/*"]
```

4. Environment variable: `NEXT_PUBLIC_API_URL` =
   `https://xxxx.us-east-1.awsapprunner.com/api/v1`
5. Deploy. You'll get `https://main.xxxx.amplifyapp.com`.
6. Go back to App Runner and set `CORS_ORIGINS` to that URL (JSON list).

Because Amplify serves over HTTPS, the **PWA install prompt works
immediately** — clinicians can install ConcertoCare as a desktop/tablet app
from the browser.

## Step 7 — Custom domain (optional, 15 min)

- Route 53 → register or import your domain (~$13/yr)
- Amplify → Domain management → add `app.yourdomain.com`
- App Runner → Custom domains → add `api.yourdomain.com`
- Update `NEXT_PUBLIC_API_URL` and `CORS_ORIGINS` accordingly

## Go-live checklist (HIPAA)

- [ ] BAA accepted in AWS Artifact (Step 0)
- [ ] RDS encryption at rest enabled; RDS not publicly accessible
- [ ] S3 bucket encrypted, public access blocked
- [ ] `ENVIRONMENT=production` and unique `SECRET_KEY` set
- [ ] `AI_PROVIDER=bedrock` (PHI never goes to the direct Anthropic API)
- [ ] Seed admin password stored in a password manager, not in chat/email
- [ ] RDS automated backups on (7-day retention is the default)
- [ ] CloudWatch log retention set (App Runner logs → 90 days+)
- [ ] Each clinician gets their own account with `licensed_states` set —
      this drives the HIPAA minimum-necessary AI chat scoping
- [ ] MFA on all AWS console users

## Monthly cost (pilot)

| Service | Est. $/mo |
|---|---|
| App Runner (0.5 vCPU / 1 GB, always on) | ~$25 |
| RDS db.t4g.micro + 20 GB | ~$15 (free tier year 1: ~$0) |
| Amplify Hosting | ~$1–5 |
| S3 + ECR | ~$2 |
| Bedrock (Claude, ~10 chat questions/user/day) | ~$3–4 per user |
| Secrets Manager / CloudWatch / Route 53 | ~$5 |
| **Total (15-user pilot)** | **~$60–100** |

## Scaling up (when the pilot outgrows this)

| Trigger | Change |
|---|---|
| ~5+ agencies | App Runner → ECS Fargate + ALB; RDS → Multi-AZ |
| ~20+ agencies | RDS → Aurora Serverless v2; add ElastiCache Redis + Celery workers for background AI jobs |
| ~100+ agencies | Schema-per-tenant isolation, dedicated clusters for enterprise clients |
| Heavy fax/OCR volume | Move Tesseract OCR to a Celery worker service (it's CPU-bound) |
| Audit/compliance growth | Add AWS Config + CloudTrail organization trail + GuardDuty |
