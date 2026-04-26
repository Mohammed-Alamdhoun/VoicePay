import os
import sys
import joblib
import spacy
import re
from rich import print
from collections import defaultdict

# Relative imports from the new structure
from app.db.database import SessionLocal
from app.db.models import PersonAccount, Bill, Transaction, AllowedRecipient
from app.core.validators import IntentValidator, NERValidator
from app.core.utils import normalize_arabic, find_closest_match, resolve_db_name, resolve_bill_name, extract_numeric_value
from app.core.biometrics.verifier import SpeakerVerifier

# Model paths relative to project root
def find_project_root():
    # Start from the current file's directory
    curr = os.path.abspath(os.path.dirname(__file__))
    # Go up until we find 'models' or 'NER' or reach root
    while curr != os.path.dirname(curr):
        if os.path.exists(os.path.join(curr, "models")) or os.path.exists(os.path.join(curr, "NER")):
            return curr
        curr = os.path.dirname(curr)
    return "/"

PROJECT_ROOT = find_project_root()
INTENT_CLASSIFIER_PATH = os.path.join(PROJECT_ROOT, "models/voicepay_intent_pipeline.pkl")
NER_MODEL_PATH = os.path.join(PROJECT_ROOT, "NER/NERspaCy/output/model-best")

class IntentClassifier:
    def __init__(self, model_path):
        self.pipeline = joblib.load(model_path)
    
    def normalize_arabic(self, text):
        return normalize_arabic(text)
    
    def predict(self, text):
        vectorizer = self.pipeline["vectorizer"]
        model = self.pipeline["model"]
        label_encoder = self.pipeline["label_encoder"]
        normalized_text = self.normalize_arabic(text)
        text_tfidf = vectorizer.transform([normalized_text])
        pred_label = model.predict(text_tfidf)[0]
        pred_proba = model.predict_proba(text_tfidf).max()
        predict_intent = label_encoder.inverse_transform([pred_label])[0]
        return predict_intent, pred_proba

class NERModel:
    def __init__(self, model_path):
        self.nlp = spacy.load(model_path)
    
    def extract_entities(self, text):
        doc = self.nlp(text)
        entities = defaultdict(list)
        for ent in doc.ents:
            entities[ent.label_].append(ent.text)
        result = {}
        for label, values in entities.items():
            if len(values) == 1:
                result[label] = values[0]
            else:
                result[label] = values
        return result

