import time
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from app.core.logger import logger

class SecurityLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start_time = time.time()
        
        # 요청 처리 (다음 단계로 넘김)
        response = await call_next(request)
        
        # 처리 시간 계산
        process_time = time.time() - start_time
        
        # [모든 접근 기록]
        log_data = {
            "ip": request.client.host,
            "method": request.method,
            "path": request.url.path,
            "status": response.status_code,
            "duration": round(process_time, 4)
        }
        
        # 500 에러(서버 고장)나 400 에러(클라이언트 잘못)도 기록
        if response.status_code >= 500:
            logger.error("SYSTEM_ERROR", extra=log_data)
        elif response.status_code >= 400:
            logger.warning("CLIENT_ERROR", extra=log_data)
            
        return response
