#  AURA — Autism Understanding and Rehabilitation Assistant

AURA is a comprehensive therapy tracking and management application designed for children with Autism Spectrum Disorder (ASD). It bridges the gap between **therapists** and **parents** by providing real-time session tracking, AI-powered assessments, interactive therapy games, and automated progress reports.

---

##  Table of Contents

- [Features](#-features)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Prerequisites](#-prerequisites)
- [Setup & Installation](#-setup--installation)
- [Running the Application](#-running-the-application)
- [Environment Variables](#-environment-variables)
- [API Endpoints](#-api-endpoints)
- [Therapy Games](#-therapy-games)
- [Contributing](#-contributing)
- [License](#-license)

---

##  Features

###  Therapist Module
- **Student Management** — Add, view, and manage student profiles with auto-assignment of therapists
- **Therapy Sessions** — Schedule, track, and complete therapy sessions with detailed notes
- **Assessment Review** — Review video-based and questionnaire assessments submitted by parents
- **AI-Powered Reports** — Generate comprehensive child development reports using Google Gemini AI
- **PDF Export** — Download professionally formatted progress reports as PDFs
- **Therapy Recommendations** — AI-assisted therapy suggestions based on assessment data
- **Dashboard** — Overview of pending sessions, student progress, and session statistics

###  Parent Module
- **Video Upload & Assessment** — Upload child behavior videos for AI-based ASD screening
- **AQ Test** — Built-in Autism Quotient questionnaire for initial screening
- **Session Tracking** — View pending, scheduled, and completed therapy sessions
- **Progress Monitoring** — Track child's developmental progress over time with visual charts
- **Interactive Games** — Access therapy-focused games assigned to their child
- **Student Linking** — Register and link to their child's profile

###  Therapy Games (8 Games)
- **Magnet Catch** — Eye contact training through object tracking
- **Sound Match** — Speech & hearing development via audio-visual matching
- **Alphabet Fish** — Language development through interactive letter recognition
- **Emotion Slider** — Emotional recognition and regulation exercises
- **Glow Race** — Focus and attention training
- **Invisible Maze** — Cognitive skills and spatial reasoning
- **Jumping Numbers** — Numerical skills and coordination
- **Simon Says** — Social interaction and instruction following

###  AI & ML Features
- **Video Analysis** — DQN-based model for behavioral pattern detection from video uploads
- **ASD Risk Assessment** — MLP pipeline for autism screening based on questionnaire + video data
- **Gemini AI Reports** — Natural language report generation summarizing therapy progress
- **Therapy Recommendations** — ML-based therapy session recommendations

---

## 🛠 Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | Flutter / Dart (Web, Android, iOS) |
| **Backend** | Python, Flask, Flask-SQLAlchemy |
| **Database** | MySQL |
| **AI/ML** | TensorFlow, Keras, scikit-learn, Gemini API |
| **PDF Generation** | `pdf` (Dart), exported via browser download |
| **Video Processing** | OpenCV, MoviePy, Librosa |
| **Charts** | fl_chart (Flutter) |

---

##  Project Structure

```
AURA_APP/
├── lib/                            # Flutter frontend
│   ├── main.dart                   # App entry point
│   ├── intro_page.dart             # Splash/intro screen
│   ├── role_selection_page.dart    # Parent/Therapist role selector
│   ├── parent/                     # Parent module
│   │   ├── parent_login_page.dart
│   │   ├── parent_register_page.dart
│   │   ├── parent_home_page.dart
│   │   ├── parent_sessions_view.dart
│   │   ├── parent_progress_page.dart
│   │   ├── video_upload_page.dart
│   │   └── aq_test_page.dart
│   ├── therapist/                  # Therapist module
│   │   ├── therapist_dashboard.dart
│   │   ├── therapist_login_page.dart
│   │   ├── student_profiles_page.dart
│   │   ├── sessions_page.dart
│   │   ├── unreviewed_assesments_page.dart
│   │   ├── recommendation_page.dart
│   │   ├── pages/
│   │   │   ├── dashboard_page.dart
│   │   │   ├── child_detail_page.dart
│   │   │   └── child_info_page.dart
│   │   └── services/
│   │       ├── gemini_service.dart     # Gemini AI integration
│   │       └── pdf_service.dart        # PDF report generation
│   ├── games/                      # 8 therapy games
│   ├── screens/                    # Game & child screens
│   ├── services/                   # API & session services
│   └── widgets/                    # Shared UI components
│
├── backend/                        # Flask backend
│   ├── app.py                      # Main Flask application
│   ├── models.py                   # SQLAlchemy models
│   ├── games.py                    # Game definitions
│   ├── requirements.txt            # Python dependencies
│   ├── .env                        # Environment variables (git-ignored)
│   └── models/                     # ML model files
│       ├── video_dqn_model.h5
│       └── video_dqn_model1.h5
│
├── assets/images/                  # App logos and images
├── pubspec.yaml                    # Flutter dependencies
├── run.ps1                         # Run script with API key (git-ignored)
└── README.md
```

---

##  Prerequisites

- **Flutter SDK** >= 3.6.0
- **Python** >= 3.10
- **MySQL** >= 8.0
- **Google Gemini API Key** — [Get one here](https://aistudio.google.com/app/apikey)
- **Chrome** (for Flutter web)

---

##  Setup & Installation

### 1. Clone the repository

```bash
git clone https://github.com/Anagha-Devi10/AURA-Autism_Understanding_and_Rehabilitation_Assistant.git
cd AURA-Autism_Understanding_and_Rehabilitation_Assistant
```

### 2. Set up the MySQL database

```sql
CREATE DATABASE aura_db;
```

> Tables are auto-created by SQLAlchemy on first run.

### 3. Set up the backend

```bash
cd backend
python -m venv .venv

# Activate virtual environment
# Windows PowerShell:
.\.venv\Scripts\Activate.ps1
# macOS/Linux:
source .venv/bin/activate

pip install -r requirements.txt
```

### 4. Configure environment variables

Create a `backend/.env` file:

```env
DB_HOST=localhost
DB_USER=root
DB_PASS=your_mysql_password
DB_NAME=aura_db
```

### 5. Install Flutter dependencies

```bash
cd ..   # back to project root
flutter pub get
```

---

##  Running the Application

### Start the backend server

```bash
cd backend
python app.py
```

The backend runs on `http://localhost:5000`.

### Start the Flutter frontend

**Option A — With Gemini AI (recommended):**

```powershell
flutter run -d chrome --dart-define=GEMINI_API_KEY=your_gemini_api_key
```

**Option B — Using the run script (Windows):**

Create a `run.ps1` file in the project root (it's git-ignored):

```powershell
$env:GEMINI_API_KEY = "your_gemini_api_key"
flutter run -d chrome --dart-define="GEMINI_API_KEY=$env:GEMINI_API_KEY"
```

Then run:

```powershell
.\run.ps1
```

**Option C — Without Gemini AI:**

```bash
flutter run -d chrome
```

> Reports will be generated locally without AI when no API key is provided.

---

##  Environment Variables

| Variable | Location | Description |
|----------|----------|-------------|
| `DB_HOST` | `backend/.env` | MySQL host (default: `localhost`) |
| `DB_USER` | `backend/.env` | MySQL username (default: `root`) |
| `DB_PASS` | `backend/.env` | MySQL password |
| `DB_NAME` | `backend/.env` | Database name (default: `aura_db`) |
| `GEMINI_API_KEY` | `--dart-define` | Google Gemini API key for AI reports |

>  **Never hardcode credentials in source files.** Use `.env` files and `--dart-define` flags.

---

##  API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/register` | Register parent + create student |
| POST | `/login` | Parent login |
| POST | `/therapist/register` | Register therapist |
| POST | `/therapist/login` | Therapist login |

### Students
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/students` | List all students |
| GET | `/api/students/<id>` | Get student by ID |
| POST | `/api/students` | Create a student |
| DELETE | `/api/students/<id>` | Delete student (cascading) |

### Assessments
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/assessments` | Submit an assessment |
| GET | `/api/assessments/unreviewed` | Get unreviewed assessments |

### Therapy Sessions
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/therapy_sessions` | Create therapy session |
| PUT | `/api/therapy_sessions/<id>/schedule` | Schedule a session |
| GET | `/api/therapists/<id>/therapy_sessions` | Get therapist's sessions |
| GET | `/api/therapists/<id>/pending_sessions` | Get pending sessions |
| GET | `/api/therapists/<id>/scheduled_sessions` | Get scheduled sessions |

### Games
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/games` | List all therapy games |
| GET | `/api/games/<id>` | Get game details |
| POST | `/api/game_sessions` | Record game session |

---

##  Therapy Games

| Game | Focus Area | Age Group |
|------|-----------|-----------|
|  Magnet Catch | Eye Contact | 4-5 |
|  Sound Match | Speech & Hearing | 4-5 |
|  Alphabet Fish | Language | 4-5 |
|  Emotion Slider | Emotional Regulation | 4-5 |
|  Glow Race | Focus & Attention | 4-5 |
|  Invisible Maze | Cognitive Skills | 4-5 |
|  Jumping Numbers | Numerical Skills | 4-5 |
|  Simon Says | Social Interaction | 4-5 |

---

##  Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -m 'Add some feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a Pull Request

---

## 📄 License

This project is developed as part of an academic project for autism therapy assistance.

---
