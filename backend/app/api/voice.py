from fastapi import APIRouter, HTTPException, Request, File, UploadFile
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import edge_tts
import io

router = APIRouter(tags=["Voice Operations"])

# --- Pydantic Models ---
class ProcessRequest(BaseModel):
    text: str
    user_pid: int

class ConfirmRequest(BaseModel):
    action_type: str
    data: dict
    user_pid: int

class TTSRequest(BaseModel):
    text: str

# --- Voice Endpoints ---

@router.get("/text-to-speech")
async def text_to_speech_get(text: str):
    """Converts text to Arabic speech using Edge TTS (GET)"""
    return await generate_speech(text)

@router.post("/text-to-speech")
async def text_to_speech_post(request: TTSRequest):
    """Converts text to Arabic speech using Edge TTS (POST)"""
    return await generate_speech(request.text)

async def generate_speech(text: str):
    try:
        # Using a natural Arabic voice (Jordanian/General) - Taim
        voice = "ar-JO-TaimNeural"
        communicate = edge_tts.Communicate(text, voice)
        
        # Stream the audio directly to memory
        audio_stream = io.BytesIO()
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio_stream.write(chunk["data"])
        
        audio_stream.seek(0)
        return StreamingResponse(audio_stream, media_type="audio/mpeg")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/process")
async def api_process_text(request_body: ProcessRequest, request: Request):
    """
    Handles initial command. 
    If it's a transaction, it returns 'needs_confirmation' + Arabic prompt.
    """
    try:
        pipeline = request.app.state.pipeline
        result = pipeline.process(request_body.text, current_user_pid=request_body.user_pid)
        
        # Add a field for the TTS message to play
        if "prompt" in result:
            result["voice_response"] = result["prompt"]
        elif "message" in result:
            result["voice_response"] = result["message"]
            
        return result
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/confirm")
async def api_confirm_action(request_body: ConfirmRequest, request: Request):
    """Executes the pending transaction after user says 'Yes'"""
    try:
        pipeline = request.app.state.pipeline
        result = pipeline.commit_action(
            action_type=request_body.action_type,
            data=request_body.data,
            current_user_pid=request_body.user_pid
        )
        
        # Add a field for the TTS message to play
        if "message" in result:
            result["voice_response"] = result["message"]
            
        return result
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/voice-to-text")
async def voice_to_text(request: Request, file: UploadFile = File(...)):
    try:
        # Get audio bytes directly from upload
        audio_data = await file.read()
        
        # Transcribe using Deepgram SDK v6 keyword-only signature
        client = request.app.state.stt_client
        
        response = client.listen.v1.media.transcribe_file(
            request=audio_data,
            model="nova-3",
            smart_format=True,
            language="ar-JO"
        )
        text = response.results.channels[0].alternatives[0].transcript.strip()
            
        return {"status": "success", "text": text}
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
