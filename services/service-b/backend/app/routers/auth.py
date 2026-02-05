from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import text
from app.database.session import get_db
from app.core.logger import logger


router = APIRouter()

class LoginRequest(BaseModel):
    username: str
    password: str

def create_response(success_code: int, data: dict = None, error: dict = None):
    return {"success": success_code, "data": data, "error": error}

@router.post("/login")
async def login(
    login_data: LoginRequest, 
    request: Request,
    db: AsyncSession = Depends(get_db)
):
    try:
        # 취약점 발생 지점
        # 입력값을 검증 없이 f-string으로 쿼리에 바로 꽂아버림 (SQL Injection)
        
        query = text(f"SELECT id, username, email, is_admin FROM fastapi_users WHERE username = '{login_data.username}' AND password = '{login_data.password}'")
        
        result = await db.execute(query)
        user = result.mappings().first() # 검색된 행이 있으면 로그인 성공

        # 로그인 성공/실패 여부 결정
        login_success = True if user else False

        # 로그 기록 (Wazuh 관제용)
        log_event = "LOGIN_SUCCESS" if login_success else "AUTH_UNAUTHORIZED"
        
        logger.info(log_event, extra={
            "input_user": login_data.username,
            "ip": request.client.host,
            "success": login_success
        })

        if login_success:
            return create_response(success_code=200, data={
                "id": user.id,
                "username": user.username,
                "email": user.email,
                "is_admin": user.is_admin
            })
        else:
            return JSONResponse(
                status_code=401,
                content=create_response(
                    success_code=401, 
                    error={"code": "AUTH_FAILED", "message": "Invalid credentials"}
                )
            )

    except Exception as e:
        # SQL 인젝션 공격 시 문법 에러가 나면 여기가 찍힘
        logger.error("LOGIN_ERROR", extra={"error": str(e), "input_user": login_data.username})
        return JSONResponse(
            status_code=500,
            content=create_response(success_code=500, error={"code": "SERVER_ERROR", "message": "Internal Server Error"})
        )
