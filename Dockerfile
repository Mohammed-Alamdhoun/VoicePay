# Use Python 3.10 for compatibility with ML libraries
FROM python:3.10-slim

# Create a non-root user for Hugging Face (UID 1000)
RUN useradd -m -u 1000 user
WORKDIR /app

# Install system dependencies for audio processing
RUN apt-get update && apt-get install -y \
    ffmpeg \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy and install requirements first for better caching
COPY --chown=user:user backend/requirements.txt .
RUN pip install --no-cache-dir --upgrade -r requirements.txt

# Install SpaCy model
RUN python -m spacy download en_core_web_sm

# Copy the application code and models
# We copy them into the structure expected by your imports
COPY --chown=user:user backend/app /app/app
COPY --chown=user:user models /app/models
COPY --chown=user:user NER /app/NER

# Set permissions for the database (SQLite needs write access to the folder)
RUN chmod -R 777 /app/app/db

# Environment variables
ENV PYTHONPATH=/app
ENV HOME=/home/user
ENV PATH=/home/user/.local/bin:$PATH

USER user

# Hugging Face expects port 7860
EXPOSE 7860

# Start the application
CMD ["uvicorn", "app.api.main:app", "--host", "0.0.0.0", "--port", "7860"]
