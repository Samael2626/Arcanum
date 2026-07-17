from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os
from dotenv import load_dotenv

load_dotenv()

SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "")

def get_pool_class(database_url: str):
    """Reutiliza conexiones también detrás de Supavisor/PgBouncer.

    El driver es psycopg2, por lo que no arrastra prepared statements entre
    transacciones. pool_pre_ping y pool_recycle descartan sockets vencidos.
    """
    return QueuePool

_engine_kwargs = dict(
    pool_pre_ping=True,
    pool_recycle=1800,
    pool_size=5,
    max_overflow=5,
    pool_timeout=10,
    connect_args={"connect_timeout": 10, "application_name": "arcanum-api"},
    poolclass=get_pool_class(SQLALCHEMY_DATABASE_URL),
)

engine = create_engine(SQLALCHEMY_DATABASE_URL, **_engine_kwargs)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
