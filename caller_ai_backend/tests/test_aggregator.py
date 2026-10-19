import asyncio
import sys
from unittest.mock import AsyncMock, MagicMock, patch

# Provide lightweight module stubs so regression test runs in isolated environments
if "redis" not in sys.modules:
    sys.modules["redis"] = MagicMock()
if "redis.asyncio" not in sys.modules:
    sys.modules["redis.asyncio"] = MagicMock()

import pytest
from app.services.aggregator import _apify_osint


@pytest.mark.anyio
async def test_apify_osint_success_resolves_without_name_error():
    """Verify _apify_osint executes asyncio.sleep without NameError and parses result."""
    fake_phone = "+15550001111"
    fake_run_id = "test-run-id-123"

    mock_run_response = MagicMock()
    mock_run_response.status_code = 201
    mock_run_response.json.return_value = {"data": {"id": fake_run_id}}

    mock_items_response = MagicMock()
    mock_items_response.status_code = 200
    mock_items_response.json.return_value = [
        {"name": "Test Caller", "carrier": "Test Carrier"}
    ]

    mock_client = AsyncMock()
    mock_client.post.return_value = mock_run_response
    mock_client.get.return_value = mock_items_response

    mock_client_cm = AsyncMock()
    mock_client_cm.__aenter__.return_value = mock_client
    mock_client_cm.__aexit__.return_value = None

    with patch("httpx.AsyncClient", return_value=mock_client_cm), \
         patch("asyncio.sleep", new_callable=AsyncMock) as mock_sleep:
        result = await _apify_osint(fake_phone)

        assert mock_sleep.called
        assert mock_sleep.call_args[0][0] == 2
        assert result == {
            "caller_name": "Test Caller",
            "carrier": "Test Carrier",
            "source": "apify",
        }


@pytest.mark.anyio
async def test_apify_osint_actor_run_failure_returns_none():
    """Verify non-200/201 actor run initialization returns None gracefully."""
    fake_phone = "+15550001111"

    mock_run_response = MagicMock()
    mock_run_response.status_code = 400

    mock_client = AsyncMock()
    mock_client.post.return_value = mock_run_response

    mock_client_cm = AsyncMock()
    mock_client_cm.__aenter__.return_value = mock_client
    mock_client_cm.__aexit__.return_value = None

    with patch("httpx.AsyncClient", return_value=mock_client_cm):
        result = await _apify_osint(fake_phone)
        assert result is None


def test_apify_osint_sync_runner():
    """Synchronous test harness exercising async _apify_osint via asyncio.run."""
    asyncio.run(test_apify_osint_success_resolves_without_name_error())
    asyncio.run(test_apify_osint_actor_run_failure_returns_none())
