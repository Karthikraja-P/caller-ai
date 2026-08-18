from fastapi import APIRouter, Depends, Query
from app.core.security import get_current_user
from app.core.rate_limiter import lookup_limiter
from app.core.database import get_admin_db
from app.services.aggregator import waterfall_lookup
import phonenumbers

router = APIRouter(prefix="/lookup", tags=["Lookup"])


@router.get("")
async def lookup_number(
    phone_number: str = Query(..., description="Phone number in E.164 format"),
    user_id: str = Depends(get_current_user),
):
    """Real-time caller identification using waterfall lookup."""
    await lookup_limiter.check(user_id)

    # Normalize
    try:
        parsed = phonenumbers.parse(phone_number)
        phone = phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)
    except Exception:
        phone = phone_number

    # Run waterfall
    result = await waterfall_lookup(phone)

    # Enrich with spam data
    admin = get_admin_db()
    spam_resp = admin.table("spam_reports").select("category, status").eq(
        "reported_number", phone
    ).execute()
    spam_data = spam_resp.data or []
    spam_count = len(spam_data)
    spam_score = min(spam_count * 10, 100)
    categories = list({r["category"] for r in spam_data})

    result["spam_analytics"] = {
        "score": spam_score,
        "report_count": spam_count,
        "categories": categories,
    }

    return result


@router.post("/batch")
async def lookup_batch(
    payload: dict,
    user_id: str = Depends(get_current_user),
):
    """Bulk caller ID lookup (up to 50 numbers)."""
    import asyncio
    numbers = payload.get("phone_numbers", [])[:50]
    results = await asyncio.gather(*[waterfall_lookup(n) for n in numbers])
    cached = sum(1 for r in results if r.get("cache_hit"))
    return {
        "results": results,
        "total": len(results),
        "cached_count": cached,
        "lookup_count": len(results) - cached,
    }


@router.get("/recent")
async def recent_lookups(user_id: str = Depends(get_current_user)):
    """Return recent call log numbers as recent lookups."""
    admin = get_admin_db()
    resp = admin.table("call_logs").select("phone_number, caller_name, created_at").eq(
        "user_id", user_id
    ).order("created_at", desc=True).limit(10).execute()
    return {"lookups": resp.data or []}
