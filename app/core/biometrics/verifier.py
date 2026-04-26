import os
import json
import numpy as np
from resemblyzer import VoiceEncoder, preprocess_wav
from sklearn.metrics.pairwise import cosine_similarity
from pydub import AudioSegment
import io

class SpeakerVerifier:
    def __init__(self, voiceprints_path=None):
        self.voiceprints_path = voiceprints_path
        self.encoder = VoiceEncoder()
        self.db_cache = {}
        if voiceprints_path:
            self.db_cache = self._load_json_db()

    def _load_json_db(self):
        if not self.voiceprints_path or not os.path.exists(self.voiceprints_path):
            return {}
        with open(self.voiceprints_path, "r", encoding="utf-8") as f:
            return json.load(f)

    def load_user(self, user_id, db_voiceprint=None):
        if db_voiceprint:
            voiceprint = np.array(json.loads(db_voiceprint), dtype=np.float32)
            return voiceprint, 0.6
        user_id_str = str(user_id)
        if user_id_str not in self.db_cache:
            raise ValueError(f"User '{user_id}' not enrolled for voice verification.")
        item = self.db_cache[user_id_str]
        voiceprint = np.array(item if isinstance(item, list) else item["voiceprint"], dtype=np.float32)
        threshold = float(item.get("threshold", 0.6)) if isinstance(item, dict) else 0.6
        return voiceprint, threshold

    def _load_audio(self, audio_bytes):
        """
        Robustly load audio using pydub and FFmpeg.
        Converts to 16kHz mono float32 array.
        """
        # Try to load as any format FFmpeg understands (WebM, Opus, M4A, etc.)
        audio = AudioSegment.from_file(io.BytesIO(audio_bytes))
        
        # Convert to 16000Hz, Mono
        audio = audio.set_frame_rate(16000).set_channels(1)
        
        # Get raw samples as numpy array
        samples = np.array(audio.get_array_of_samples())
        
        # Convert to float32 normalized to [-1, 1]
        if audio.sample_width == 2:
            samples = samples.astype(np.float32) / 32768.0
        elif audio.sample_width == 4:
            samples = samples.astype(np.float32) / 2147483648.0
            
        return samples

    def basic_liveness_gate(self, wav, min_seconds=0.8, energy_threshold=1e-5):
        """
        Check if the audio is long enough and has enough energy.
        Being slightly more lenient with Web recordings.
        """
        duration = len(wav) / 16000.0
        rms = float(np.sqrt(np.mean(wav**2)) + 1e-12)

        if duration < min_seconds:
            return False, f"Audio too short ({duration:.2f}s). Please speak clearly for at least {min_seconds}s."
        if rms < energy_threshold:
            return False, f"Audio too quiet (rms={rms:.6f}). Please speak louder."
        return True, "OK"

    def verify(self, user_id, audio_bytes, db_voiceprint=None):
        try:
            wav_norm = self._load_audio(audio_bytes)
            liveness_ok, msg = self.basic_liveness_gate(wav_norm)
            if not liveness_ok:
                return {"status": "error", "reason": "liveness_failed", "message": msg}

            voiceprint, threshold = self.load_user(user_id, db_voiceprint=db_voiceprint)
            wav = preprocess_wav(wav_norm)
            probe_embedding = self.encoder.embed_utterance(wav)

            similarity = float(cosine_similarity([voiceprint], [probe_embedding])[0][0])
            is_match = similarity >= threshold
            
            return {
                "status": "success" if is_match else "failed",
                "similarity": similarity,
                "threshold": threshold,
                "verified": is_match,
                "message": "تم التحقق من بصمة الصوت بنجاح." if is_match else "عذراً، بصمة الصوت غير متطابقة. يرجى المحاولة مرة أخرى بصوت أوضح."
            }
        except Exception as e:
            import traceback
            traceback.print_exc()
            return {"status": "error", "reason": "verification_error", "message": str(e)}

    def enroll(self, audio_samples_bytes):
        embs = []
        try:
            for audio_bytes in audio_samples_bytes:
                wav_norm = self._load_audio(audio_bytes)
                liveness_ok, msg = self.basic_liveness_gate(wav_norm)
                if not liveness_ok:
                    return {"status": "error", "message": f"Sample check failed: {msg}"}
                
                wav = preprocess_wav(wav_norm)
                emb = self.encoder.embed_utterance(wav)
                embs.append(emb)

            if len(embs) < 6:
                return {"status": "error", "message": f"Required 6 valid samples, but only got {len(embs)}."}

            voiceprint = np.mean(embs, axis=0)
            return {"status": "success", "voiceprint": voiceprint.tolist()}
        except Exception as e:
            import traceback
            traceback.print_exc()
            return {"status": "error", "message": str(e)}
