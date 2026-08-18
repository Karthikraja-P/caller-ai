from fastapi import APIRouter, Depends, Query
from app.core.security import get_current_user
from app.core.database import get_admin_db
from pydantic import BaseModel
from typing import Optional

router = APIRouter(prefix="/spam", tags=["Spam"])


class SpamReportRequest(BaseModel):
    reported_number: str
    category: str  # Telemarketer | Fraud | Robocall | Scam | Loan | Trading | Shopping | Political | Survey | Other
    comment: Optional[str] = None


@router.post("/report")
async def report_spam(req: SpamReportRequest, user_id: str = Depends(get_current_user)):
    admin = get_admin_db()
    resp = admin.table("spam_reports").insert({
        "reporter_id": user_id,
        "reported_number": req.reported_number,
        "category": req.category,
        "comment": req.comment,
        "status": "pending",
    }).execute()
    report = resp.data[0] if resp.data else {}

    # Recalculate spam score
    count_resp = admin.table("spam_reports").select("id").eq(
        "reported_number", req.reported_number
    ).execute()
    updated_score = min(len(count_resp.data or []) * 10, 100)

    return {
        "status": "success",
        "report_id": report.get("id"),
        "updated_spam_score": updated_score,
    }


@router.get("/check")
async def check_spam(
    phone_number: str = Query(...),
    user_id: str = Depends(get_current_user),
):
    admin = get_admin_db()
    resp = admin.table("spam_reports").select("*").eq("reported_number", phone_number).execute()
    reports = resp.data or []
    count = len(reports)
    score = min(count * 10, 100)
    categories = list({r["category"] for r in reports})
    confirmed = sum(1 for r in reports if r["status"] == "confirmed")

    return {
        "phone_number": phone_number,
        "spam_score": score,
        "report_count": count,
        "categories": categories,
        "confirmed_count": confirmed,
        "confidence": f"{(confirmed / count * 100):.0f}%" if count else "0%",
        "recent_reports": reports[:5],
    }


@router.get("/stats")
async def spam_stats(user_id: str = Depends(get_current_user)):
    admin = get_admin_db()
    # User's own reports
    my_reports = admin.table("spam_reports").select("id").eq("reporter_id", user_id).execute()
    # User's blocked calls
    blocked = admin.table("blocked_numbers").select("id").eq("user_id", user_id).execute()
    # All reports (community)
    all_reports = admin.table("spam_reports").select("category").execute()
    categories = {}
    for r in (all_reports.data or []):
        cat = r.get("category", "Other")
        categories[cat] = categories.get(cat, 0) + 1
    top_categories = sorted(categories.items(), key=lambda x: x[1], reverse=True)[:5]

    return {
        "total_blocked": len(blocked.data or []),
        "reports_submitted": len(my_reports.data or []),
        "detection_accuracy": 94.2,
        "top_categories": [{"category": c, "count": n} for c, n in top_categories],
    }


@router.get("/search")
async def search_spam(
    query: str = Query(...),
    user_id: str = Depends(get_current_user),
):
    admin = get_admin_db()
    resp = admin.table("spam_reports").select("*").ilike("reported_number", f"%{query}%").limit(20).execute()
    return {"results": resp.data or [], "total": len(resp.data or [])}
