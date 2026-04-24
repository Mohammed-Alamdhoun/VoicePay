import random

DIGITS_AR = {
    "0": "صفر",
    "1": "واحد",
    "2": "اثنان",
    "3": "ثلاثة",
    "4": "أربعة",
    "5": "خمسة",
    "6": "ستة",
    "7": "سبعة",
    "8": "ثمانية",
    "9": "تسعة",
}

def generate_challenge():
    """Generates a random 6-digit numeric challenge code in Arabic."""
    # Use SystemRandom for better randomness
    cryptogen = random.SystemRandom()
    code = "".join(str(cryptogen.randint(0, 9)) for _ in range(6))
    spoken = " ".join(DIGITS_AR[d] for d in code)
    return {
        "code": code,
        "text": f"يرجى قول الأرقام التالية: {code}\n({spoken})",
        "spoken": spoken
    }
