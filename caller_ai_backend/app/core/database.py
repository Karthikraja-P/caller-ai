from supabase import create_client, Client
from supabase.lib.client_options import ClientOptions
from app.core.config import settings
from functools import lru_cache


@lru_cache(maxsize=1)
def get_supabase_client() -> Client:
    """Supabase client using anon key (respects RLS)."""
    return create_client(
        settings.SUPABASE_URL,
        settings.SUPABASE_ANON_KEY,
        options=ClientOptions(auto_refresh_token=False, persist_session=False),
    )


@lru_cache(maxsize=1)
def get_supabase_admin() -> Client:
    """Supabase admin client using service key (bypasses RLS)."""
    return create_client(
        settings.SUPABASE_URL,
        settings.SUPABASE_SERVICE_KEY,
        options=ClientOptions(auto_refresh_token=False, persist_session=False),
    )


# Dependency aliases
def get_db() -> Client:
    return get_supabase_client()


def get_admin_db() -> Client:
    return get_supabase_admin()
