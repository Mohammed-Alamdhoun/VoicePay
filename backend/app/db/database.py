import os
import sys
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Relative import from the new structure
from app.db.models import Base

# Path to the database file in the same directory
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATABASE_URL = f"sqlite:///{os.path.join(BASE_DIR, 'voicepay.db')}"

engine = create_engine(DATABASE_URL, echo=False)
SessionLocal = sessionmaker(bind=engine)


def create_database():
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    print("Database created successfully!")


if __name__ == "__main__":
    create_database()
