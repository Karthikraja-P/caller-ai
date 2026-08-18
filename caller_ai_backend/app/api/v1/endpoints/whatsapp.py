from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from app.core.security import get_current_user
from app.core.database import get_admin_db
from app.core.whatsapp_client import send_whatsapp_message, get_whatsapp_connection_status

router = APIRouter(prefix="/whatsapp", tags=["WhatsApp Bridge"])


class DivertRequest(BaseModel):
    phone_number: str
    contact_name: Optional[str] = None
    auto_reply_template: str = "Hi, I'm currently unavailable. Please message me on WhatsApp."


class SendMessageRequest(BaseModel):
    to_number: str
    message: str


@router.get("/status")
async def whatsapp_status(user_id: str = Depends(get_current_user)):
    return await get_whatsapp_connection_status()


@router.post("/divert")
async def enable_diversion(req: DivertRequest, user_id: str = Depends(get_current_user)):
    admin = get_admin_db()
    admin.table("whatsapp_diversions").upsert({
        "user_id": user_id,
        "contact_number": req.phone_number,
        "contact_name": req.contact_name,
        "auto_reply_template": req.auto_reply_template,
        "is_active": True,
    }, on_conflict="user_id,contact_number").execute()
    return {"status": "success", "message": f"Diversion enabled for {req.phone_number}"}


@router.delete("/divert/{phone_number}")
async def disable_diversion(phone_number: str, user_id: str = Depends(get_current_user)):
    admin = get_admin_db()
    admin.table("whatsapp_diversions").update({"is_active": False}).eq(
        "user_id", user_id
    ).eq("contact_number", phone_number).execute()
    return {"status": "success", "message": "Diversion disabled"}


@router.post("/send-message")
async def whatsapp_send(req: SendMessageRequest, user_id: str = Depends(get_current_user)):
    result = await send_whatsapp_message(req.to_number, req.message)
    return {"status": "success", "result": result}


@router.get("/history")
async def whatsapp_history(user_id: str = Depends(get_current_user)):
    admin = get_admin_db()
    resp = admin.table("whatsapp_diversions").select("*").eq(
        "user_id", user_id
    ).order("created_at", desc=True).execute()
    return {"diversions": resp.data or []}
