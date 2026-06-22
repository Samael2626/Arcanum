from sqlalchemy import create_engine
from sqlalchemy.pool import NullPool
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os
from dotenv import load_dotenv

load_dotenv()

SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "")

# pgbouncer transaction mode: no soporta prepared statements fuera de tx,
# NullPool evita conexiones idle que el pooler cierra en silencio.
_engine_kwargs = dict(
    pool_pre_ping=True,
    pool_recycle=1800,
    connect_args={"connect_timeout": 10, "application_name": "arcanum-api"},
)
if "pgbouncer=true" in SQLALCHEMY_DATABASE_URL or ":6543" in SQLALCHEMY_DATABASE_URL:
    _engine_kwargs["poolclass"] = NullPool

engine = create_engine(SQLALCHEMY_DATABASE_URL, **_engine_kwargs)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
