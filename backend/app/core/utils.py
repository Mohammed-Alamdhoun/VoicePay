import re
import difflib
from pyarabic.number import text2number

def normalize_arabic(text):
    """
    Normalize Arabic text by:
    - Unifying similar letters (Alef, Yeh, Heh)
    - Removing special characters (Tashkeel, etc.)
    - Removing extra spaces
    """
    if not text:
        return ""
    
    # Normalize Alefs
    text = re.sub("[إأآ]", "ا", text)
    # Normalize Yeh/Alef Maqsura
    text = re.sub("[ىي]", "ي", text) 
    # Standardize Heh and Teh Marbuta
    text = text.replace("ة", "ه")
    
    # Remove Tashkeel (diacritics)
    tashkeel = re.compile(r'[\u064B-\u0652]')
    text = re.sub(tashkeel, "", text)

    # Keep only Arabic letters, numbers, and spaces
    text = re.sub(r"[^ء-ي0-9\s]", "", text)

    # Remove extra spaces
    text = re.sub(r"\s+", " ", text).strip()

    return text

def extract_numeric_value(text):
    """
    Extract a numeric value from Arabic text.
    Handles:
    - Digits (e.g., '50')
    - Formal Arabic text numbers (e.g., 'خمسة وعشرون')
    - Dialectal variations (e.g., 'خمسه', 'دينارين')
    - Mixed formats (e.g., '60 ونص')
    """
    if not text:
        return 0.0

    # 1. Normalize for common dialectal variations
    norm_text = normalize_arabic(text)
    
    # Custom mapping for terms pyarabic might miss or handle inconsistently
    custom_mapping = {
        "دينارين": 2.0,
        "ليرتين": 2.0,
        "دينار": 1.0,
        "ليره": 1.0,
        "نصف": 0.5,
        "نص": 0.5,
        "ربع": 0.25,
        "مائتين": 200.0,
        "مئتين": 200.0,
        "مائتان": 200.0,
        "مئتان": 200.0,
        "الفين": 2000.0,
        "الفان": 2000.0,
        "مليون": 1000000.0,
    }
    
    if norm_text in custom_mapping:
        return custom_mapping[norm_text]

    # Handle mixed currency units
    if "قرش" in norm_text or "قروش" in norm_text:
        main_part = re.split(r"(دينار|دنانير|ليره|ليرات)", norm_text)[0]
        if main_part.strip():
             return extract_numeric_value(main_part)

    # 2. Pre-process: Remove currency words first to avoid separating numbers from fractions
    # This turns '60 دينار ونصف' into '60 ونصف'
    parsing_text = re.sub(r"(دينار|دنانير|ليره|ليرات|قرش|قروش)", "", norm_text).strip()

    # 3. Extract fraction from the cleaned text
    fraction_val = 0.0
    if "ونصف" in parsing_text or "ونص" in parsing_text:
        fraction_val = 0.5
        parsing_text = parsing_text.replace("ونصف", "").replace("ونص", "").strip()
    elif "وربع" in parsing_text:
        fraction_val = 0.25
        parsing_text = parsing_text.replace("وربع", "").strip()

    # 4. Check for digits in the remaining part (e.g., '60')
    digit_match = re.search(r"(\d+\.?\d*)", str(parsing_text))
    if digit_match:
        return float(digit_match.group(1)) + fraction_val

    # 5. Handle text numbers (e.g., 'خمسين')
    parsing_text = parsing_text.replace("مائة", "مئة").replace("مائه", "مئة")
    parsing_text = parsing_text.replace("مائتين", "مئتين").replace("مائتان", "مئتان")
    
    # Formalize text for pyarabic
    formal_text = parsing_text.replace("ه", "ة").replace("ى", "ي").replace("الف", "ألف").replace("الاف", "ألف").replace("ملايين", "مليون")
    # Also ensure initial Alif has a hamza for numbers starting with it (أربعين, أحد, etc.)
    if formal_text.startswith("ا"):
        formal_text = "أ" + formal_text[1:]
    
    print(f"DEBUG: Parsing Text: |{parsing_text}|")
    print(f"DEBUG: Formal Text: |{formal_text}|")
    
    try:
        # Split by 'و' logic for compound numbers
        if " و" in formal_text:
            parts = formal_text.split(" و")
            total = 0.0
            for part in parts:
                clean_part = part.strip()
                formal_part = clean_part.replace("ه", "ة").replace("ا", "أ")
                p_val = text2number(formal_part)
                if p_val == 0:
                    formal_part_simple = clean_part.replace("ه", "ة")
                    p_val = text2number(formal_part_simple)
                if p_val == 0:
                    if clean_part in custom_mapping:
                        p_val = custom_mapping[clean_part]
                total += float(p_val)
            if total > 0:
                return total + fraction_val

        val = text2number(formal_text)
        if val > 0:
            return float(val) + fraction_val
        elif "مليون" in formal_text and val == 0:
             return 1000000.0 + fraction_val
    except:
        pass

    if fraction_val > 0 and not parsing_text:
        return fraction_val

    return 0.0

