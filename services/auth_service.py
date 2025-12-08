"""
Authentication service
"""
import hashlib
import secrets
from datetime import datetime
from typing import Optional, Tuple
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from models import User


class AuthService:
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    def _hash_password(self, password: str) -> str:
        return hashlib.sha256(password.encode()).hexdigest()
    
    def _verify_password(self, password: str, password_hash: str) -> bool:
        return self._hash_password(password) == password_hash
    
    def generate_token(self, user_id: str) -> str:
        return f"{user_id}:{secrets.token_urlsafe(32)}"
    
    def _normalize_phone(self, phone_number: str) -> str:
        phone = ''.join(filter(str.isdigit, phone_number))
        if phone.startswith('998'):
            return f"+{phone}"
        elif phone.startswith('0'):
            return f"+998{phone[1:]}"
        else:
            return f"+998{phone}"
    
    async def register_user(
        self,
        phone_number: str,
        full_name: str,
        password: str
    ) -> Tuple[bool, str, Optional[User]]:
        normalized = self._normalize_phone(phone_number)
        
        query = select(User).where(User.phone_number == normalized)
        result = await self.db.execute(query)
        existing = result.scalar_one_or_none()
        
        if existing:
            return False, "Bu telefon raqami allaqachon ro'yxatdan o'tgan", None
        
        if len(normalized) != 13 or not normalized.startswith("+998"):
            return False, "Telefon raqami noto'g'ri", None
        
        if len(full_name.strip()) < 2:
            return False, "Ism juda qisqa", None
        
        if len(password) < 6:
            return False, "Parol kamida 6 ta belgi bo'lishi kerak", None
        
        user = User(
            phone_number=normalized,
            full_name=full_name.strip(),
            password_hash=self._hash_password(password),
            total_points=0,
            is_active=True,
            is_verified=False,
            created_at=datetime.utcnow()
        )
        
        try:
            self.db.add(user)
            await self.db.commit()
            await self.db.refresh(user)
            return True, "Ro'yxatdan o'tish muvaffaqiyatli!", user
        except:
            await self.db.rollback()
            return False, "Xatolik yuz berdi", None
    
    async def login_user(
        self,
        phone_number: str,
        password: str
    ) -> Tuple[bool, str, Optional[User], Optional[str]]:
        normalized = self._normalize_phone(phone_number)
        
        query = select(User).where(User.phone_number == normalized)
        result = await self.db.execute(query)
        user = result.scalar_one_or_none()
        
        if not user:
            return False, "Telefon yoki parol noto'g'ri", None, None
        
        if not user.is_active:
            return False, "Hisobingiz bloklangan", None, None
        
        if not self._verify_password(password, user.password_hash):
            return False, "Telefon yoki parol noto'g'ri", None, None
        
        user.last_login = datetime.utcnow()
        await self.db.commit()
        
        token = self.generate_token(user.id)
        return True, "Kirish muvaffaqiyatli!", user, token
    
    async def verify_token(self, token: str) -> Optional[User]:
        try:
            user_id = token.split(':')[0]
            query = select(User).where(User.id == user_id)
            result = await self.db.execute(query)
            user = result.scalar_one_or_none()
            return user if user and user.is_active else None
        except:
            return None
