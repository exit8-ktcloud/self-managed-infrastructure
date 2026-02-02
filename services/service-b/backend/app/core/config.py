import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Service B"
    
    # [DB 접속 정보]
    # 수정 포인트: 기본값을 127.0.0.1로 명확하게 지정
    POSTGRES_USER: str = os.getenv("POSTGRES_USER", "exit8")
    POSTGRES_PASSWORD: str = os.getenv("POSTGRES_PASSWORD", "exit8pass")
    POSTGRES_SERVER: str = os.getenv("POSTGRES_SERVER", "127.0.0.1") 
    POSTGRES_DB: str = os.getenv("POSTGRES_DB", "EXIT8")

    # [Redis 접속 정보]
    # 수정 포인트: 기본값을 127.0.0.1로 명확하게 지정
    REDIS_HOST: str = os.getenv("REDIS_HOST", "127.0.0.1")

    # DB 접속 주소 완성하기
    @property
    def DATABASE_URL(self) -> str:
        return f"postgresql+asyncpg://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_SERVER}:5432/{self.POSTGRES_DB}"

settings = Settings()