from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    app_name: str = "ConcertoCare EMR"
    app_version: str = "0.1.0"
    debug: bool = False

    database_url: str = "postgresql+asyncpg://emr:emr@localhost:5432/emr"
    redis_url: str = "redis://localhost:6379/0"

    secret_key: str = "change-me-in-production"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 480

    # AI — set AI_PROVIDER=bedrock to route through AWS Bedrock instead of direct Anthropic
    ai_provider: str = "anthropic"  # "anthropic" | "bedrock"
    anthropic_api_key: str = ""
    ai_model: str = "claude-sonnet-4-6"
    ai_model_opus: str = "claude-opus-4-7"

    # Bedrock model IDs (cross-region inference profiles recommended)
    bedrock_model_id: str = "us.anthropic.claude-sonnet-4-5-20251001-v1:0"
    bedrock_model_id_opus: str = "us.anthropic.claude-3-opus-20240229-v1:0"
    bedrock_guardrails_id: str = ""   # optional — Bedrock Guardrail for PII redaction
    bedrock_guardrails_version: str = "DRAFT"

    # AWS — shared by S3, HealthLake, Bedrock, Comprehend Medical
    aws_access_key_id: str = ""
    aws_secret_access_key: str = ""
    aws_session_token: str = ""       # for assumed-role / SSO
    aws_region: str = "us-east-1"

    # S3 for document storage
    s3_bucket: str = "concertocare-emr-docs"

    # AWS HealthLake — set HEALTHLAKE_DATASTORE_ID to enable real FHIR store
    healthlake_datastore_id: str = ""
    healthlake_endpoint: str = ""     # auto-built from region if blank

    # AWS Comprehend Medical — set USE_COMPREHEND=true to enable NLP on ingested docs
    use_comprehend_medical: bool = False

    # Fax ingestion
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    fax_inbox_number: str = ""

    cors_origins: list[str] = ["http://localhost:3000"]

    class Config:
        env_file = ".env"


@lru_cache
def get_settings() -> Settings:
    return Settings()
