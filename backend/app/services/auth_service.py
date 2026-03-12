from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.user import User
from app.utils.security import verify_password, create_access_token, create_refresh_token, decode_token

# Simple in-memory login attempt tracking
_login_attempts: dict[str, dict] = {}


def authenticate_user(db: Session, username: str, password: str) -> dict:
    """Authenticate user and return tokens."""
    import time

    # Check lockout
    attempts = _login_attempts.get(username, {"count": 0, "locked_until": 0})
    if attempts["locked_until"] > time.time():
        remaining = int(attempts["locked_until"] - time.time())
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Account locked. Try again in {remaining} seconds.",
        )

    user = db.query(User).filter(User.username == username).first()
    if not user or not verify_password(password, user.password_hash):
        # Track failed attempt
        attempts["count"] = attempts.get("count", 0) + 1
        if attempts["count"] >= 5:
            attempts["locked_until"] = time.time() + 120  # 2-minute lockout
            attempts["count"] = 0
        _login_attempts[username] = attempts
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    # Reset attempts on success
    _login_attempts.pop(username, None)

    access_token = create_access_token(data={"sub": str(user.id)})
    refresh_token = create_refresh_token(data={"sub": str(user.id)})

    return {
        "token": access_token,
        "refresh_token": refresh_token,
        "cashier_name": user.full_name or user.username,
        "user_id": user.id,
    }


def refresh_user_token(db: Session, refresh_token: str) -> dict:
    """Generate new access token from a valid refresh token."""
    payload = decode_token(refresh_token)
    if payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type",
        )

    user_id = payload.get("sub")
    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
        )

    new_access_token = create_access_token(data={"sub": str(user.id)})
    return {"token": new_access_token}
