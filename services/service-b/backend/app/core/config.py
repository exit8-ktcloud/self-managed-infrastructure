import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Service B"
    
    # [DB 접속 정보]
    
    POSTGRES_USER: str = os.getenv("POSTGRES_USER", "admin")
    POSTGRES_PASSWORD: str = os.getenv("POSTGRES_PASSWORD", "changeme")
    POSTGRES_SERVER: str = os.getenv("POSTGRES_SERVER", "postgres") 
    POSTGRES_DB: str = os.getenv("POSTGRES_DB", "appdb")

    # [Redis 접속 정보]
    REDIS_HOST: str = os.getenv("REDIS_HOST", "redis")

    # DB 접속 주소 완성하기
    @property
    def DATABASE_URL(self) -> str:
        return f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_SERVER}:5432/{self.POSTGRES_DB}"

settings = Settings()
