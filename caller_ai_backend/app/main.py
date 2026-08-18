from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import structlog

from app.core.config import settings
from app.api.v1.api import api_router

logger = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting Caller AI Backend", version=settings.APP_VERSION, env=settings.APP_ENV)
    yield
    logger.info("Shutting down Caller AI Backend")


app = FastAPI(
    title="Caller AI API",
    description="AI-Powered Call Management & Voice Assistant Platform",
    version=settings.APP_VERSION,
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
    lifespan=lifespan,
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routes
app.include_router(api_router)


@app.get("/")
async def root():
    return {"service": "Caller AI Backend", "version": settings.APP_VERSION, "status": "running"}
