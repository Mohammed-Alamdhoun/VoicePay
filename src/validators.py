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
            "p2p_transfer": ["RECIPIENT", "AMOUNT", "CURRENCY"],
            "pay_bill": ["BILL_TYPE"]
        }

    # ---------- Helpers ----------
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
    def validate(self, intent, entities):
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

        # Case 2: Missing required entities
        missing_entities = self._check_missing_entities(intent, entities, self.intent_entity_requirements)
        if missing_entities:
            return {
                "status": "clarification_required",
                "reason": "missing_entities",
                "details": missing_entities
            }

        # Case 3: Empty entity values
        empty_entities = self._check_empty_values(entities)
        if empty_entities:
            return {
                "status": "clarification_required",
                "reason": "empty_entity_values",
                "details": empty_entities
            }

        # Case 4: Duplicate entities
        duplicated = self._detect_duplicates(entities)
        if duplicated:
            return {
                "status": "clarification_required",
                "reason": "duplicate_entities",
                "details": duplicated
            }

        # Approved
        return {
            "status": "approved",
            "entities": entities
        }

class IntentValidator:
    """
    Class to validate predicted intents with their confidence scores.
    
    Responsibilities:
    - Check if the predicted intent is allowed
    - Handle unknown intents
    - Handle low-confidence predictions
    - Return structured results for downstream handling

    Parameters:
    - min_confidence: threshold for requiring user confirmation
    - unknown_threshold: threshold below which the intent is considered very unclear
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
        """
        Helper method to categorize confidence levels.

        Returns:
        - "very_low" if confidence < unknown_threshold
        - "low" if confidence < min_confidence
        - "high" otherwise
        """
        if confidence < self.unknown_threshold:
            return "very_low"
        elif confidence < self.min_confidence:
            return "low"
        else:
            return "high"

    def validate(self, intent, confidence):
        """
        Validate the predicted intent and confidence.

        Cases handled:
        1. Confidence is None -> invalid input
        2. Intent is 'unknown' or not in allowed intents -> clarification required
        3. Confidence very low -> clarification required
        4. Confidence low but above unknown threshold -> confirmation required
        5. Confidence high -> approved

        Returns:
        - A dictionary with status, reason, and additional info when needed
        """

        # Case 1: Invalid confidence value
        if confidence is None:
            result = {"status": "rejected", "reason": "invalid_confidence"}

        # Case 2: Unknown or unrecognized intent
        elif intent == "unknown" or intent not in self.allowed_intents:
            result = {"status": "clarification_required", "reason": "intent_unknown"}

        else:
            conf_status = self._check_confidence(confidence)

            # Case 3: Very low confidence
            if conf_status == "very_low":
                result = {"status": "clarification_required", "reason": "very_low_confidence"}

            # Case 4: Low confidence but not extremely low
            elif conf_status == "low":
                result = {
                    "status": "confirmation_required",
                    "reason": "low_confidence",
                    "predicted_intent": intent
                }

            # Case 5: High confidence
            else:
                result = {"status": "approved", "intent": intent, "confidence": confidence}

        return result