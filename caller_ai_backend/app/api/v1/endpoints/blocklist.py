from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
from app.core.security import get_current_user
from app.core.database import get_admin_db

router = APIRouter(prefix="/blocklist", tags=["Blocklist"])


class BlockRequest(BaseModel):
    phone_number: str
    reason: Optional[str] = None


@router.post("")
async def add_to_blocklist(req: BlockRequest, user_id: str = Depends(get_current_user)):
    admin = get_admin_db()
    try:
        admin.table("blocked_numbers").insert({
            "user_id": user_id,
            "blocked_number": req.phone_number,
            "reason": req.reason,
        }).execute()
    except Exception as e:
        if "duplicate" in str(e).lower():
            raise HTTPException(status_code=409, detail="Number already blocked.")
        raise
    return {"status": "success", "message": f"{req.phone_number} blocked."}


@router.get("")
async def list_blocklist(user_id: str = Depends(get_current_user)):
    admin = get_admin_db()
    resp = admin.table("blocked_numbers").select("*").eq(
        "user_id", user_id
    ).order("created_at", desc=True).execute()
    return {"blocked_numbers": resp.data or [], "total": len(resp.data or [])}


@router.delete("/{phone_number}")
async def remove_from_blocklist(phone_number: str, user_id: str = Depends(get_current_user)):
    admin = get_admin_db()
    admin.table("blocked_numbers").delete().eq("user_id", user_id).eq(
        "blocked_number", phone_number
    ).execute()
    return {"status": "success", "message": f"{phone_number} unblocked."}
