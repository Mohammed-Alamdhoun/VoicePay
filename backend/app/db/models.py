from sqlalchemy import (Column, Integer, String, Float, ForeignKey, DateTime, CheckConstraint, Table)
from sqlalchemy.orm import declarative_base, relationship
from sqlalchemy.sql import func

Base = declarative_base()

class AllowedRecipient(Base):
    __tablename__ = 'allowed_recipients'
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_pid = Column(Integer, ForeignKey('person_account.PID'), nullable=False)
    recipient_pid = Column(Integer, ForeignKey('person_account.PID'), nullable=True)
    nickname = Column(String, nullable=False)
    bank_name = Column(String, nullable=True)
    reference_number = Column(String, nullable=True)
    phone_number = Column(String, nullable=True)
    owner = relationship('PersonAccount', foreign_keys=[user_pid], back_populates='allowed_contacts')
    actual_account = relationship('PersonAccount', foreign_keys=[recipient_pid])

class PersonAccount(Base):
    __tablename__ = 'person_account'
    PID = Column(Integer, primary_key=True, autoincrement=True)
    reference_number = Column(String, unique=True, nullable=False)
    full_name = Column(String, nullable=False)
    phone_number = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=True)
    password = Column(String, nullable=True)
    balance = Column(Float, default=0.0)
    bank_name = Column(String, nullable=True) # New field for user's bank
    bills = relationship('Bill', back_populates='owner', cascade='all, delete')
    sent_transactions = relationship('Transaction', foreign_keys='Transaction.sender_PID', back_populates='sender', cascade='all, delete')
    received_transactions = relationship('Transaction', foreign_keys='Transaction.recipient_PID', back_populates='recipient', cascade='all, delete')
    allowed_contacts = relationship('AllowedRecipient', foreign_keys=[AllowedRecipient.user_pid], back_populates='owner')

class Bill(Base):
    __tablename__ = 'bills'
    bill_id = Column(Integer, primary_key=True, autoincrement=True)
    bills_name = Column(String, nullable=False)
    bills_cost = Column(Float, nullable=False)
    serves = Column(String, nullable=False)
    due_date = Column(String, nullable=False)
    paid_status = Column(String, default='Unpaid')
    account_PID = Column(Integer, ForeignKey('person_account.PID'), nullable=False)
    __table_args__ = (CheckConstraint('paid_status IN ("Paid","Unpaid")', name='check_paid_status'),)
    owner = relationship('PersonAccount', back_populates='bills')

class Transaction(Base):
    __tablename__ = 'transactions'
    transaction_id = Column(Integer, primary_key=True, autoincrement=True)
    sender_PID = Column(Integer, ForeignKey('person_account.PID'), nullable=False)
    recipient_PID = Column(Integer, ForeignKey('person_account.PID'), nullable=False)
    amount = Column(Float, nullable=False)
    date_time = Column(DateTime, server_default=func.now())
    reference_number = Column(String, unique=True, nullable=False)
    sender = relationship('PersonAccount', foreign_keys=[sender_PID], back_populates='sent_transactions')
    recipient = relationship('PersonAccount', foreign_keys=[recipient_PID], back_populates='received_transactions')
