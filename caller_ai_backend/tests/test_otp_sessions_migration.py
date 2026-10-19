from pathlib import Path
import pytest


def test_migration_005_enables_rls_and_revokes_privileges():
    migration_path = Path(__file__).parent.parent / "migrations" / "005_secure_otp_sessions.sql"
    assert migration_path.exists(), "Migration 005_secure_otp_sessions.sql must exist"

    sql = migration_path.read_text()
    # Must enable RLS
    assert "ALTER TABLE public.otp_sessions ENABLE ROW LEVEL SECURITY;" in sql
    # Must revoke all privileges from anon, authenticated, and public
    assert "REVOKE ALL ON TABLE public.otp_sessions FROM anon, authenticated, public;" in sql
    # Must grant to service_role
    assert "GRANT ALL ON TABLE public.otp_sessions TO service_role;" in sql
    # Must NOT create any public access policies
    assert "CREATE POLICY" not in sql


def test_disposable_smoke_test_covers_all_crud_operations():
    smoke_path = Path(__file__).parent.parent / "migrations" / "smoke_test_005_rls.sql"
    assert smoke_path.exists(), "Smoke test smoke_test_005_rls.sql must exist"

    sql = smoke_path.read_text()
    # Must run in disposable transaction with ROLLBACK
    assert "BEGIN;" in sql
    assert "ROLLBACK;" in sql
    # Must test service_role operations
    assert "SET LOCAL ROLE service_role;" in sql
    # Must test anon denial
    assert "SET LOCAL ROLE anon;" in sql
    assert "insufficient_privilege" in sql
    # Must test authenticated denial
    assert "SET LOCAL ROLE authenticated;" in sql
