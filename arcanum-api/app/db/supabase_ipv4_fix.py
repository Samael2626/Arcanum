"""
SQLAlchemy engine configuration with Supabase IPv4 workaround.

This module handles the connection to Supabase with fallback strategies
for IPv6 issues on Render.

Primary: Supavisor (pooler.supabase.com)
Fallback: hostaddr parameter with explicit IPv4 (requires manual IP lookup)
"""

import os
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://user:password@localhost:5432/arcanum_db"
)

def get_engine():
    """
    Create SQLAlchemy engine with IPv4 workarounds.

    Strategies in order:
    1. If using Supavisor (pooler.supabase.com) — use as-is, IPv4 guaranteed
    2. If using direct Supabase DB — try hostaddr workaround (if IP provided)
    3. Fallback to standard connection (for local dev)
    """

    connect_args = {
        "connect_timeout": 5,  # 5 second timeout for Render health check
        "keepalives": 1,       # Enable TCP keepalives
        "keepalives_idle": 30, # Idle timeout (30 sec) — Supabase default
    }

    # If using Supavisor, no special args needed
    if "pooler.supabase.com" in DATABASE_URL:
        pass  # Supavisor handles IPv4 automatically

    # If using direct DB and we have an IPv4 override, use it
    elif "db.qqwendjedaokyrstbugv.supabase.co" in DATABASE_URL:
        ipv4_override = os.getenv("SUPABASE_IPV4_ADDRESS")
        if ipv4_override:
            # Use explicit IPv4 address instead of DNS resolution
            # This bypasses IPv6 DNS records entirely
            connect_args["hostaddr"] = ipv4_override
            print(f"⚠️  Using IPv4 override: {ipv4_override}")
        else:
            print(
                "⚠️  WARNING: Using direct Supabase connection without Supavisor.\n"
                "   This may fail on Render due to IPv6.\n"
                "   Recommended: Switch to pooler.supabase.com (Supavisor)"
            )

    # Create engine with connection pooling
    engine = create_engine(
        DATABASE_URL,
        poolclass=QueuePool,
        pool_size=5,           # Connections to keep in pool
        max_overflow=10,       # Extra connections beyond pool_size
        pool_pre_ping=True,    # Test connection before use (discard dead ones)
        pool_recycle=1800,     # Recycle connections every 30 min (Supabase default)
        echo=False,            # Set to True for SQL debug logging
        connect_args=connect_args,
    )

    return engine

# Create singleton engine
engine = get_engine()

if __name__ == "__main__":
    # Test script
    print("Testing database connection...")
    try:
        with engine.connect() as conn:
            result = conn.execute("SELECT version();")
            print(f"✅ Connected! {result.scalar()[:60]}...")
    except Exception as e:
        print(f"❌ Connection failed: {e}")
