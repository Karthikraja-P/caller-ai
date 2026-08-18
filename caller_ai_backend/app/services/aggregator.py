import json
import time
import httpx
import redis.asyncio as aioredis
from app.core.config import settings

CACHE_TTL = 86400  # 24 hours
_redis = None


async def _get_redis() -> aioredis.Redis:
    global _redis
    if _redis is None:
        _redis = await aioredis.from_url(settings.REDIS_URL, decode_responses=True)
    return _redis


async def cache_get(phone: str) -> dict | None:
    r = await _get_redis()
    val = await r.get(f"lookup:{phone}")
    return json.loads(val) if val else None


async def cache_set(phone: str, data: dict) -> None:
    r = await _get_redis()
    await r.setex(f"lookup:{phone}", CACHE_TTL, json.dumps(data))


async def _telnyx_lookup(phone: str) -> dict | None:
    """Tier 3a: Telnyx CNAM lookup."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(
                f"https://api.telnyx.com/v2/number_lookup/{phone}",
                headers={"Authorization": f"Bearer {settings.TELNYX_API_KEY}"},
                params={"type": "carrier,caller-name"},
            )
            if resp.status_code == 200:
                d = resp.json().get("data", {})
                return {
                    "caller_name": d.get("caller_name", {}).get("caller_name"),
                    "carrier": d.get("carrier", {}).get("name"),
                    "line_type": d.get("line_type"),
                    "country": d.get("country_code"),
                    "source": "telnyx",
                }
    except Exception:
        pass
    return None


async def _trestleiq_lookup(phone: str) -> dict | None:
    """Tier 3b: TrestleIQ caller ID lookup."""
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(
                "https://api.trestleiq.com/3.0/phone",
                params={"api_key": settings.TRESTLEIQ_API_KEY, "phone": phone},
            )
            if resp.status_code == 200:
                d = resp.json()
                names = d.get("belongs_to", [])
                name = names[0].get("name") if names else None
                return {
                    "caller_name": name,
                    "carrier": d.get("carrier"),
                    "line_type": d.get("line_type"),
                    "country": d.get("country_calling_code"),
                    "source": "trestleiq",
                }
    except Exception:
        pass
    return None


async def _apify_osint(phone: str) -> dict | None:
    """Tier 4: Apify OSINT scrape (slowest, last resort)."""
    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            # Start actor run
            run_resp = await client.post(
                "https://api.apify.com/v2/acts/vdrmota~phone-number-lookup/runs",
                headers={"Authorization": f"Bearer {settings.APIFY_API_TOKEN}"},
                json={"phoneNumber": phone},
            )
            if run_resp.status_code not in (200, 201):
                return None
            run_id = run_resp.json().get("data", {}).get("id")

            # Poll for result (max 10s)
            for _ in range(5):
                await asyncio.sleep(2)
                result_resp = await client.get(
                    f"https://api.apify.com/v2/acts/vdrmota~phone-number-lookup/runs/{run_id}/dataset/items",
                    headers={"Authorization": f"Bearer {settings.APIFY_API_TOKEN}"},
                )
                items = result_resp.json()
                if items:
                    item = items[0]
                    return {
                        "caller_name": item.get("name"),
                        "carrier": item.get("carrier"),
                        "source": "apify",
                    }
    except Exception:
        pass
    return None


async def waterfall_lookup(phone: str) -> dict:
    """
    Multi-tier waterfall:
    Tier 1: Redis cache (5ms)
    Tier 2: Country/carrier registry (static)
    Tier 3: Telnyx + TrestleIQ CNAM (parallel, ~500ms)
    Tier 4: Apify OSINT (~800ms, last resort)
    """
    import asyncio
    start = time.monotonic()

    # Tier 1: Cache
    cached = await cache_get(phone)
    if cached:
        cached["cache_hit"] = True
        cached["latency_ms"] = int((time.monotonic() - start) * 1000)
        return cached

    # Tier 3: Parallel Telnyx + TrestleIQ
    results = await asyncio.gather(
        _telnyx_lookup(phone),
        _trestleiq_lookup(phone),
        return_exceptions=True,
    )

    result = None
    for r in results:
        if isinstance(r, dict) and r.get("caller_name"):
            result = r
            break

    # Tier 4: Apify fallback
    if not result or not result.get("caller_name"):
        apify_result = await _apify_osint(phone)
        if apify_result:
            result = apify_result

    if not result:
        result = {}

    final = {
        "phone_number": phone,
        "caller_name": result.get("caller_name"),
        "carrier": result.get("carrier"),
        "line_type": result.get("line_type", "unknown"),
        "country": result.get("country"),
        "source": result.get("source", "unknown"),
        "cache_hit": False,
        "latency_ms": int((time.monotonic() - start) * 1000),
    }

    # Cache the result
    await cache_set(phone, final)
    return final