def find_closest_match(query, candidates, threshold=0.6):
    """
    Find the closest match for a query in a list of candidates using difflib.
    Returns the best match if its score is above threshold, else None.
    """
    if not candidates:
        return None
    
    # Normalize query
    norm_query = normalize_arabic(query)
    
    # Map normalized candidates back to original
    norm_to_orig = {normalize_arabic(c): c for c in candidates}
    norm_candidates = list(norm_to_orig.keys())
    
    matches = difflib.get_close_matches(norm_query, norm_candidates, n=1, cutoff=threshold)
    
    if matches:
        return norm_to_orig[matches[0]]
    
    return None

# Mapping for bill types to handle common variations
BILLS_MAPPING = {
    "الكهرباء": "الكهرباء",
    "الكهربا": "الكهرباء",
    "المياه": "المياه",
    "المي": "المياه",
    "انترنت": "إنترنت",
    "نت": "إنترنت",
    "الغاز": "الغاز",
    "غاز": "الغاز",
    "موبايل": "موبايل",
    "هاتف": "موبايل",
    "تلفون": "موبايل",
}

def resolve_db_name(query, candidates, recursive_call=False):
    """
    Resolve a query name (Arabic) to a database candidate (Arabic).
    """
    if not query:
        return None

    # 1. Try exact match after normalization
    norm_query = normalize_arabic(query)
    for cand in candidates:
        if normalize_arabic(cand) == norm_query:
            return cand

    # 2. Try fuzzy matching on candidates
    match = find_closest_match(query, candidates)
    if match:
        return match

    # 3. Handle common prefixes (e.g., 'لـ' for recipient) if not already done
    if not recursive_call:
        # Check if query starts with 'ل' (to/for)
        if query.startswith("ل") and len(query) > 3:
            return resolve_db_name(query[1:], candidates, recursive_call=True)
            
    return None

def resolve_bill_name(query, candidates, recursive_call=False):
    """
    Specially designed matcher for bill names.
    """
    if not query:
        return None

    # Normalize query (remove "فاتورة", "فاتوره" if present)
    query = query.replace("فاتورة", "").replace("فاتوره", "").strip()
    norm_query = normalize_arabic(query)

    # 1. Try direct mapping from BILLS_MAPPING
    for variation, official_name in BILLS_MAPPING.items():
        if normalize_arabic(variation) == norm_query:
            # Match the official name against available bills in DB
            for cand in candidates:
                if normalize_arabic(cand) == normalize_arabic(official_name):
                    return cand

    # 2. Try fuzzy matching on candidates
    match = find_closest_match(query, candidates)
    if match:
        return match

    # 3. Handle common prefixes if not already done
    if not recursive_call:
        if query.startswith(("ل", "ب", "ف")) and len(query) > 3:
            return resolve_bill_name(query[1:], candidates, recursive_call=True)

    return None
