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

    anthropic_api_key: str = ""
    ai_model: str = "claude-sonnet-4-6"
    ai_model_opus: str = "claude-opus-4-7"

    # Fax / document ingestion
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    fax_inbox_number: str = ""

    # S3 for document storage
    aws_access_key_id: str = ""
    aws_secret_access_key: str = ""
    aws_region: str = "us-east-1"
    s3_bucket: str = "concertocare-emr-docs"

    cors_origins: list[str] = ["http://localhost:3000"]

    class Config:
        env_file = ".env"


@lru_cache
def get_settings() -> Settings:
    return Settings()
