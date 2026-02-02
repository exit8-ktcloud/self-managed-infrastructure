import logging
import sys
from pythonjsonlogger import jsonlogger

# [로거 설정]
def get_logger(name: str):
    logger = logging.getLogger(name)
    
    if not logger.handlers:
        logger.setLevel(logging.INFO)
        handler = logging.StreamHandler(sys.stdout)
        
        # 로그 포맷: 시간, 레벨, 메시지 등을 JSON으로 출력
        formatter = jsonlogger.JsonFormatter(
            '%(asctime)s %(levelname)s %(message)s %(ip)s %(query)s'
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        
    return logger

# 서비스 이름으로 로거 생성
logger = get_logger("service-b")