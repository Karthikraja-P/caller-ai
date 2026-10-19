from fastapi import APIRouter
from app.api.v1.endpoints import (
    auth, users, lookup, spam, whatsapp, blocklist, health, voicemail
)

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(lookup.router)
api_router.include_router(spam.router)
api_router.include_router(whatsapp.router)
api_router.include_router(blocklist.router)
api_router.include_router(health.router)
api_router.include_router(voicemail.router)
