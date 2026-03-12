from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.bootstrap import ensure_database_ready
from app.database import active_database_url
from app.routers import auth, menu, bills, payments, webhooks, reports, upi_accounts


@asynccontextmanager
async def lifespan(_: FastAPI):
    ensure_database_ready()
    yield

app = FastAPI(
    title="Nalan Hotel POS API",
    description="Cashier Billing System for Nalan Hotel — Phase 1",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS — allow all origins for development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routers
app.include_router(auth.router)
app.include_router(menu.router)
app.include_router(bills.router)
app.include_router(payments.router)
app.include_router(webhooks.router)
app.include_router(reports.router)
app.include_router(upi_accounts.router)


@app.get("/")
def root():
    return {
        "app": "Nalan Hotel POS API",
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs",
        "database": active_database_url,
    }


@app.get("/health")
def health_check():
    return {"status": "healthy", "database": active_database_url}
