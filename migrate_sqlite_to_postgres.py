import os
from uuid import uuid4

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from dotenv import load_dotenv

# Loyihadagi modellardan import qilamiz
from models import User, Tree, Task, CheckIn, TaskCompletionLog, Base

load_dotenv()

# Eski SQLite baza (greentree.db)
SQLITE_URL = "sqlite:///./greentree.db"

# Yangi Postgres baza (greendb) - .env dan olamiz
POSTGRES_URL = os.getenv("DATABASE_URL")

if not POSTGRES_URL:
    raise RuntimeError("DATABASE_URL topilmadi. .env ni tekshiring")

print("SQLite URL:", SQLITE_URL)
print("Postgres URL:", POSTGRES_URL)

# Engine va sessionlar
sqlite_engine = create_engine(
    SQLITE_URL,
    connect_args={"check_same_thread": False},
)

pg_engine = create_engine(POSTGRES_URL)

SQLiteSession = sessionmaker(bind=sqlite_engine)
PGSession = sessionmaker(bind=pg_engine)


def migrate_table(sqlite_session, pg_session, model):
    """
    Bitta jadvaldagi ma'lumotlarni SQLite dan Postgresga ko'chirish
    """
    rows = sqlite_session.query(model).all()
    print(f"{model.__name__}: {len(rows)} ta yozuv topildi")

    for row in rows:
        # Yangi session uchun detached obyekt yaratamiz
        data = {}
        for col in row.__table__.columns:
            data[col.name] = getattr(row, col.name)

        new_obj = model(**data)
        pg_session.merge(new_obj)  # ID bo'yicha mavjud bo'lsa - update, bo'lmasa - insert

    pg_session.commit()
    print(f"{model.__name__}: ko'chirish yakunlandi\n")


def main():
    sqlite_session = SQLiteSession()
    pg_session = PGSession()

    try:
        # 1) Avval Postgresda jadval strukturalari borligiga ishonch hosil qilamiz
        print("Postgresda jadvallarni yaratish (agar bo'lmasa)...")
        Base.metadata.create_all(bind=pg_engine)

        # 2) Migratsiya tartibi: foreign keylarga qarab
        migrate_table(sqlite_session, pg_session, User)
        migrate_table(sqlite_session, pg_session, Tree)
        migrate_table(sqlite_session, pg_session, Task)
        migrate_table(sqlite_session, pg_session, CheckIn)
        migrate_table(sqlite_session, pg_session, TaskCompletionLog)

        print("✅ Barcha ma'lumotlar ko'chirildi!")
    finally:
        sqlite_session.close()
        pg_session.close()


if __name__ == "__main__":
    main()
