from fastapi import FastAPI
from app.core.middleware import ProcessTimeMiddleware
from app.routers import auth, users
from app.db.session import Base, engine

app = FastAPI(
    title="Arcanum API",
    description="Backend for Arcanum app",
    version="0.1.0"
)

# Add middleware
app.add_middleware(ProcessTimeMiddleware)

# Include routers
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(users.router, prefix="/users", tags=["users"])

# Create tables on startup
@app.on_event("startup")
async def startup():
    Base.metadata.create_all(bind=engine)

@app.get("/")
def read_root():
    return {"message": "Welcome to Arcanum API"}

@app.get("/health")
def health_check():
    return {"status": "healthy"}