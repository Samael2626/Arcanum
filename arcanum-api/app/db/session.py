import os
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import QueuePool

load_dotenv()
Base = declarative_base()
engine = None
SessionLocal = None

def get_pool_class(database_url: str):
    return QueuePool

def get_database_url() -> str:
    """Unica fuente de la URL de base de datos del backend.

    El engine y las migraciones leen de aqui: dos constantes separadas para la
    misma URL es como se llega a que una apunte a otra base sin que nadie lo note.
    """
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL requerida para inicializar la base de datos")
    return database_url

def get_engine():
    get_session_factory()
    return engine

def get_session_factory():
    global engine, SessionLocal
    if SessionLocal is not None:
        return SessionLocal
    database_url = get_database_url()
    engine = create_engine(
        database_url,
        pool_pre_ping=True,
        pool_recycle=1800,
        pool_size=5,
        max_overflow=5,
        pool_timeout=10,
        connect_args={"connect_timeout": 10, "application_name": "arcanum-api"},
        poolclass=get_pool_class(database_url),
    )
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    return SessionLocal

def get_db():
    db = get_session_factory()()
    try:
        yield db
    finally:
        db.close()