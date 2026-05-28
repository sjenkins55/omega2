from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from app.core.config import get_settings
from app.db.base import engine, Base

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from app.models import territory as _territory_models  # ensure table is created
from app.api.routes import patients, visits, ingestion, workflows, engagement, admin

app.include_router(patients.router, prefix="/api/v1")
app.include_router(visits.router, prefix="/api/v1")
app.include_router(ingestion.router, prefix="/api/v1")
app.include_router(workflows.router, prefix="/api/v1")
app.include_router(engagement.router, prefix="/api/v1")
app.include_router(admin.router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok", "version": settings.app_version}
