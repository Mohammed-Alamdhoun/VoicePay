#!/bin/bash

# Set the PYTHONPATH to the backend directory to resolve app.db, app.core, app.api imports
export PYTHONPATH=$PYTHONPATH:$(pwd)/backend

# Run the FastAPI server using the module path
echo "Starting VoicePay Backend API..."
python3 -m app.api.main
