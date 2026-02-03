import logging
import sys
from pythonjsonlogger import jsonlogger
from datetime import datetime

#JsonFormatter 오버라이딩
class CustomJsonFormatter(jsonlogger.JsonFormatter):
    def add_fields(self, log_record, record, message_dict):
        # 1. 부모 클래스(super)의 기능은 그대로 실행 (기본 로그 생성)
        super(CustomJsonFormatter, self).add_fields(log_record, record, message_dict)
        
        # 값이 없으면 '-'로 채워서 KeyError 방지
        if not log_record.get('ip'):
            log_record['ip'] = '-'
            
        if not log_record.get('query'):
            log_record['query'] = '-'
            
        # 3. 타임스탬프 포맷 정리
        if not log_record.get('timestamp'):
            log_record['timestamp'] = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%S.%fZ')

def get_logger(name: str):
    logger = logging.getLogger(name)
    
    if not logger.handlers:
        logger.setLevel(logging.INFO)
        handler = logging.StreamHandler(sys.stdout)
        
        # CustomJsonFormatter를 끼워넣음   
        formatter = CustomJsonFormatter(
            '%(timestamp)s %(levelname)s %(message)s %(ip)s %(query)s'
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)
        
    return logger

# 서비스 이름으로 로거 생성
logger = get_logger("service-b")