class VoicePayPipeline:
    def __init__(self):
        self.intent_classifier = IntentClassifier(INTENT_CLASSIFIER_PATH)
        self.ner_model = NERModel(NER_MODEL_PATH)
        self.intent_validator = IntentValidator()
        self.ner_validator = NERValidator()
        self.speaker_verifier = SpeakerVerifier()
        self.db = SessionLocal()

    def __del__(self):
        try:
            if hasattr(self, 'db') and self.db is not None:
                self.db.close()
        except:
            pass

    def process(self, text, current_user_pid=1):
        # Refresh the database session to pick up newly added recipients
        self.db.expire_all()
        
        intent, confidence = self.intent_classifier.predict(text)
        intent_validation = self.intent_validator.validate(intent, confidence)
        if intent_validation["status"] != "approved":
            # For unknown or low confidence, we provide a friendly voice response
            intent_validation["status"] = "error" # Keep status consistent for UI
            intent_validation["message"] = "عذراً، لم أفهم طلبك بشكل صحيح. هل يمكنك إعادة المحاولة؟"
            intent_validation["voice_response"] = "عذراً، لم أفهم طلبك بشكل صحيح. هل يمكنك إعادة المحاولة؟"
            return intent_validation
        
        if intent == "check_balance":
            return self.handle_check_balance(current_user_pid)
            
        # Get allowed recipients/bills for validation
        allowed_names = []
        if intent == "p2p_transfer":
            contacts = self.db.query(AllowedRecipient).filter(AllowedRecipient.user_pid == current_user_pid).all()
            allowed_names = [c.nickname for c in contacts]
        elif intent == "pay_bill":
            all_bills = self.db.query(Bill).filter(Bill.account_PID == current_user_pid).all()
            allowed_names = [b.bills_name for b in all_bills]

        entities = self.ner_model.extract_entities(text)
        print(f"DEBUG: Initial NER Entities: {entities}")

        # --- Fallback Extraction ---
        if intent == "p2p_transfer":
            # Fallback for RECIPIENT: Look for 'إلى [اسم]' or 'ل [اسم]' or 'لـ [اسم]'
            # Trigger if missing or if the extracted name is too short (likely just a prefix)
            extracted_recipient = str(entities.get("RECIPIENT", ""))
            if "RECIPIENT" not in entities or len(extracted_recipient.strip()) <= 1:
                # This regex looks for 'إلى' or 'ل' followed by 1 or 2 Arabic words
                # Handles 'إلى مدهون', 'ل مدهون', 'لمدهون'
                match = re.search(r"(?:إلى\s+|لـ?\s*|ل\s*)([ء-ي]{3,}(?:\s+[ء-ي]+)?)", text)
                if match:
                    entities["RECIPIENT"] = match.group(1).strip()
                    print(f"DEBUG: Fallback RECIPIENT found: {entities['RECIPIENT']}")
            
            # Fallback for AMOUNT: Look for words like 'ألف', 'مئة', or digits followed by 'دينار'
            if "AMOUNT" not in entities:
                amount_match = re.search(r"(\d+|ألف|الف|مئة|مائه|خمسين|عشرين|عشرة|عشره|خمسة|خمسه|دينارين)\s*(?:دينار|دنانير|ليره|ليرات)?", text)
                if amount_match:
                    entities["AMOUNT"] = amount_match.group(0).strip()
                    print(f"DEBUG: Fallback AMOUNT found: {entities['AMOUNT']}")

        ner_validation = self.ner_validator.validate(intent, entities, allowed_names=allowed_names)
        print(f"DEBUG: NER Validation Status: {ner_validation['status']}")
        
        if ner_validation["status"] != "approved":
            ner_validation["status"] = "error"
            
            # Specific messages based on why it failed
            reason = ner_validation.get("reason")
            print(f"DEBUG: Validation Failed Reason: {reason}")
            
            if reason == "duplicate_entities":
                msg = "عذراً، لقد ذكرت أكثر من مستلم أو مبلغ واحد. يرجى ذكر تفاصيل عملية واحدة فقط."
            else:
                missing = ner_validation.get("details", [])
                print(f"DEBUG: Missing Entities: {missing}")
                if "RECIPIENT" in missing and "AMOUNT" in missing:
                    msg = "عذراً، لم أفهم المبلغ والمستلم. هل يمكنك إعادة المحاولة وتحديدهما؟"
                elif "RECIPIENT" in missing:
                    msg = "عذراً، لم أفهم لمن تريد التحويل. يرجى ذكر اسم المستلم."
                elif "AMOUNT" in missing:
                    msg = "عذراً، لم أفهم المبلغ المطلوب. يرجى ذكر المبلغ بوضوح."
                elif "BILL_TYPE" in missing:
                    msg = "عذراً، لم أفهم نوع الفاتورة التي تريد دفعها."
                else:
                    msg = "عذراً، لم أفهم بعض التفاصيل. هل يمكنك إعادة المحاولة؟"
                
            ner_validation["message"] = msg
            ner_validation["voice_response"] = msg
            return ner_validation
            
        entities = ner_validation.get("entities", entities)
        print(f"DEBUG: Final Entities for process: {entities}")
        
        # New Interactive Flow: Prepare instead of execute immediately
        return self.prepare_action(intent, entities, current_user_pid)

    def prepare_action(self, intent, entities, current_user_pid):
        if intent == "p2p_transfer":
            return self.handle_p2p_transfer_prepare(entities, current_user_pid)
        elif intent == "pay_bill":
            return self.handle_pay_bill_prepare(entities, current_user_pid)
        else:
            return {"status": "error", "reason": "unhandled_intent", "intent": intent}

    def commit_action(self, action_type, data, current_user_pid):
        """Actually executes the transaction after voice confirmation"""
        if action_type == "p2p_transfer":
            return self.handle_p2p_transfer_execute(data, current_user_pid)
        elif action_type == "pay_bill":
            return self.handle_pay_bill_execute(data, current_user_pid)
        return {"status": "error", "reason": "invalid_action_type"}

    def handle_check_balance(self, user_pid):
        user = self.db.query(PersonAccount).filter(PersonAccount.PID == user_pid).first()
        if not user:
            return {"status": "error", "reason": "user_not_found"}
        return {
            "status": "success",
            "message": f"أهلاً {user.full_name}، رصيدك الحالي هو {user.balance:.2f} دينار أردني.",
            "data": {"user": user.full_name, "balance": user.balance}
        }

    def handle_p2p_transfer_prepare(self, entities, sender_pid):
        amount_str = entities.get("AMOUNT")
        recipient_query = entities.get("RECIPIENT")
        if isinstance(recipient_query, list):
            recipient_query = " ".join(recipient_query)
        
        # Clean 'ل' prefix if it exists (e.g., 'لرامي' -> 'رامي')
        if recipient_query and recipient_query.startswith("ل") and len(recipient_query) > 2:
            recipient_query = recipient_query[1:].strip()
        
        amount = extract_numeric_value(amount_str)
        if amount <= 0:
            return {"status": "error", "reason": "invalid_amount", "details": f"Could not parse amount: {amount_str}"}
            
        sender = self.db.query(PersonAccount).filter(PersonAccount.PID == sender_pid).first()
        if not sender:
            return {"status": "error", "reason": "sender_not_found"}
        if sender.balance < amount:
            return {
                "status": "error", 
                "reason": "insufficient_balance", 
                "message": f"عذراً، رصيدك الحالي هو {sender.balance:.2f} دينار وهو غير كافٍ لإتمام هذه العملية بقيمة {amount:.2f} دينار.",
                "details": f"Insufficient balance ({sender.balance:.2f})."
            }

        contacts = self.db.query(AllowedRecipient).filter(AllowedRecipient.user_pid == sender_pid).all()
        
        # Match ONLY against nicknames provided in the contacts list
        nicknames = [c.nickname for c in contacts]
        nickname_to_contact = {c.nickname: c for c in contacts}
        
        print(f"DEBUG: Query: |{recipient_query}|")
        print(f"DEBUG: Saved Nicknames: {nicknames}")
        
        best_nickname = resolve_db_name(recipient_query, nicknames)
        print(f"DEBUG: Best Match: |{best_nickname}|")
        
        if not best_nickname:
            return {
                "status": "error", 
                "reason": "recipient_not_in_allowed_list", 
                "message": f"عذراً، الاسم '{recipient_query}' ليس ضمن قائمة الأسماء المحفوظة لديك.",
                "voice_response": f"عذراً، الاسم '{recipient_query}' ليس ضمن قائمة الأسماء المحفوظة لديك.",
                "details": recipient_query
            }

        contact = nickname_to_contact[best_nickname]
        if not contact.recipient_pid:
            return {"status": "error", "reason": "recipient_account_not_found", "message": f"عذراً، لا يوجد حساب نشط للمستلم '{contact.nickname}'."}

        recipient = self.db.query(PersonAccount).filter(PersonAccount.PID == contact.recipient_pid).first()
        if not recipient:
            return {"status": "error", "reason": "recipient_account_defunct", "message": "عذراً، حساب المستلم غير موجود حالياً."}

        if recipient.PID == sender_pid:
            return {"status": "error", "reason": "cannot_transfer_to_self", "message": "عذراً، لا يمكنك التحويل لنفسك."}

        return {
            "status": "needs_confirmation",
            "action_type": "p2p_transfer",
            "prompt": f"هل تريد تأكيد تحويل مبلغ {amount:.2f} دينار إلى {contact.nickname}؟",
            "data": {
                "recipient_pid": recipient.PID,
                "amount": amount,
                "nickname": contact.nickname
            }
        }

    def handle_p2p_transfer_execute(self, data, sender_pid):
        amount = data["amount"]
        recipient_pid = data["recipient_pid"]
        nickname = data["nickname"]

        sender = self.db.query(PersonAccount).filter(PersonAccount.PID == sender_pid).first()
        recipient = self.db.query(PersonAccount).filter(PersonAccount.PID == recipient_pid).first()

        if not sender or not recipient:
            return {"status": "error", "reason": "accounts_mismatch"}
        if sender.balance < amount:
            return {"status": "error", "reason": "insufficient_balance"}

        new_txn = Transaction(
            sender_PID=sender_pid,
            recipient_PID=recipient.PID,
            amount=amount,
            reference_number=f"TXN_VP_{os.urandom(4).hex().upper()}"
        )
        try:
            sender.balance -= amount
            recipient.balance += amount
            self.db.add(new_txn)
            self.db.commit()
            return {
                "status": "success",
                "message": f"تم التحويل بنجاح. تم إرسال {amount:.2f} دينار إلى {nickname}. رصيدك الجديد هو {sender.balance:.2f} دينار.",
                "transaction_id": new_txn.transaction_id,
                "new_balance": sender.balance
            }
        except Exception as e:
            self.db.rollback()
            return {"status": "error", "reason": "database_error", "details": str(e)}

    def handle_pay_bill_prepare(self, entities, user_pid):
        bill_type = entities.get("BILL_TYPE")
        user = self.db.query(PersonAccount).filter(PersonAccount.PID == user_pid).first()
        if not user:
            return {"status": "error", "reason": "user_not_found"}
        
        all_bills = self.db.query(Bill).filter(Bill.account_PID == user_pid).all()
        if not all_bills:
            return {"status": "error", "reason": "no_bills_found"}
            
        unpaid_bills = [b for b in all_bills if b.paid_status == "Unpaid"]
        unpaid_names = [b.bills_name for b in unpaid_bills]
        best_unpaid_match = resolve_bill_name(bill_type, unpaid_names)
        
        if best_unpaid_match:
            bill = next(b for b in unpaid_bills if b.bills_name == best_unpaid_match)
            if user.balance < bill.bills_cost:
                return {
                    "status": "error", 
                    "reason": "insufficient_balance", 
                    "message": f"عذراً، لا يمكنك دفع فاتورة {bill.bills_name} لأن رصيدك {user.balance:.2f} دينار أقل من قيمة الفاتورة {bill.bills_cost:.2f} دينار.",
                    "details": f"Bill cost {bill.bills_cost:.2f} exceeds balance {user.balance:.2f}."
                }
            
            return {
                "status": "needs_confirmation",
                "action_type": "pay_bill",
                "prompt": f"هل تريد تأكيد دفع فاتورة {bill.bills_name} بقيمة {bill.bills_cost:.2f} دينار؟",
                "data": {
                    "bill_id": bill.bill_id,
                    "bill_name": bill.bills_name,
                    "cost": bill.bills_cost
                }
            }

        paid_bills = [b for b in all_bills if b.paid_status == "Paid"]
        paid_names = [b.bills_name for b in paid_bills]
        best_paid_match = resolve_bill_name(bill_type, paid_names)
        if best_paid_match:
            bill = next(b for b in paid_bills if b.bills_name == best_paid_match)
            return {"status": "error", "reason": "bill_already_paid", "message": f"لقد تم دفع فاتورة {bill.bills_name} مسبقاً."}
        return {"status": "error", "reason": "bill_not_found", "message": f"عذراً، لم أجد فاتورة باسم {bill_type}.", "details": bill_type}

    def handle_pay_bill_execute(self, data, user_pid):
        bill_id = data["bill_id"]
        user = self.db.query(PersonAccount).filter(PersonAccount.PID == user_pid).first()
        bill = self.db.query(Bill).filter(Bill.bill_id == bill_id).first()

        if not user or not bill:
            return {"status": "error", "reason": "data_mismatch"}
        if user.balance < bill.bills_cost:
            return {"status": "error", "reason": "insufficient_balance"}

        try:
            bill.paid_status = "Paid"
            user.balance -= bill.bills_cost
            self.db.commit()
            return {
                "status": "success",
                "message": f"تم دفع فاتورة {bill.bills_name} بنجاح. رصيدك الجديد هو {user.balance:.2f} دينار.",
                "bill_id": bill.bill_id,
                "new_balance": user.balance
            }
        except Exception as e:
            self.db.rollback()
            return {"status": "error", "reason": "database_error", "details": str(e)}
