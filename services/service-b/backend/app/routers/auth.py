from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.database.session import get_db
from app.core.logger import logger
from app.models import User  # User 모델 가져오기

router = APIRouter()

class LoginRequest(BaseModel):
    username: str
    password: str

# 공통 응답 포맷 함수
def create_response(success_code: int, data: dict = None, error: dict = None):
    return {"success": success_code, "data": data, "error": error}

@router.post("/login")
async def login(
    login_data: LoginRequest, 
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    try:
        stmt = select(User).where(User.username == login_data.username)
        result = await db.execute(stmt)
        user = result.scalars().first()

        # 비밀번호 검증 (현재는 평문 비교, 추후 해싱 적용 권장)
        login_success = False
        if user and user.password == login_data.password:
            login_success = True

        # 로그 기록 (Wazuh 관제용 표준 포맷)
        log_event = "LOGIN_SUCCESS" if login_success else "AUTH_UNAUTHORIZED"
        
        logger.info(log_event, extra={
            "input_user": login_data.username,
            "ip": request.client.host,
            "success": login_success
        })

        if login_success:
            user_dict = {
                "id": user.id,
                "username": user.username,
                "email": user.email,
                "is_admin": user.is_admin
            }
            return create_response(success_code=200, data=user_dict)
        else:
            return JSONResponse(
                status_code=401,
                content=create_response(
                    success_code=401, 
                    error={"code": "AUTH_FAILED", "message": "Invalid credentials"}
                )
            )

    except Exception as e:
        # 서버 에러 로그
        logger.error("SERVER_ERROR", extra={"error": str(e)})
        return JSONResponse(
            status_code=500,
            content=create_response(success_code=500, error={"code": "SERVER_ERROR", "message": "Internal Server Error"})
        )
