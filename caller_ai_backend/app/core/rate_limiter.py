import time
import redis.asyncio as aioredis
from fastapi import HTTPException, Request, status
from app.core.config import settings

_redis_client = None


async def get_redis() -> aioredis.Redis:
    global _redis_client
    if _redis_client is None:
        _redis_client = await aioredis.from_url(
            settings.REDIS_URL, encoding="utf-8", decode_responses=True
        )
    return _redis_client


class RateLimiter:
    """
    Sliding window rate limiter using Redis sorted sets.
    window_seconds: time window
    max_requests: max allowed requests in that window
    key_prefix: namespace for this limiter
    """

    def __init__(self, max_requests: int, window_seconds: int, key_prefix: str = "rl"):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.key_prefix = key_prefix

    async def check(self, identifier: str) -> None:
        """Raises 429 if rate limit exceeded."""
        r = await get_redis()
        key = f"{self.key_prefix}:{identifier}"
        now = time.time()
        window_start = now - self.window_seconds

        pipe = r.pipeline()
        pipe.zremrangebyscore(key, 0, window_start)
        pipe.zcard(key)
        pipe.zadd(key, {str(now): now})
        pipe.expire(key, self.window_seconds)
        results = await pipe.execute()

        count = results[1]
        if count >= self.max_requests:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "error": "RATE_LIMITED",
                    "message": f"Rate limit exceeded. Max {self.max_requests} requests per {self.window_seconds}s.",
                    "retry_after": self.window_seconds,
                },
            )


# Pre-configured limiters
otp_limiter = RateLimiter(max_requests=5, window_seconds=3600, key_prefix="otp")
lookup_limiter = RateLimiter(max_requests=100, window_seconds=60, key_prefix="lookup")
