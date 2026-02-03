from sqlalchemy import Column, Integer, String, Boolean
from sqlalchemy.orm import declarative_base

# 데이터베이스 모델의 기본 틀
Base = declarative_base()

# [사용자 테이블 정의]
# 이름: fastapi_users
# 역할: 아이디, 비밀번호 등 사용자 정보를 저장하는 엑셀 시트 같은 존재
class User(Base):
    __tablename__ = "fastapi_users"  

    id = Column(Integer, primary_key=True, index=True)      # 고유 번호
    username = Column(String(50), unique=True, index=True)  # 아이디 (admin 등)
    password = Column(String(100))                          # 비밀번호 (평문 저장
    email = Column(String(100))                             # 이메일
    is_admin = Column(Boolean, default=False)               # 관리자 여부
