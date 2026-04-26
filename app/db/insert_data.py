from app.db.database import SessionLocal, engine
from app.db.models import Base, PersonAccount, Bill, Transaction, AllowedRecipient
import bcrypt
import os

# Clear all data by dropping and recreating tables
print("Dropping all tables...")
Base.metadata.drop_all(engine)
print("Creating all tables...")
Base.metadata.create_all(engine)

session = SessionLocal()

def hash_password(password: str) -> str:
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')

hashed_password = hash_password('password123')

# 1. Create a fresh set of Users
print("Inserting new users...")
users = [
    PersonAccount(reference_number='REF101', full_name='محمد العتوم', phone_number='0791234567', email='mohammad@example.com', password=hashed_password, balance=5000.0, bank_name='البنك العربي'),
    PersonAccount(reference_number='REF102', full_name='زيد الخطيب', phone_number='0788888888', email='zaid@example.com', password=hashed_password, balance=1200.5, bank_name='بنك الإسكان'),
    PersonAccount(reference_number='REF103', full_name='نور الهدى', phone_number='0777777777', email='nour@example.com', password=hashed_password, balance=350.75, bank_name='كابيتال بنك'),
    PersonAccount(reference_number='REF104', full_name='رامي الكيلاني', phone_number='0790000000', email='rami@example.com', password=hashed_password, balance=2750.0, bank_name='بنك الاتحاد'),
    PersonAccount(reference_number='REF105', full_name='دينا المصري', phone_number='0781111111', email='dina@example.com', password=hashed_password, balance=890.0, bank_name='بنك القاهرة عمان'),
    PersonAccount(reference_number='REF106', full_name='حمزة عبيدات', phone_number='0772222222', email='hamza@example.com', password=hashed_password, balance=150.0, bank_name='البنك الإسلامي الأردني'),
    PersonAccount(reference_number='REF107', full_name='سلمى جابر', phone_number='0793333333', email='salma@example.com', password=hashed_password, balance=4200.0, bank_name='صفوة الإسلامي'),
]

session.add_all(users)
session.commit()

# Refresh to get IDs
mohammad = session.query(PersonAccount).filter_by(reference_number='REF101').first()
zaid = session.query(PersonAccount).filter_by(reference_number='REF102').first()
nour = session.query(PersonAccount).filter_by(reference_number='REF103').first()
rami = session.query(PersonAccount).filter_by(reference_number='REF104').first()
dina = session.query(PersonAccount).filter_by(reference_number='REF105').first()
hamza = session.query(PersonAccount).filter_by(reference_number='REF106').first()
salma = session.query(PersonAccount).filter_by(reference_number='REF107').first()

# 2. Add Allowed Recipients (Contacts)
print("Adding contacts...")
# Mohammad's contacts
session.add_all([
    AllowedRecipient(user_pid=mohammad.PID, recipient_pid=zaid.PID, nickname='زيد', bank_name=zaid.bank_name, reference_number=zaid.reference_number, phone_number=zaid.phone_number),
    AllowedRecipient(user_pid=mohammad.PID, recipient_pid=nour.PID, nickname='نور', bank_name=nour.bank_name, reference_number=nour.reference_number, phone_number=nour.phone_number),
    AllowedRecipient(user_pid=mohammad.PID, recipient_pid=salma.PID, nickname='سلمى جابر', bank_name=salma.bank_name, reference_number=salma.reference_number, phone_number=salma.phone_number),
])

# Zaid's contacts
session.add_all([
    AllowedRecipient(user_pid=zaid.PID, recipient_pid=mohammad.PID, nickname='محمد العتوم', bank_name=mohammad.bank_name, reference_number=mohammad.reference_number, phone_number=mohammad.phone_number),
    AllowedRecipient(user_pid=zaid.PID, recipient_pid=rami.PID, nickname='رامي', bank_name=rami.bank_name, reference_number=rami.reference_number, phone_number=rami.phone_number),
])

# Nour's contacts
session.add_all([
    AllowedRecipient(user_pid=nour.PID, recipient_pid=dina.PID, nickname='دينا', bank_name=dina.bank_name, reference_number=dina.reference_number, phone_number=dina.phone_number),
])

# 3. Add Bills
print("Adding bills...")
bills_data = [
    # Mohammad's bills
    Bill(bills_name='الكهرباء', bills_cost=45.30, serves='شركة الكهرباء الوطنية', due_date='2026-04-20', account_PID=mohammad.PID, paid_status='Unpaid'),
    Bill(bills_name='المياه', bills_cost=12.50, serves='مياهنا', due_date='2026-04-25', account_PID=mohammad.PID, paid_status='Unpaid'),
    Bill(bills_name='إنترنت', bills_cost=35.00, serves='زين', due_date='2026-04-01', account_PID=mohammad.PID, paid_status='Paid'),
    
    # Zaid's bills
    Bill(bills_name='الكهرباء', bills_cost=60.00, serves='شركة الكهرباء الوطنية', due_date='2026-04-15', account_PID=zaid.PID, paid_status='Unpaid'),
    Bill(bills_name='هاتف', bills_cost=10.00, serves='أورانج', due_date='2026-04-10', account_PID=zaid.PID, paid_status='Unpaid'),
    
    # Nour's bills
    Bill(bills_name='الجامعة', bills_cost=150.00, serves='جامعة الأردن', due_date='2026-05-01', account_PID=nour.PID, paid_status='Unpaid'),
    
    # Salma's bills
    Bill(bills_name='الغاز', bills_cost=7.00, serves='موزع الغاز', due_date='2026-04-05', account_PID=salma.PID, paid_status='Unpaid'),
]

session.add_all(bills_data)
session.commit()
session.close()

print('--------------------------------------------------')
print('Database successfully reset and repopulated!')
print(f'Total Users: {len(users)}')
print('Main user for testing: محمد العتوم (REF101)')
print('--------------------------------------------------')
