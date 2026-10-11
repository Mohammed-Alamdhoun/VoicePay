# VoicePay: Arabic Voice Banking Assistant

VoicePay lets people use their bank by speaking Arabic. A user can check their balance, send money to a saved contact, or pay a bill with one spoken sentence. They log in with their password plus their voice.

Entered in the 5th edition of the Crown Prince Award for Best Government Service Application (Jordan).

<!-- Screenshots: add 2–3 app screenshots here, for example:
<p align="center">
  <img src="docs/login.png" width="230">
  <img src="docs/dashboard.png" width="230">
</p>
-->

## What it does

- **Voice commands in Arabic.** "كم رصيدي؟", "حوّل 50 دينار لأحمد" or "ادفع فاتورة الكهرباء" is understood, checked and carried out.
- **Voice login as a second factor.** After the password, the user reads a random 6-digit code aloud. The backend checks the spoken digits and the speaker's voiceprint, so an old recording can't be replayed.
- **Confirmation before money moves.** Every transfer or bill payment is read back to the user, and it runs only after they confirm.
- **Spoken replies** in a Jordanian Arabic voice.
- **Built-in checks.** Transfers only go to the user's saved contacts, and the balance is checked before every action.

## How it works

```mermaid
flowchart LR
    A["Voice command"] --> B["1. Speech-to-text<br/>Deepgram nova-2"]
    B --> C["2. Intent<br/>TF-IDF + Logistic Regression"]
    C --> D["3. Entities<br/>custom spaCy NER"]
    D --> E["4. Validation<br/>contacts, bills, balance"]
    E --> F["5. Confirm and reply<br/>edge-tts"]
```

| Stage | What happens | Built with |
|---|---|---|
| 1. Speech-to-text | Arabic audio from the app becomes text | Deepgram `nova-2` (`language=ar`) |
| 2. Intent | Classifies the request as `check_balance`, `p2p_transfer`, `pay_bill` or `unknown` | TF-IDF + Logistic Regression (scikit-learn) |
| 3. Entities | Extracts `RECIPIENT`, `AMOUNT`, `CURRENCY` and `BILL_TYPE`, with regex fallbacks for missed names and amounts | Custom Arabic spaCy NER |
| 4. Validation | Checks that required entities exist, matches names to saved contacts and bills (Arabic normalization + fuzzy matching), and checks the balance | PyArabic, difflib, SQLAlchemy |
| 5. Confirm and reply | Reads the action back, runs it after the user confirms, and speaks the result | edge-tts (`ar-JO-TaimNeural`) |

### Voice login

1. **Enrollment:** the user records 6 voice samples. Resemblyzer turns them into a voiceprint (speaker embedding) that is saved with the account.
2. **Login:** after the password check (bcrypt), the app shows a random 6-digit code. The user says it in Arabic.
3. **Verification:** speech-to-text checks the digits (5 of 6 must match, to allow for noise), and the cosine similarity between the new voice and the saved voiceprint must pass a threshold (0.6 by default). A basic liveness check rejects silent or very short audio.

## Models and results

| Model | Training data | Result |
|---|---|---|
| Intent classifier (TF-IDF + Logistic Regression) | Arabic banking commands, augmented with back-translation (Arabic → English → Arabic) and Gemini paraphrases | ~0.99 macro F1 in cross-validation (on augmented data) |
| NER (spaCy `tok2vec` + `ner`) | Entities labeled with Gemini, then converted to BIO tags | 0.89 F1 overall: `AMOUNT`, `CURRENCY` and `RECIPIENT` 1.00, `BILL_TYPE` 0.66 |

`BILL_TYPE` is the weakest entity, so the pipeline fuzzy-matches it against the user's real bills before acting. The training notebooks are in [`research/`](research/).

## Tech stack

- **Backend:** Python 3.10, FastAPI, SQLAlchemy + SQLite, spaCy, scikit-learn, Resemblyzer, librosa, pydub, Deepgram SDK, edge-tts, PyArabic, bcrypt
- **Mobile:** Flutter (http, record, audioplayers, speech_to_text, provider, shared_preferences)
- **Deployment:** Docker on Hugging Face Spaces; a GitHub Actions workflow builds an unsigned iOS app

## Project structure

```
VoicePay/
├── backend/
│   ├── app/
│   │   ├── api/         # FastAPI routes: voice commands and account management
│   │   ├── core/        # NLP pipeline, validators, Arabic utilities, voice biometrics
│   │   └── db/          # SQLAlchemy models and SQLite database
│   └── requirements.txt
├── models/              # Intent classifier (.pkl, stored with Git LFS)
├── NER/NERspaCy/        # Trained spaCy NER model and training data
├── data/ner/            # NER datasets (entity extraction, BIO tagging)
├── research/            # Notebooks: data augmentation, intent training, NER training
├── mobile/              # Flutter app
├── Dockerfile           # Backend image for Hugging Face Spaces
└── run_backend.sh       # Runs the API locally
```

## API

All routes start with `/api/v1`. When the server is running, interactive docs are at `/docs`.

| Method | Route | Purpose |
|---|---|---|
| POST | `/register` | Create an account |
| GET | `/enrollment-challenges` | Get 6 phrases to record for voice enrollment |
| POST | `/enroll-voice` | Upload the 6 samples and save the voiceprint |
| POST | `/login` | Check email and password, then return a voice challenge |
| POST | `/verify-login-challenge` | Check the spoken code and the speaker's voice |
| POST | `/voice-to-text` | Transcribe Arabic audio |
| POST | `/process` | Turn a command into an action that needs confirmation |
| POST | `/confirm` | Run the confirmed action |
| GET, POST | `/text-to-speech` | Speak a reply in Arabic |
| GET | `/recipients/{user_pid}`, `/bills/{user_pid}` | List saved contacts and bills |
| POST | `/recipients/add`, `/recipients/update`, `/recipients/remove` | Manage saved contacts |
| POST | `/send-reset-code`, `/verify-reset-code` | Reset a password by email |

## Getting started

You need Python 3.10, [Git LFS](https://git-lfs.com) (the models are stored with it), ffmpeg, and a [Deepgram](https://deepgram.com) API key. For the app, you need Flutter.

**1. Install**

```bash
git lfs install
git clone https://github.com/Mohammed-Alamdhoun/VoicePay.git
cd VoicePay
python -m venv .venv && source .venv/bin/activate
pip install -r backend/requirements.txt
```

**2. Add your keys** in a `.env` file in the project root:

```env
DEEPGRAM_API_KEY=your_deepgram_key

# Only needed for password-reset emails
MAIL_USERNAME=you@gmail.com
MAIL_PASSWORD=your_app_password
MAIL_SERVER=smtp.gmail.com
MAIL_PORT=587
```

**3. Run the backend**

```bash
bash run_backend.sh        # http://localhost:5000, docs at http://localhost:5000/docs
```

Or with Docker:

```bash
docker build -t voicepay-backend .
docker run -p 7860:7860 --env-file .env voicepay-backend
```

**4. Run the mobile app**

```bash
cd mobile
flutter pub get
flutter run
```

The app calls the hosted backend by default. To use your local server, change `baseUrl` in `mobile/lib/services/api_service.dart` (on the Android emulator, use `http://10.0.2.2:5000/api/v1`).

## Team

- [Mohammed Al-Madhoun](https://github.com/Mohammed-Alamdhoun)
- Layan Khaddash
- [Shatha Al-Ghrair](https://github.com/ShathaAlghrair)
