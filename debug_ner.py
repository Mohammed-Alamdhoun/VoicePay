import os
import sys

# Add backend to sys.path
sys.path.append(os.path.join(os.getcwd(), "backend"))

from app.core.pipeline import VoicePayPipeline
import spacy

# Mocking some environment variables or paths if needed
# The pipeline handles paths relative to project root usually.

pipeline = VoicePayPipeline()

text = "حول لزيد الخطيب 50 دينار"
user_pid = 16 # VP-737650

print(f"Input text: {text}")

# 1. Test NER directly
entities = pipeline.ner_model.extract_entities(text)
print(f"Extracted entities: {entities}")

# 2. Test full process
result = pipeline.process(text, current_user_pid=user_pid)
print(f"Pipeline result: {result}")
