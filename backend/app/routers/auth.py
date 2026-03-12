from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db
from app.schemas.auth import LoginRequest, LoginResponse, TokenRefreshRequest, TokenRefreshResponse
from app.services.auth_service import authenticate_user, refresh_user_token

router = APIRouter(prefix="/api/auth", tags=["Authentication"])


@router.post("/login", response_model=LoginResponse)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    """Authenticate cashier and return JWT tokens."""
    result = authenticate_user(db, request.username, request.password)
    return result


@router.post("/refresh", response_model=TokenRefreshResponse)
def refresh_token(request: TokenRefreshRequest, db: Session = Depends(get_db)):
    """Refresh access token using a valid refresh token."""
    result = refresh_user_token(db, request.refresh_token)
    return result


@router.post("/logout")
def logout():
    """Logout — client should discard tokens."""
    return {"message": "Logged out successfully"}
