from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session
import bcrypt

# Relative imports
from app.db.database import SessionLocal
from app.db.models import PersonAccount, AllowedRecipient, Bill

router = APIRouter(tags=["User Management"])

# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- Pydantic Models ---
class LoginRequest(BaseModel):
    email: str
    password: str

class AddRecipientRequest(BaseModel):
    user_pid: int
    nickname: str
    bank_name: str
    reference_number: str
    phone_number: str

class UpdateRecipientRequest(BaseModel):
    id: int # The AllowedRecipient.id
    nickname: str
    bank_name: str
    reference_number: str
    phone_number: str

class RemoveRecipientRequest(BaseModel):
    user_pid: int
    recipient_pid: int # We'll use the ID of the record

# --- Management Endpoints ---

@router.get("/user/{user_pid}")
async def get_user_details(user_pid: int, db: Session = Depends(get_db)):
    user = db.query(PersonAccount).filter(PersonAccount.PID == user_pid).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return {
        "pid": user.PID,
        "full_name": user.full_name,
        "email": user.email,
        "balance": user.balance
    }

@router.post("/login")
async def api_login(request: LoginRequest, db: Session = Depends(get_db)):
    try:
        user = db.query(PersonAccount).filter(PersonAccount.email == request.email).first()
        if not user:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
        
        # Verify password using direct bcrypt call (passlib is broken with bcrypt 5.0.0)
        password_bytes = request.password.encode('utf-8')
        hash_bytes = user.password.encode('utf-8')
        if not bcrypt.checkpw(password_bytes, hash_bytes):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid email or password")
        
        return {
            "status": "success",
            "user": {
                "pid": user.PID,
                "full_name": user.full_name,
                "email": user.email,
                "balance": user.balance
            }
        }
    except Exception as e:
        import traceback
        traceback.print_exc()
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/recipients/{user_pid}")
async def get_recipients(user_pid: int, db: Session = Depends(get_db)):
    user = db.query(PersonAccount).filter(PersonAccount.PID == user_pid).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return [
        {
            "id": r.id,
            "pid": r.recipient_pid,
            "nickname": r.nickname,
            "bank_name": r.bank_name,
            "reference_number": r.reference_number,
            "phone_number": r.phone_number
        } 
        for r in user.allowed_contacts
    ]

@router.get("/bills/{user_pid}")
async def get_bills(user_pid: int, db: Session = Depends(get_db)):
    user = db.query(PersonAccount).filter(PersonAccount.PID == user_pid).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return [
        {
            "id": b.bill_id,
            "name": b.bills_name,
            "cost": b.bills_cost,
            "serves": b.serves,
            "due_date": b.due_date,
            "status": b.paid_status
        }
        for b in user.bills
    ]

@router.post("/recipients/add")
async def add_recipient(request: AddRecipientRequest, db: Session = Depends(get_db)):
    # 1. Check if recipient exists in the main system by reference number
    recipient = db.query(PersonAccount).filter(PersonAccount.reference_number == request.reference_number).first()
    
    if not recipient:
        return {
            "status": "error", 
            "message": "عذراً، لا يوجد مستخدم مسجل بهذا الرقم المرجعي. يرجى التأكد من الرقم والمحاولة مرة أخرى."
        }
    
    # 2. Check if already in the allowed list for this user
    existing = db.query(AllowedRecipient).filter(
        AllowedRecipient.user_pid == request.user_pid,
        AllowedRecipient.reference_number == request.reference_number
    ).first()
    
    if existing:
        return {
            "status": "error",
            "message": "هذا المستلم موجود بالفعل في قائمة جهات الاتصال الخاصة بك."
        }

    new_contact = AllowedRecipient(
        user_pid=request.user_pid,
        recipient_pid=recipient.PID,
        nickname=request.nickname,
        bank_name=request.bank_name,
        reference_number=request.reference_number,
        phone_number=request.phone_number
    )
    
    db.add(new_contact)
    db.commit()
    return {"status": "success", "message": f"تمت إضافة المستلم '{request.nickname}' بنجاح!"}

@router.post("/recipients/update")
async def update_recipient(request: UpdateRecipientRequest, db: Session = Depends(get_db)):
    contact = db.query(AllowedRecipient).filter(AllowedRecipient.id == request.id).first()
    if not contact:
        raise HTTPException(status_code=404, detail="Recipient not found")
    
    contact.nickname = request.nickname
    contact.bank_name = request.bank_name
    contact.reference_number = request.reference_number
    contact.phone_number = request.phone_number
    
    db.commit()
    return {"status": "success", "message": f"Recipient '{request.nickname}' updated successfully!"}

@router.post("/recipients/remove")
async def remove_recipient(request: RemoveRecipientRequest, db: Session = Depends(get_db)):
    contact = db.query(AllowedRecipient).filter(
        AllowedRecipient.user_pid == request.user_pid,
        AllowedRecipient.recipient_pid == request.recipient_pid
    ).first()
    
    if not contact:
        # Try finding by ID if pid lookup fails
        contact = db.query(AllowedRecipient).filter(AllowedRecipient.id == request.recipient_pid).first()

    if not contact:
        raise HTTPException(status_code=404, detail="Recipient record not found")
        
    db.delete(contact)
    db.commit()
    return {"status": "success", "message": "Recipient removed successfully!"}
