from fastapi import APIRouter

router = APIRouter(prefix="/health", tags=["Health"])


@router.get("")
async def health():
    return {"status": "ok", "version": "2.0.0", "service": "caller-ai-backend"}


@router.get("/ready")
async def readiness():
    """Kubernetes readiness probe — checks Redis + Supabase."""
    checks = {}
    try:
        from app.core.rate_limiter import get_redis
        r = await get_redis()
        await r.ping()
        checks["redis"] = "ok"
    except Exception as e:
        checks["redis"] = f"error: {str(e)}"

    try:
        from app.core.database import get_supabase_client
        client = get_supabase_client()
        client.table("profiles").select("id").limit(1).execute()
        checks["supabase"] = "ok"
    except Exception as e:
        checks["supabase"] = f"error: {str(e)}"

    all_ok = all(v == "ok" for v in checks.values())
    return {"ready": all_ok, "checks": checks}
