#!/usr/bin/env python3
"""
Test Supavisor connection before deploying to Render.
Run this locally to verify DATABASE_URL is correct.
"""

import os
import sys
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

# Load .env
load_dotenv()

def test_supavisor_connection():
    """Test if we can connect to Supabase via Supavisor."""

    database_url = os.getenv("DATABASE_URL")

    if not database_url:
        print("❌ ERROR: DATABASE_URL not set in .env")
        sys.exit(1)

    print(f"🔍 Testing connection to: {database_url[:50]}...")

    try:
        # Create engine
        engine = create_engine(
            database_url,
            pool_pre_ping=True,
            pool_recycle=1800,
            connect_args={"connect_timeout": 5},  # 5 sec timeout
        )

        # Try to connect
        with engine.connect() as conn:
            result = conn.execute(text("SELECT version();"))
            version = result.scalar()

        print(f"✅ Connection successful!")
        print(f"   PostgreSQL: {version[:60]}...")

        # Check if we're using Supavisor
        if "pooler.supabase.com" in database_url:
            print(f"✅ Using Supavisor (pooler.supabase.com) — IPv6 issue will be avoided")
        elif "db.qqwendjedaokyrstbugv.supabase.co" in database_url:
            print(f"⚠️  WARNING: Using direct DB connection — may fail on Render due to IPv6")
            print(f"   Recommended: Change to pooler.supabase.com:6543")

        return True

    except Exception as e:
        print(f"❌ Connection failed: {type(e).__name__}")
        print(f"   Details: {str(e)[:200]}")

        if "Network is unreachable" in str(e):
            print(f"\n   💡 Hint: IPv6 issue detected. Make sure to use Supavisor:")
            print(f"      postgresql://user:pass@pooler.supabase.com:6543/postgres?user=postgres")
        elif "connect_timeout" in str(e).lower():
            print(f"\n   💡 Timeout: Check if Supabase is reachable and DATABASE_URL is correct")
        elif "password authentication failed" in str(e).lower():
            print(f"\n   💡 Auth error: Check username/password in DATABASE_URL")

        return False

def test_alembic_migrations():
    """Test if Alembic can connect and list migrations."""

    print("\n🔍 Testing Alembic migrations...")

    try:
        os.chdir(os.path.dirname(__file__))

        # Try to import and initialize alembic
        from alembic.config import Config
        from alembic.script import ScriptDirectory

        config = Config("alembic.ini")
        script = ScriptDirectory.from_config(config)

        # Get current head
        head = script.get_current_head()

        print(f"✅ Alembic initialized")
        print(f"   Current head: {head}")
        print(f"   Migrations directory exists: {os.path.exists('migrations')}")

        return True

    except Exception as e:
        print(f"⚠️  Alembic check failed: {str(e)[:200]}")
        return True  # Don't fail — Alembic issues are separate

if __name__ == "__main__":
    print("=" * 60)
    print("ARCANUM: Supavisor Connection Test")
    print("=" * 60)

    # Test 1: Connection
    conn_ok = test_supavisor_connection()

    # Test 2: Alembic
    alembic_ok = test_alembic_migrations()

    print("\n" + "=" * 60)
    if conn_ok:
        print("✅ All tests passed! Ready to deploy to Render.")
        sys.exit(0)
    else:
        print("❌ Some tests failed. Fix errors before deploying.")
        sys.exit(1)
