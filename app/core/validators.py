class NERValidator:
    """
    Validate extracted entities from NER.
    Responsibilities:
    - Check for required entities per intent
    - Detect duplicate entities
    - Check for empty entity values
    - Return structured validation result
    """

    def __init__(self):
        # Define required entities per intent
        self.intent_entity_requirements = {
            "p2p_transfer": ["RECIPIENT", "AMOUNT"], # Made CURRENCY optional if it can be inferred
            "pay_bill": ["BILL_TYPE"]
        }

    # ---------- Helpers ----------
    @staticmethod
    def _check_implicit_currency(amount_text):
        """Check if currency is mentioned within the amount text itself"""
        currency_keywords = ["دينار", "دنانير", "ليره", "ليرات", "قرش", "قروش", "JOD"]
        return any(kw in str(amount_text) for kw in currency_keywords)
    @staticmethod
    def _is_empty(value):
        """Check if an entity value is empty"""
        if value is None:
            return True
        if not isinstance(value, list):
            value = [value]
        return all(not str(v).strip() for v in value)

    @staticmethod
    def _detect_duplicates(entities):
        """Detect duplicated entity values"""
        duplicated = {}
        for key, value in entities.items():
            if isinstance(value, list) and len(value) > 1:
                duplicated[key] = value
        return duplicated

    @staticmethod
    def _check_empty_values(entities):
        """Detect entities that exist but have empty values"""
        empty_entities = [key for key, val in entities.items() if NERValidator._is_empty(val)]
        return empty_entities

    @staticmethod
    def _check_missing_entities(intent, entities, intent_entity_requirements):
        """Check for required entities missing in input"""
        required_entities = intent_entity_requirements.get(intent, [])
        missing = [ent for ent in required_entities if ent not in entities]
        return missing

    # ---------- Main Validation ----------
    def validate(self, intent, entities, allowed_names=None):
        """
        Run full validation on entities for a given intent.
        Returns a structured dict with status, reason, and details.
        """

        # Case 1: No entities extracted
        if not entities:
            return {
                "status": "clarification_required",
                "reason": "no_entities_detected"
            }

        # Pre-process multi-word entities (RECIPIENT, BILL_TYPE)
        # We join these BEFORE duplicate detection ONLY IF they don't map to separate allowed people.
        processed_entities = {}
        for key, val in entities.items():
            if key in ["RECIPIENT", "BILL_TYPE"] and isinstance(val, list) and len(val) > 1:
                # Option 2 Implementation: 
                if allowed_names:
                    # Check if the whole string matches something perfectly
                    joined_name = " ".join([str(v) for v in val])
                    
                    # We need a way to check if individual parts match DIFFERENT people
                    # If "Omar" matches Person A and "Yousef" matches Person B, don't join.
                    # This is best handled by checking if individual tokens have high-confidence matches.
                    matches = set()
                    from app.core.utils import resolve_db_name, resolve_bill_name
                    
                    for token in val:
                        m = None
                        if key == "RECIPIENT":
                            m = resolve_db_name(token, allowed_names)
                        else:
                            m = resolve_bill_name(token, allowed_names)
                        if m:
                            matches.add(m)
                    
                    if len(matches) > 1:
                        # Multiple DIFFERENT people found! Keep as list to trigger duplicate check.
                        processed_entities[key] = val
                    else:
                        # Either 0 or 1 match found for the parts, safe to join.
                        processed_entities[key] = joined_name
                else:
                    # No allowed_names provided, fallback to default joining.
                    processed_entities[key] = " ".join([str(v) for v in val])
            else:
                processed_entities[key] = val

        # Case 2: Duplicate entities (Check this AFTER joining name parts, but BEFORE joining amounts)
        # This will flag [5, 50] for AMOUNT as a duplicate, but treat ["Omar", "Nasser"] as one RECIPIENT
        duplicated = self._detect_duplicates(processed_entities)
        if duplicated:
            return {
                "status": "clarification_required",
                "reason": "duplicate_entities",
                "details": duplicated
            }

        # Final pass: join any remaining lists (like multiple CURRENCY or AMOUNT tokens that weren't duplicates)
        for key, val in processed_entities.items():
            if isinstance(val, list):
                processed_entities[key] = " ".join([str(v) for v in val])

        # --- Entity Recovery ---
        # If AMOUNT is missing but CURRENCY exists (e.g. "دينار"), use CURRENCY as AMOUNT
        if intent == "p2p_transfer":
            if "AMOUNT" not in processed_entities and "CURRENCY" in processed_entities:
                processed_entities["AMOUNT"] = processed_entities["CURRENCY"]

        entities = processed_entities

        # Case 3: Missing required entities
        missing_entities = self._check_missing_entities(intent, entities, self.intent_entity_requirements)
        if missing_entities:
            return {
                "status": "clarification_required",
                "reason": "missing_entities",
                "details": missing_entities
            }

        # Case 4: Empty entity values
        empty_entities = self._check_empty_values(entities)
        if empty_entities:
            return {
                "status": "clarification_required",
                "reason": "empty_entity_values",
                "details": empty_entities
            }

        # Approved
        final_entities = entities

        # Post-validation: Ensure CURRENCY exists for transfers, either explicitly or implicitly
        if intent == "p2p_transfer":
            has_explicit = "CURRENCY" in final_entities
            has_implicit = self._check_implicit_currency(final_entities.get("AMOUNT", ""))
            
            if not has_explicit and not has_implicit:
                # If neither, we could either fail OR default to JOD
                # For this project, let's default to JOD but notify
                final_entities["CURRENCY"] = "JOD (default)"
            elif has_implicit and not has_explicit:
                 final_entities["CURRENCY"] = "Inferred from amount"

        return {
            "status": "approved",
            "entities": final_entities
        }

class IntentValidator:
    """
    Class to validate predicted intents with their confidence scores.
    """

    def __init__(self, min_confidence=0.75, unknown_threshold=0.6):
        # List of intents that the system recognizes
        self.allowed_intents = [
            "check_balance",
            "p2p_transfer",
            "pay_bill",
            "unknown"
        ]
        self.min_confidence = min_confidence      # Minimum confidence to auto-approve
        self.unknown_threshold = unknown_threshold  # Confidence below this is "very low"

    def _check_confidence(self, confidence):
        if confidence < self.unknown_threshold:
            return "very_low"
        elif confidence < self.min_confidence:
            return "low"
        else:
            return "high"

    def validate(self, intent, confidence):
        if confidence is None:
            return {"status": "rejected", "reason": "invalid_confidence"}

        if intent == "unknown" or intent not in self.allowed_intents:
            return {"status": "clarification_required", "reason": "intent_unknown"}

        conf_status = self._check_confidence(confidence)
        if conf_status == "very_low":
            return {"status": "clarification_required", "reason": "very_low_confidence"}
        elif conf_status == "low":
            return {
                "status": "confirmation_required",
                "reason": "low_confidence",
                "predicted_intent": intent
            }
        else:
            return {"status": "approved", "intent": intent, "confidence": confidence}
