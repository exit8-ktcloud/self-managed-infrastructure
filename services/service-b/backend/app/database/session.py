from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from redis import asyncio as aioredis
from app.core.config import settings

# [수정된 부분] connect_args={"ssl": False} 
# 윈도우 로컬 환경에서 SSL 연결 오류를 방지합니다
engine = create_async_engine(
    settings.DATABASE_URL, 
    echo=False, 
    future=True,
    connect_args={"ssl": False} 
)

AsyncSessionLocal = sessionmaker(
    bind=engine, 
    class_=AsyncSession, 
    expire_on_commit=False, 
    autoflush=False
)

# Redis 연결
redis_client = aioredis.from_url(
    f"redis://{settings.REDIS_HOST}:6379", 
    encoding="utf-8", 
    decode_responses=True
)

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session