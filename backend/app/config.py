from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # Database
    DATABASE_URL: str = "postgresql://postgres:postgres@localhost:5432/nalan_db"

    # JWT
    JWT_SECRET_KEY: str = "nalan-hotel-secret-key-change-in-production-2024"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 480  # 8 hours
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Hotel Config
    HOTEL_NAME: str = "Nalan Hotel"
    HOTEL_UPI_ID: str = "nalanhotel@okicici"
    HOTEL_ADDRESS: str = "123 Main Road, Chennai"
    HOTEL_PHONE: str = "+91-XXXXXXXXXX"
    HOTEL_GSTIN: str = ""
    CURRENCY_SYMBOL: str = "₹"
    BILL_PREFIX: str = "NLN"

    # UPI Config
    UPI_POLL_INTERVAL: int = 5
    UPI_POLL_TIMEOUT: int = 300
    MAX_DISCOUNT_PCT: int = 20

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    return Settings()
