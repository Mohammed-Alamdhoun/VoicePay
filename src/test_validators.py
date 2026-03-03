from validators import IntentValidator, NERValidator

# --------------------------
# Test Script for Validators
# --------------------------

def test_intent_validator():
    print("=== Testing IntentValidator ===")
    iv = IntentValidator(min_confidence=0.75, unknown_threshold=0.6)

    test_cases = [
        ("p2p_transfer", 0.8),    # High confidence, should approve
        ("pay_bill", 0.7),        # Low confidence, should ask for confirmation
        ("check_balance", 0.5),   # Very low confidence, should ask clarification
        ("unknown", 0.9),         # Explicit unknown intent
        ("invalid_intent", 0.9),  # Not allowed intent
        ("p2p_transfer", None),   # None confidence
    ]

    for intent, conf in test_cases:
        result = iv.validate(intent, conf)
        print(f"Intent: {intent}, Confidence: {conf} -> {result}")


def test_ner_validator():
    print("\n=== Testing NERValidator ===")
    nv = NERValidator()

    test_cases = [
        ("p2p_transfer", {"RECIPIENT": "Ali", "AMOUNT": 100, "CURRENCY": "USD"}),  # Valid
        ("p2p_transfer", {"RECIPIENT": "Ali", "AMOUNT": 100}),                     # Missing CURRENCY
        ("p2p_transfer", {"RECIPIENT": "", "AMOUNT": 100, "CURRENCY": "USD"}),    # Empty RECIPIENT
        ("pay_bill", {"BILL_TYPE": ["electricity", "water"]}),                     # Duplicate BILL_TYPE
        ("p2p_transfer", {}),                                                     # No entities
    ]

    for intent, entities in test_cases:
        result = nv.validate(intent, entities)
        print(f"Intent: {intent}, Entities: {entities} -> {result}")


if __name__ == "__main__":
    test_intent_validator()
    test_ner_validator()