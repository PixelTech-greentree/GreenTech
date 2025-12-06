"""
Authentication service for user registration and login
"""
import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Optional, Tuple
from sqlalchemy.orm import Session

from models import User


class AuthService:
    
    def __init__(self, db: Session):
        self.db = db
    
    def _hash_password(self, password: str) -> str:
        """Hash password using SHA256"""
        return hashlib.sha256(password.encode()).hexdigest()
    
    def _verify_password(self, password: str, password_hash: str) -> bool:
        """Verify password against hash"""
        return self._hash_password(password) == password_hash
    
    def _generate_token(self, user_id: str) -> str:
        """
        Generate a simple session token
        In production, use JWT with proper expiration
        """
        random_part = secrets.token_urlsafe(32)
        return f"{user_id}:{random_part}"
    
    def _normalize_phone(self, phone_number: str) -> str:
        """Normalize phone number format"""
        # Remove all non-digit characters
        phone = ''.join(filter(str.isdigit, phone_number))
        
        # Ensure it starts with 998 for Uzbekistan
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
        """
        Register a new user
        
        Returns:
            (success, message, user)
        """
        # Normalize phone number
        normalized_phone = self._normalize_phone(phone_number)
        
        # Check if user already exists
        existing_user = self.db.query(User).filter(
            User.phone_number == normalized_phone
        ).first()
        
        if existing_user:
            return False, "Bu telefon raqami allaqachon ro'yxatdan o'tgan", None
        
        # Validate phone number format (must be valid Uzbekistan number)
        if not normalized_phone.startswith("+998") or len(normalized_phone) != 13:
            return False, "Telefon raqami noto'g'ri formatda (+998XXXXXXXXX)", None
        
        # Validate full name
        if len(full_name.strip()) < 2:
            return False, "Ism juda qisqa", None
        
        # Validate password
        if len(password) < 6:
            return False, "Parol kamida 6 ta belgidan iborat bo'lishi kerak", None
        
        # Hash password
        password_hash = self._hash_password(password)
        
        # Create new user
        new_user = User(
            phone_number=normalized_phone,
            full_name=full_name.strip(),
            password_hash=password_hash,
            total_points=0,
            is_active=True,
            is_verified=False,
            created_at=datetime.utcnow(),
            last_login=None
        )
        
        try:
            self.db.add(new_user)
            self.db.commit()
            self.db.refresh(new_user)
            return True, "Ro'yxatdan o'tish muvaffaqiyatli!", new_user
        except Exception as e:
            self.db.rollback()
            return False, f"Xatolik yuz berdi: {str(e)}", None
    
    async def login_user(
        self,
        phone_number: str,
        password: str
    ) -> Tuple[bool, str, Optional[User], Optional[str]]:
        """
        Login user
        
        Returns:
            (success, message, user, token)
        """
        # Normalize phone number
        normalized_phone = self._normalize_phone(phone_number)
        
        # Find user
        user = self.db.query(User).filter(
            User.phone_number == normalized_phone
        ).first()
        
        if not user:
            return False, "Telefon raqami yoki parol noto'g'ri", None, None
        
        # Check if user is active
        if not user.is_active:
            return False, "Hisobingiz bloklangan. Administrator bilan bog'laning", None, None
        
        # Verify password
        if not self._verify_password(password, user.password_hash):
            return False, "Telefon raqami yoki parol noto'g'ri", None, None
        
        # Update last login
        user.last_login = datetime.utcnow()
        self.db.commit()
        
        # Generate token
        token = self._generate_token(user.id)
        
        return True, "Kirish muvaffaqiyatli!", user, token
    
    async def verify_token(self, token: str) -> Optional[User]:
        """
        Verify token and return user
        In production, implement proper JWT verification
        """
        try:
            user_id = token.split(':')[0]
            user = self.db.query(User).filter(User.id == user_id).first()
            
            if user and user.is_active:
                return user
            return None
        except:
            return None
    
    async def get_user_by_id(self, user_id: str) -> Optional[User]:
        """Get user by ID"""
        return self.db.query(User).filter(User.id == user_id).first()
    
    async def update_user_profile(
        self,
        user_id: str,
        full_name: Optional[str] = None,
        avatar_url: Optional[str] = None
    ) -> Tuple[bool, str, Optional[User]]:
        """
        Update user profile
        
        Returns:
            (success, message, user)
        """
        user = await self.get_user_by_id(user_id)
        
        if not user:
            return False, "Foydalanuvchi topilmadi", None
        
        if full_name:
            if len(full_name.strip()) < 2:
                return False, "Ism juda qisqa", None
            user.full_name = full_name.strip()
        
        if avatar_url:
            user.avatar_url = avatar_url
        
        try:
            self.db.commit()
            self.db.refresh(user)
            return True, "Profil yangilandi", user
        except Exception as e:
            self.db.rollback()
            return False, f"Xatolik yuz berdi: {str(e)}", None
