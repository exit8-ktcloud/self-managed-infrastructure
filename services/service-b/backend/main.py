from fastapi import FastAPI
from prometheus_fastapi_instrumentator import Instrumentator
from sqlalchemy import select

from app.core.config import settings
from app.core.middleware import SecurityLoggingMiddleware
from app.core.logger import logger
from app.routers import auth
from app.database.session import engine, AsyncSessionLocal
from app.models import Base, User

app = FastAPI(title=settings.PROJECT_NAME)

app.add_middleware(SecurityLoggingMiddleware)
Instrumentator().instrument(app).expose(app, endpoint="/actuator/prometheus")

app.include_router(auth.router, prefix="/api/v1/auth", tags=["Authentication"])

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "service-b"}

# 서버 시작 시 실행
@app.on_event("startup")
async def startup_event():
    # 테이블 자동 생성
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    # 관리자 계정(Target) 자동 생성
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.username == "admin"))
        if not result.scalars().first():
            new_admin = User(
                username="admin", 
                password="super_secret_password_123", # 평문 비밀번호
                email="admin@exit8.corp", 
                is_admin=True
            )
            db.add(new_admin)
            await db.commit()
            logger.info("SERVER_STARTED", extra={"msg": "Admin user initialized"})
        
    logger.info("SERVER_STARTED", extra={"service": "service-b"})
