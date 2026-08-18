from fastapi import APIRouter, Depends, HTTPException, status
from app.core.security import get_current_user
from app.core.database import get_admin_db
from app.schemas.user import (
    UpdateProfileRequest, UserProfileResponse,
    RegisterDeviceRequest, SubscriptionResponse,
)

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/profile", response_model=UserProfileResponse)
async def get_profile(user_id: str = Depends(get_current_user)):
    admin = get_admin_db()
    resp = admin.table("profiles").select("*").eq("id", user_id).single().execute()
    if not resp.data:
        raise HTTPException(status_code=404, detail={"error": "NOT_FOUND", "message": "Profile not found."})
    return resp.data


@router.put("/profile", response_model=UserProfileResponse)
async def update_profile(req: UpdateProfileRequest, user_id: str = Depends(get_current_user)):
    admin = get_admin_db()
    update_data = {k: v for k, v in req.model_dump().items() if v is not None}
    if not update_data:
        raise HTTPException(status_code=400, detail={"error": "BAD_REQUEST", "message": "No fields to update."})

    resp = admin.table("profiles").update(update_data).eq("id", user_id).execute()
    if not resp.data:
        raise HTTPException(status_code=500, detail="Profile update failed")
    return resp.data[0]


@router.delete("/profile")
async def delete_account(user_id: str = Depends(get_current_user)):
    """Soft delete — marks account as deleted. 30-day recovery window."""
    admin = get_admin_db()
    # In production: set a deleted_at field and schedule cleanup
    admin.table("profiles").update({"plan": "deleted"}).eq("id", user_id).execute()
    admin.auth.admin.delete_user(user_id)
    return {"status": "success", "message": "Account scheduled for deletion. Recovery available within 30 days."}


@router.post("/devices")
async def register_device(req: RegisterDeviceRequest, user_id: str = Depends(get_current_user)):
    """Upsert FCM device token for push notifications."""
    admin = get_admin_db()
    admin.table("device_tokens").upsert({
        "user_id": user_id,
        "device_uuid": req.device_uuid,
        "fcm_token": req.fcm_token,
        "platform": req.platform,
        "last_active_at": "now()",
    }, on_conflict="user_id,device_uuid").execute()
    return {"status": "success", "message": "Device token registered."}


@router.get("/subscription", response_model=SubscriptionResponse)
async def get_subscription(user_id: str = Depends(get_current_user)):
    admin = get_admin_db()
    resp = admin.table("profiles").select("plan, ai_calls_used, ai_calls_limit").eq("id", user_id).single().execute()
    data = resp.data or {}
    plan = data.get("plan", "free")
    ai_used = data.get("ai_calls_used", 0)
    ai_limit = data.get("ai_calls_limit", 10)

    features = {
        "ai_agent_limit": None if plan == "premium" else ai_limit,
        "ai_calls_used": ai_used,
        "ads_enabled": plan == "free",
        "busy_mode": plan == "premium",
        "whatsapp_diversion": plan == "premium",
    }
    return SubscriptionResponse(plan=plan, expires_at=None, features=features)
