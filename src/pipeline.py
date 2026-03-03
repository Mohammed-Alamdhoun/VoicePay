import whisper
import joblib
import spacy
import re
from rich import print
from collections import defaultdict

# model = whisper.load_model("turbo", device="cpu")
# result = model.transcribe("../test.wav")
# text = result["text"]
# print(text)

# models paths
INITENT_CLASSIFIER_PATH = "../models/voicepay_intent_pipeline.pkl"
NER_MODEL_PATH = "../NER/NERspaCy/output/model-best"

class IntentClassifier:
    def __init__(self, model_path):
        self.pipeline = joblib.load(model_path)
    
    # Text Normalization
    def normalize_arabic(self,text):
        """
        Normalize Arabic text by:
        - Unifying similar letters
        - Removing special characters
        - Removing extra spaces
        """
        text = text.replace("إ", "ا").replace("أ", "ا").replace("آ", "ا")
        text = text.replace("ى", "ي").replace("ة", "ه")

        # Keep only Arabic letters, numbers, and spaces
        text = re.sub(r"[^ء-ي0-9\s]", "", text)

        # Remove extra spaces
        text = re.sub(r"\s+", " ", text).strip()

        return text
    
    def predict(self, text):
        """  preprocess the input text, vectorize it, and predict the intent using the trained model. """
        vectorizer = self.pipeline["vectorizer"]
        model = self.pipeline["model"]
        label_encoder = self.pipeline["label_encoder"]
        
        text = self.normalize_arabic(text)
        text_tfidf = vectorizer.transform([text])
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

        return dict(entities)
    
