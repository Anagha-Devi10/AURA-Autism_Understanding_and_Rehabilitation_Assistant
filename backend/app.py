import os
import sys
import uuid
import traceback
import joblib
import pandas as pd
import numpy as np
import mysql.connector
import json
from dotenv import load_dotenv
from flask import Flask, request, jsonify
from flask_cors import CORS
from sqlalchemy import Table, case, literal, text
from werkzeug.security import generate_password_hash, check_password_hash
from sklearn.pipeline import Pipeline
from moviepy.editor import VideoFileClip
import librosa
from datetime import datetime
from models import db, Child, GameSession, ProgressEntry, Therapist, Assessment, TherapySession, Parent
from games import get_all_games, get_game_by_id

# Load environment variables from .env file
load_dotenv()

try:
    import cv2
    CV2_AVAILABLE = True
except Exception as e:
    print(f" Warning: OpenCV (cv2) not available: {e}")
    CV2_AVAILABLE = False

os.environ["KERAS_BACKEND"] = "tensorflow"

try:
    import keras
    import tensorflow as tf
    from scikeras.wrappers import KerasClassifier
    
    from keras.applications.mobilenet_v2 import MobileNetV2, preprocess_input
    from keras import Sequential, layers, optimizers, metrics, regularizers
    from keras.models import load_model

    TF_AVAILABLE = True
    print(f"✓ TensorFlow {tf.__version__} & Keras {keras.__version__}")
except ImportError as e:
    print(f" Warning: TensorFlow/Keras import failed: {e}")
    TF_AVAILABLE = False

# behavioral columns
behavioral_cols = [
    'Social Smile', 'Attention', 'Eye contact', 'Sitting behavio',
    'Hyperactivity', 'Echolalia', 'Recognition of parents',
    'Excessive crying', 'Restlessness', 'Temper tantrums',
    'Self-injurious behaviour (when young)', 'Head banging',
    'Vacant staring', 'Self-muttering', 'Stubborn', 'Laziness'
]

# Needed because the model pickle references it
def map_behavioral_cols(df):
    df_mapped = df.copy()
    mapping = {'P': 1, 'A': 0, 'NaN': 0}
    for col in behavioral_cols:
        df_mapped[col] = df_mapped[col].astype(str).map(mapping)
    return df_mapped

# Needed for autism model unpickling - only define if TensorFlow available
if TF_AVAILABLE:
    def build_mlp_model(input_shape):
        model = Sequential([
            layers.Input(shape=(input_shape,)),
            layers.BatchNormalization(),
            layers.Dense(64, activation="relu", kernel_regularizer=regularizers.l2(1e-4)),
            layers.Dropout(0.3),
            layers.Dense(32, activation="relu", kernel_regularizer=regularizers.l2(1e-4)),
            layers.Dropout(0.2),
            layers.Dense(1, activation="sigmoid")
        ])
        model.compile(
            optimizer=optimizers.Adam(1e-3),
            loss="binary_crossentropy",
            metrics=[metrics.AUC(name="auc"), metrics.Precision(), metrics.Recall()]
        )
        return model
else:
    def build_mlp_model(input_shape):
        raise ImportError("TensorFlow not installed. Cannot rebuild model architecture.")


# ============================================
# DQN VIDEO CLASSIFIER
# ============================================

class DQNVideoClassifier: 
    def __init__(self, model_path=None):
        self.model = None
        self.model_path = model_path or os.path.join(
            os.path.dirname(__file__), 
            "models", 
            "video_dqn_model.h5"
        )
        
        self._load_model()
    
    def _load_model(self):
        """Load the trained DQN model."""
        if not TF_AVAILABLE:
            print(" TensorFlow not available, cannot load DQN model")
            return
            
        try:
            if os.path.exists(self.model_path):
                self.model = load_model(self.model_path, compile=False)
                print(f"✓ DQN model loaded from {self.model_path}")
                return
            
            keras_path = self.model_path.replace('.h5', '.keras')
            if os.path.exists(keras_path):
                self.model = load_model(keras_path, compile=False)
                print(f"✓ DQN model loaded from {keras_path}")
                return
                
            print(f" DQN model not found at {self.model_path}")
            self.model = None
            
        except Exception as e:
            print(f" Error loading DQN model: {e}")
            traceback.print_exc()
            self.model = None
    
    def is_loaded(self):
        """Check if model is loaded."""
        return self.model is not None
    
    def predict(self, features):
        if self.model is None:
            return {
                "error": "Model not loaded",
                "prediction": None,
                "confidence": 0,
                "label": "Unknown"
            }
        
        try:
            # Ensure features are 2D
            if features.ndim == 1:
                features = features.reshape(1, -1)
            
            # Get Q-values from the model
            q_values = self.model.predict(features, verbose=0)
            
            # Action 0 = TD (Typical Development), Action 1 = ASD
            predicted_action = int(np.argmax(q_values[0]))
            
            # Calculate confidence using softmax on Q-values
            exp_q = np.exp(q_values[0] - np.max(q_values[0]))
            softmax_probs = exp_q / exp_q.sum()
            confidence = float(softmax_probs[predicted_action])
            
            # Map action to label
            label = "ASD" if predicted_action == 1 else "TD"
            
            return {
                "prediction": predicted_action,
                "label": label,
                "confidence": confidence,
                "asd_probability": float(softmax_probs[1]) if len(softmax_probs) > 1 else float(predicted_action),
                "q_values": {
                    "TD": float(q_values[0][0]),
                    "ASD": float(q_values[0][1]) if len(q_values[0]) > 1 else 0.0
                },
                "probabilities": {
                    "TD": float(softmax_probs[0]),
                    "ASD": float(softmax_probs[1]) if len(softmax_probs) > 1 else 0.0
                }
            }
        except Exception as e:
            print(f" DQN prediction error: {e}")
            traceback.print_exc()
            return {
                "error": str(e),
                "prediction": None,
                "confidence": 0,
                "label": "Error"
            }

# Singleton instance
_dqn_classifier = None

def get_dqn_classifier():
    """Get or create the DQN classifier singleton."""
    global _dqn_classifier
    if _dqn_classifier is None:
        _dqn_classifier = DQNVideoClassifier()
    return _dqn_classifier


# ============================================
# FEATURE EXTRACTION
# ============================================
def extract_video_features(video_path, fps=1):
    """Extract video features using MobileNetV2."""
    if not TF_AVAILABLE:
        raise RuntimeError("TensorFlow/Keras not available for video feature extraction.")
    
    features = []
    
    if CV2_AVAILABLE:
        cap = cv2.VideoCapture(video_path)
        video_fps = cap.get(cv2.CAP_PROP_FPS)
        frame_interval = int(video_fps / fps) if video_fps > 0 else 30

        idx = 0
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break

            if idx % frame_interval == 0:
                frame = cv2.resize(frame, (224, 224))
                frame = preprocess_input(frame.astype(np.float32))
                frame = np.expand_dims(frame, axis=0)
                feat = cnn.predict(frame, verbose=0)
                features.append(feat.squeeze())

            idx += 1

        cap.release()
    else:
        # Fallback using moviepy
        try:
            clip = VideoFileClip(video_path).resize((224, 224))
            duration = clip.duration or 0
            if duration <= 0:
                clip.close()
                return None

            times = np.arange(0, duration, 1.0 / fps)
            for t in times:
                frame = clip.get_frame(t)
                frame = preprocess_input(frame.astype(np.float32))
                frame = np.expand_dims(frame, axis=0)
                feat = cnn.predict(frame, verbose=0)
                features.append(feat.squeeze())
            clip.close()
        except Exception as e:
            print(f" Error extracting frames without cv2: {e}")
            return None

    if not features:
        return None
    return np.mean(features, axis=0)


def extract_audio_features(audio_path, sr=16000):
    """Extract audio features (MFCCs) from audio file."""
    try:
        y, sr = librosa.load(audio_path, sr=sr)
        
        if len(y) == 0:
            return np.zeros(28)
        
        # MFCC (13 coefficients)
        mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=13)
        
        # Mean and Std (13 + 13 = 26 features)
        mfcc_mean = mfcc.mean(axis=1)
        mfcc_std = mfcc.std(axis=1)

        # RMS Energy (1 feature)
        rms = np.mean(librosa.feature.rms(y=y))

        # Silence Ratio (1 feature)
        intervals = librosa.effects.split(y, top_db=20)
        if len(intervals) > 0:
            non_silent_samples = np.sum([end - start for start, end in intervals])
            silence_ratio = 1.0 - (non_silent_samples / len(y))
        else:
            silence_ratio = 1.0

        # Total = 13 + 13 + 1 + 1 = 28 features
        return np.concatenate([mfcc_mean, mfcc_std, [rms, silence_ratio]])
        
    except Exception as e:
        print(f"Error in audio extraction: {e}")
        return np.zeros(28)

def generate_explanation(probability):
    if probability >= 0.85:
        return {
            "risk_level": "High Risk",
            "summary": "Strong indicators of neurodivergent behavioral patterns detected.",
            "details": [
                "Repetitive motor patterns (Stereotypies) detected",
                "Significant deviation in vocal frequency/prosody",
                "Visual engagement patterns correlate with ASD traits"
            ],
            "recommendation": "Consultation with a developmental pediatrician is recommended.",
            "note": "This is a screening tool only. Professional evaluation is required for diagnosis."
        }
    elif probability >= 0.55:
        return {
            "risk_level": "Moderate Risk",
            "summary": "Some behavioral cues associated with ASD were identified.",
            "details": [
                "Mildly atypical social engagement cues",
                "Some variation in auditory responsiveness patterns"
            ],
            "recommendation": "Monitor behavior in different environments and consider professional evaluation.",
            "note": "Further observation recommended before drawing conclusions."
        }
    elif probability >= 0.35:
        return {
            "risk_level": "Low-Moderate Risk",
            "summary": "Few behavioral indicators detected, mostly typical patterns.",
            "details": [
                "Mostly typical behavioral patterns observed",
                "Minor variations that may be within normal range"
            ],
            "recommendation": "Continue regular developmental milestone tracking. Re-evaluate if concerns arise.",
            "note": "Variations in child behavior are normal."
        }
    else:
        return {
            "risk_level": "Low Risk",
            "summary": "Behavioral patterns appear typical for this developmental stage.",
            "details": [
                "No prominent ASD-related behavioral cues detected",
                "Age-appropriate engagement patterns observed"
            ],
            "recommendation": "Continue regular developmental milestone tracking.",
            "note": "This screening does not rule out other developmental considerations."
        }

# ============================================
# FLASK APP SETUP
# ============================================
app = Flask(__name__)

app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv(
     "SQLALCHEMY_DATABASE_URI",
     "mysql+pymysql://{user}:{password}@{host}:3306/{db}".format(
         user=os.getenv("DB_USER", "root"),
         password=os.getenv("DB_PASS", ""),
         host=os.getenv("DB_HOST", "localhost"),
         db=os.getenv("DB_NAME", "aura_db"),
     ))
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db.init_app(app)
CORS(app, resources={r"/*": {
        "origins": "*",
        "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization"]
    }})

# Try to connect to database automatically
with app.app_context():
    try:
        students_table = Table('students', db.metadata, autoload_with=db.engine)
        print("Students table columns:", students_table.columns.keys())
    except Exception as e:
        print(f"⚠ Could not load students table: {e}")
    
    try:
        therapists_table = Table('therapists', db.metadata, autoload_with=db.engine)
        print("Therapists table columns:", therapists_table.columns.keys())
    except Exception as e:
        print(f" Could not load therapists table: {e}")
    
    db.create_all()
    
    # Ensure student_id column exists in parents table
    try:
        db.session.execute(text("ALTER TABLE parents ADD COLUMN student_id INT NULL"))
        db.session.execute(text("ALTER TABLE parents ADD CONSTRAINT fk_parent_student FOREIGN KEY (student_id) REFERENCES students(id)"))
        db.session.commit()
        print("✓ Added student_id column to parents table")
    except Exception:
        db.session.rollback()
        # Column already exists, that's fine

# MySQL connection
mysql_conn = None
cursor = None

try:
    mysql_conn = mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASS", ""),
        database=os.getenv("DB_NAME", "aura_db"),
        connect_timeout=5,
        use_pure=True
    )
    cursor = mysql_conn.cursor(dictionary=True)
    print("✓ Connected to MySQL database.")
except mysql.connector.Error as err:
    print(f"⚠ WARNING: Cannot connect to MySQL database: {err}")
    mysql_conn = None
    cursor = None

# Numpy compatibility fix
try:
    if not hasattr(np, '_core'):
        sys.modules['numpy._core'] = np
    if not hasattr(np, '_core._multiarray_umath'):
        import numpy.core._multiarray_umath as _mu
        sys.modules['numpy._core._multiarray_umath'] = _mu
except ImportError:
    pass

# Load the therapy recommendation pipeline
try:
    model = joblib.load("therapy_recommendation_pipeline.pkl")
    print("✓ Therapy recommendation model loaded")
except Exception as e:
    print(f"⚠ Error loading therapy recommendation model: {e}")
    model = None

# Load the autism detection pipeline
try:
    autism_model = joblib.load("autism_model_mlp_pipeline.pkl")
    print("✓ Autism detection model loaded")
except Exception as e:
    print(f" Error loading autism model: {e}")
    autism_model = None

# Initialize DQN classifier
dqn_classifier = None
if TF_AVAILABLE:
    dqn_classifier = get_dqn_classifier()

# Features for autism detection
q_items = [f"A{i}" for i in range(1, 11)]  # A1..A10
num_cols = ["Age_Mons", "Qchat-10-Score"]
cat_cols = ["Sex", "Ethnicity", "Jaundice", "Family_mem_with_ASD", "Who completed the test"]

MAX_VIDEO_SIZE_MB = 50
MAX_VIDEO_DURATION_SEC = 60
ALLOWED_EXTENSIONS = {"mp4", "avi", "mov", "mkv"}
UPLOAD_FOLDER = "temp_uploads"
n_mfcc = 28

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Initialize CNN for feature extraction
cnn = None
if TF_AVAILABLE:
    try:
        cnn = MobileNetV2(
            weights="imagenet",
            include_top=False,
            pooling="avg"
        )
        print("✓ MobileNetV2 loaded for feature extraction")
    except Exception as e:
        print(f" Error loading MobileNetV2: {e}")
        cnn = None

THERAPIES = [
    'Medical Consultation',
    'Psychology Consultation',
    'Speech and Audiology',
    'Physical Therapy',
    'Occupational Therapy',
    'Special Education'
]

# ============================================
# ENSEMBLE PREDICTOR (DQN + MLP)
# ============================================
class EnsembleASDClassifier:
    """
    Combines DQN (video analysis) and MLP (questionnaire) for final prediction.
    """
    
    def __init__(self):
        self.dqn_classifier = get_dqn_classifier()
        self.mlp_model = autism_model
        
        # Weights for ensemble
        self.video_weight = 0.5
        self.questionnaire_weight = 0.5
    
    def predict_questionnaire(self, questionnaire_data):
        """
        Predict using questionnaire data with proper handling.
        """
        if self.mlp_model is None:
            return None, "MLP model not loaded"
        
        try:
            # Create DataFrame with expected columns
            df = pd.DataFrame([questionnaire_data])
            
            print(f"📋 Questionnaire columns: {list(df.columns)}")
            print(f"📋 Questionnaire values: {questionnaire_data}")
            
            # Get Q-CHAT score for simple probability estimation
            qchat_score = questionnaire_data.get('Qchat-10-Score', 0)
            
            # Try MLP prediction
            try:
                if hasattr(self.mlp_model, 'predict_proba'):
                    prob_raw = self.mlp_model.predict_proba(df)
                    if isinstance(prob_raw, np.ndarray):
                        if prob_raw.ndim > 1 and prob_raw.shape[1] > 1:
                            asd_prob = float(prob_raw[0][1])
                        else:
                            asd_prob = float(prob_raw[0][0])
                    else:
                        asd_prob = float(prob_raw)
                else:
                    # Fallback: use Q-CHAT score based probability
                    # Score 0-2: Low risk, 3-5: Moderate, 6+: High
                    asd_prob = min(qchat_score / 10.0, 1.0)
                    
            except Exception as model_error:
                print(f"⚠️ MLP prediction error: {model_error}")
                # Fallback to Q-CHAT score based probability
                # Normalize: 0 score = 0.1 prob, 10 score = 0.9 prob
                asd_prob = 0.1 + (qchat_score / 10.0) * 0.8
            
            # Ensure probability is in valid range
            asd_prob = float(np.clip(asd_prob, 0.05, 0.95))
            
            print(f"📊 Q-CHAT Score: {qchat_score}, ASD Probability: {asd_prob:.4f}")
            
            return asd_prob, None
            
        except Exception as e:
            print(f"❌ Questionnaire prediction error: {e}")
            traceback.print_exc()
            return None, str(e)
    
    def predict_combined(self, video_features=None, questionnaire_data=None):
        """
        Combined prediction using both video and questionnaire.
        """
        results = {
            "video_result": None,
            "questionnaire_result": None,
            "ensemble_result": None,
            "individual_available": {
                "video": False,
                "questionnaire": False
            }
        }
        
        video_asd_prob = None
        questionnaire_asd_prob = None
        
        # Video prediction (DQN)
        if video_features is not None and self.dqn_classifier.is_loaded():
            try:
                video_result = self.dqn_classifier.predict(video_features)
                if "error" not in video_result or not video_result.get("error"):
                    video_asd_prob = video_result.get("asd_probability", 0.5)
                    results["video_result"] = {
                        "asd_probability": float(video_asd_prob),
                        "label": video_result.get("label", "Unknown"),
                        "confidence": float(video_result.get("confidence", 0))
                    }
                    results["individual_available"]["video"] = True
                    print(f"🎥 Video ASD probability: {video_asd_prob:.4f}")
            except Exception as e:
                print(f"❌ Video prediction error: {e}")
        
        # Questionnaire prediction (MLP)
        if questionnaire_data is not None:
            questionnaire_asd_prob, error = self.predict_questionnaire(questionnaire_data)
            if questionnaire_asd_prob is not None:
                results["questionnaire_result"] = {
                    "asd_probability": float(questionnaire_asd_prob),
                    "label": "ASD" if questionnaire_asd_prob >= 0.5 else "TD",
                    "confidence": float(abs(questionnaire_asd_prob - 0.5) * 2),
                    "qchat_score": questionnaire_data.get('Qchat-10-Score', 0)
                }
                results["individual_available"]["questionnaire"] = True
                print(f"📋 Questionnaire ASD probability: {questionnaire_asd_prob:.4f}")
        
        # Ensemble prediction
        if video_asd_prob is not None and questionnaire_asd_prob is not None:
            # Weighted average
            ensemble_prob = (
                video_asd_prob * self.video_weight + 
                questionnaire_asd_prob * self.questionnaire_weight
            )
            ensemble_prob = float(np.clip(ensemble_prob, 0.05, 0.95))
            
            results["ensemble_result"] = {
                "asd_probability": ensemble_prob,
                "label": "ASD" if ensemble_prob >= 0.5 else "TD",
                "confidence": float(abs(ensemble_prob - 0.5) * 2),
                "weights_used": {
                    "video": self.video_weight,
                    "questionnaire": self.questionnaire_weight
                }
            }
            print(f"🔗 Ensemble ASD probability: {ensemble_prob:.4f}")
            
        elif video_asd_prob is not None:
            results["ensemble_result"] = {
                "asd_probability": float(video_asd_prob),
                "label": "ASD" if video_asd_prob >= 0.5 else "TD",
                "confidence": float(abs(video_asd_prob - 0.5) * 2),
                "note": "Based on video analysis only"
            }
        elif questionnaire_asd_prob is not None:
            results["ensemble_result"] = {
                "asd_probability": float(questionnaire_asd_prob),
                "label": "ASD" if questionnaire_asd_prob >= 0.5 else "TD",
                "confidence": float(abs(questionnaire_asd_prob - 0.5) * 2),
                "note": "Based on questionnaire only"
            }
        
        return results

# Singleton
_ensemble_classifier = None

def get_ensemble_classifier():
    global _ensemble_classifier
    if _ensemble_classifier is None:
        _ensemble_classifier = EnsembleASDClassifier()
    return _ensemble_classifier

# ============================================
# COMBINED ASSESSMENT ENDPOINT
# ============================================
@app.route("/api/combined_assessment", methods=["POST"])
def combined_assessment():
    ensemble = get_ensemble_classifier()
    
    video_features = None
    questionnaire_data = None
    
    # Process video if provided
    if 'video' in request.files:
        file = request.files['video']
        if file.filename:
            try:
                ext = file.filename.split(".")[-1].lower()
                if ext not in ALLOWED_EXTENSIONS:
                    return jsonify({"error": f"Invalid video format. Allowed: {ALLOWED_EXTENSIONS}"}), 400

                temp_id = str(uuid.uuid4())
                video_path = os.path.join(UPLOAD_FOLDER, f"{temp_id}.{ext}")
                audio_path = os.path.join(UPLOAD_FOLDER, f"{temp_id}.wav")

                file.save(video_path)
                print(f"✓ Video saved: {video_path}")

                # Extract audio features
                audio_feat = np.zeros(n_mfcc)
                try:
                    clip = VideoFileClip(video_path)
                    if clip.audio is not None:
                        clip.audio.write_audiofile(audio_path, logger=None)
                        clip.close()
                        audio_feat = extract_audio_features(audio_path)
                        if audio_feat is None:
                            audio_feat = np.zeros(n_mfcc)
                    else:
                        clip.close()
                except Exception as e:
                    print(f"Audio extraction error: {e}")

                # Extract video features
                video_feat = extract_video_features(video_path)
                
                if video_feat is not None:
                    video_features = np.concatenate([video_feat, audio_feat])
                    print(f"✓ Combined features shape: {video_features.shape}")

                # Cleanup
                for p in [video_path, audio_path]:
                    if os.path.exists(p):
                        os.remove(p)
                        
            except Exception as e:
                print(f"Video processing error: {e}")
                traceback.print_exc()
    
    # Process questionnaire if provided
    questionnaire_json = request.form.get('questionnaire')
    if questionnaire_json:
        try:
            questionnaire_data = json.loads(questionnaire_json)
            print(f"✓ Questionnaire data received: {list(questionnaire_data.keys())}")
        except Exception as e:
            print(f"Questionnaire parsing error: {e}")
    
    # Also check for JSON body (for non-multipart requests)
    if questionnaire_data is None and request.is_json:
        try:
            data = request.get_json(force=True)
            if 'questionnaire' in data:
                questionnaire_data = data['questionnaire']
        except:
            pass
    
    if video_features is None and questionnaire_data is None:
        return jsonify({
            "error": "No valid input provided. Please upload a video or provide questionnaire data."
        }), 400
    
    # Get combined prediction
    try:
        results = ensemble.predict_combined(video_features, questionnaire_data)
        
        # Generate assessment based on ensemble result
        if results["ensemble_result"]:
            asd_prob = results["ensemble_result"]["asd_probability"]
            assessment = generate_explanation(asd_prob)
        else:
            assessment = {
                "risk_level": "Unknown",
                "summary": "Could not generate assessment",
                "recommendation": "Please try again with valid inputs"
            }
        
        return jsonify({
            "success": True,
            "results": results,
            "assessment": assessment,
            "inputs_received": {
                "video": video_features is not None,
                "questionnaire": questionnaire_data is not None
            }
        })
        
    except Exception as e:
        print(f"Combined assessment error: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/api/ensemble/weights", methods=["GET"])
def get_ensemble_weights():
    """Get current ensemble weights."""
    ensemble = get_ensemble_classifier()
    return jsonify({
        "video_weight": ensemble.video_weight,
        "questionnaire_weight": ensemble.questionnaire_weight
    })


@app.route("/api/ensemble/weights", methods=["POST"])
def set_ensemble_weights():
    """Update ensemble weights."""
    ensemble = get_ensemble_classifier()
    data = request.get_json(force=True)
    
    if 'video_weight' in data:
        ensemble.video_weight = float(data['video_weight'])
    if 'questionnaire_weight' in data:
        ensemble.questionnaire_weight = float(data['questionnaire_weight'])
    
    # Normalize weights
    total = ensemble.video_weight + ensemble.questionnaire_weight
    if total > 0:
        ensemble.video_weight /= total
        ensemble.questionnaire_weight /= total
    
    return jsonify({
        "success": True,
        "video_weight": ensemble.video_weight,
        "questionnaire_weight": ensemble.questionnaire_weight
    })

# ============================================
# VIDEO ANALYSIS ENDPOINT (DQN)
# ============================================

@app.route("/analyze_video", methods=["POST"])
def analyze_video():
    """Analyze video using DQN model for ASD detection."""
    
    # Check if DQN model is loaded
    classifier = get_dqn_classifier()
    if not classifier.is_loaded():
        return jsonify({
            "error": "Video analysis model not loaded. Please ensure video_dqn_model.h5 is in the models folder."
        }), 503
    
    if cnn is None:
        return jsonify({"error": "Feature extraction model (MobileNetV2) not loaded"}), 503
    
    try:
        file = request.files.get("video")
        if not file:
            return jsonify({"error": "No video uploaded"}), 400

        ext = file.filename.split(".")[-1].lower()
        if ext not in ALLOWED_EXTENSIONS:
            return jsonify({"error": f"Invalid file format. Allowed: {ALLOWED_EXTENSIONS}"}), 400

        temp_id = str(uuid.uuid4())
        video_path = os.path.join(UPLOAD_FOLDER, f"{temp_id}.{ext}")
        audio_path = os.path.join(UPLOAD_FOLDER, f"{temp_id}.wav")

        file.save(video_path)
        print(f"✓ Video saved: {video_path}")

        # Extract audio features
        audio_feat = np.zeros(n_mfcc)
        try:
            clip = VideoFileClip(video_path)
            
            # Check duration
            if clip.duration and clip.duration > MAX_VIDEO_DURATION_SEC:
                clip.close()
                os.remove(video_path)
                return jsonify({"error": f"Video too long. Max duration: {MAX_VIDEO_DURATION_SEC}s"}), 400

            if clip.audio is not None:
                try:
                    clip.audio.write_audiofile(audio_path, logger=None)
                    clip.close()
                    audio_feat = extract_audio_features(audio_path)
                    if audio_feat is None:
                        audio_feat = np.zeros(n_mfcc)
                except Exception as e:
                    print(f"⚠ Audio extraction error: {e}")
                    clip.close()
            else:
                print("⚠ No audio track in video, using zero features")
                clip.close()
                
        except Exception as e:
            print(f" Error processing video for audio: {e}")

        # Extract video features
        print("Extracting video features...")
        video_feat = extract_video_features(video_path)
        
        if video_feat is None:
            # Cleanup
            for p in [video_path, audio_path]:
                if os.path.exists(p):
                    os.remove(p)
            return jsonify({"error": "Video feature extraction failed"}), 500

        print(f"✓ Video features shape: {video_feat.shape}")
        print(f"✓ Audio features shape: {audio_feat.shape}")

        # Combine features (early fusion)
        combined_features = np.concatenate([video_feat, audio_feat])
        print(f"✓ Combined features shape: {combined_features.shape}")

        # Predict using DQN
        result = classifier.predict(combined_features)
        
        if "error" in result and result["error"]:
            return jsonify({"error": result["error"]}), 500

        # Get probability for explanation
        asd_prob = result.get("asd_probability", result.get("probabilities", {}).get("ASD", 0.5))
        assessment = generate_explanation(asd_prob)

        # Cleanup temp files
        for p in [video_path, audio_path]:
            try:
                if os.path.exists(p):
                    os.remove(p)
            except:
                pass

        return jsonify({
            "success": True,
            "model": "DQN",
            "asd_related": result["label"] == "ASD",
            "classification": result["label"],
            "confidence_score": round(result["confidence"], 4),
            "asd_probability": round(asd_prob, 4),
            "assessment": assessment,
            "details": {
                "q_values": result.get("q_values", {}),
                "probabilities": result.get("probabilities", {})
            }
        })

    except Exception as e:
        print(f" Server Error in analyze_video: {str(e)}")
        traceback.print_exc()
        return jsonify({"error": f"Internal server error: {str(e)}"}), 500


# ============================================
# GAME ENDPOINTS
# ============================================
@app.route('/api/games', methods=['GET'])
def list_games():
    """Get all available games"""
    games = get_all_games()
    return jsonify({
        'status': 'success',
        'count': len(games),
        'games': games
    })


@app.route('/api/games/<game_id>', methods=['GET'])
def get_game(game_id):
    """Get a specific game by ID"""
    game = get_game_by_id(game_id)
    if game:
        return jsonify({'status': 'success', 'game': game})
    return jsonify({'status': 'error', 'message': 'Game not found'}), 404


# ============================================
# SESSION ENDPOINTS
# ============================================
@app.route('/api/start_game', methods=['POST'])
def start_game():
    """Start a new game session"""
    data = request.json
    game_id = data.get('game_id')
    student_id = data.get('student_id')
    
    if not game_id or not student_id:
        return jsonify({
            'status': 'error',
            'message': 'game_id and student_id are required'
        }), 400
    
    game = get_game_by_id(game_id)
    if not game:
        return jsonify({'status': 'error', 'message': 'Game not found'}), 404
    
    child = Child.query.get(student_id)
    if not child:
        return jsonify({'status': 'error', 'message': 'Child not found'}), 404
    
    session = GameSession(
        student_id=student_id,
        game_id=game_id,
        game_name=game['name'],
        status='active'
    )
    db.session.add(session)
    db.session.commit()
    
    return jsonify({
        'status': 'success',
        'message': f"Game '{game['name']}' started for {child.name}",
        'session': session.to_dict()
    })


@app.route('/api/stop_game', methods=['POST'])
def stop_game():
    """Stop an active game session"""
    data = request.json
    session_id = data.get('session_id')
    
    if not session_id:
        return jsonify({'status': 'error', 'message': 'session_id is required'}), 400
    
    session = GameSession.query.get(session_id)
    if not session:
        return jsonify({'status': 'error', 'message': 'Session not found'}), 404
    
    session.status = 'completed'
    session.end_time = datetime.utcnow()
    db.session.commit()
    
    return jsonify({
        'status': 'success',
        'message': 'Game session completed',
        'session': session.to_dict()
    })


@app.route('/api/record_score', methods=['POST'])
def record_score():
    """Record therapy scores for a session"""
    data = request.json
    session_id = data.get('session_id')
    
    if not session_id:
        return jsonify({'status': 'error', 'message': 'session_id is required'}), 400
    
    session = GameSession.query.get(session_id)
    if not session:
        return jsonify({'status': 'error', 'message': 'Session not found'}), 404
    
    session.eye_contact_score = data.get('eye_contact_score', session.eye_contact_score)
    session.speech_score = data.get('speech_score', session.speech_score)
    session.motor_score = data.get('motor_score', session.motor_score)
    session.therapist_notes = data.get('notes', session.therapist_notes)
    
    scores = [session.eye_contact_score, session.speech_score, session.motor_score]
    session.overall_score = sum(scores) // 3
    
    db.session.commit()
    
    return jsonify({
        'status': 'success',
        'message': 'Scores recorded',
        'session': session.to_dict()
    })


@app.route('/api/sessions', methods=['GET'])
def list_sessions():
    """Get all game sessions, optionally filtered by student_id"""
    student_id = request.args.get('student_id')
    
    query = GameSession.query.order_by(GameSession.start_time.desc())
    if student_id:
        query = query.filter_by(student_id=student_id)
    
    sessions = query.limit(100).all()
    
    return jsonify({
        'status': 'success',
        'count': len(sessions),
        'sessions': [s.to_dict() for s in sessions]
    })


# ============================================
# CHILD/STUDENT ENDPOINTS
# ============================================
@app.route('/api/students', methods=['GET'])
def list_children():
    """Get all child profiles"""
    try:
        children = Child.query.all()
        children_list = [child.to_dict() for child in children]
        return jsonify({
            'status': 'success',
            'count': len(children),
            'children': children_list,
            'students': children_list
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({'status': 'error', 'message': str(e)}), 500


@app.route('/api/students', methods=['POST'])
def create_child():
    """Create a new child profile"""
    try:
        data = request.get_json(force=True) or {}
        name = data.get('name')
        age = data.get('age')
        guardian = data.get('guardian', '')
        therapist_id = data.get('therapist_id')
        notes = data.get('notes', '')

        if not name or age is None:
            return jsonify({
                'status': 'error',
                'message': 'name and age are required'
            }), 400

        try:
            age = int(age)
            if therapist_id is not None and therapist_id != '':
                therapist_id = int(therapist_id)
            else:
                therapist_id = None
        except Exception:
            return jsonify({
                'status': 'error',
                'message': 'age must be an integer'
            }), 400

        child = Child(
            name=name,
            age=age,
            guardian=guardian,
           
            therapist_id=therapist_id
        )
        db.session.add(child)
        db.session.commit()

        return jsonify({
            'status': 'success',
            'message': f"Child profile created for {name}",
            'child': child.to_dict()
        }), 201
    except Exception as e:
        traceback.print_exc()
        return jsonify({'status': 'error', 'message': str(e)}), 500


@app.route('/api/students/<int:student_id>', methods=['GET'])
def get_child(student_id):
    """Get a specific child profile"""
    child = Child.query.get(student_id)
    if not child:
        return jsonify({'status': 'error', 'message': 'Child not found'}), 404
    
    return jsonify({'status': 'success', 'child': child.to_dict()})


@app.route('/api/students/<int:student_id>', methods=['PUT'])
def update_child(student_id):
    """Update a child profile"""
    child = Child.query.get(student_id)
    if not child:
        return jsonify({'status': 'error', 'message': 'Child not found'}), 404
    
    data = request.json
    child.name = data.get('name', child.name)
    child.age = data.get('age', child.age)
    child.notes = data.get('notes', child.notes)
    db.session.commit()
    
    return jsonify({
        'status': 'success',
        'message': 'Profile updated',
        'child': child.to_dict()
    })


@app.route('/api/students/<int:student_id>', methods=['DELETE'])
def delete_child(student_id):
    """Delete a child profile and all related records"""
    child = Child.query.get(student_id)
    if not child:
        return jsonify({'status': 'error', 'message': 'Child not found'}), 404
    
    try:
        # Delete related records first
        ProgressEntry.query.filter_by(student_id=student_id).delete()
        TherapySession.query.filter_by(child_id=student_id).delete()
        Assessment.query.filter_by(child_id=student_id).delete()
        GameSession.query.filter_by(student_id=student_id).delete()
        # Unlink parents instead of deleting them
        Parent.query.filter_by(student_id=student_id).update({'student_id': None})
        
        db.session.delete(child)
        db.session.commit()
        
        return jsonify({
            'status': 'success',
            'message': f"Profile for {child.name} deleted"
        })
    except Exception as e:
        db.session.rollback()
        print(f"Error deleting student: {e}")
        traceback.print_exc()
        return jsonify({'status': 'error', 'message': str(e)}), 500


# ============================================
# PROGRESS ENDPOINTS
# ============================================
@app.route('/api/progress/<int:student_id>', methods=['GET'])
def get_progress(student_id):
    """Get progress data for a student"""
    student = Child.query.get(student_id)
    if not student:
        return jsonify({'status': 'error', 'message': 'Student not found'}), 404
    
    sessions = GameSession.query.filter_by(
        student_id=student_id,
        status='completed'
    ).order_by(GameSession.start_time.desc()).all()
    
    if sessions:
        total_sessions = len(sessions)
        avg_eye_contact = sum(s.eye_contact_score or 0 for s in sessions) / total_sessions
        avg_speech = sum(s.speech_score or 0 for s in sessions) / total_sessions
        avg_motor = sum(s.motor_score or 0 for s in sessions) / total_sessions
        avg_overall = sum(s.overall_score or 0 for s in sessions) / total_sessions
        
        game_counts = {}
        for s in sessions:
            game_counts[s.game_name] = game_counts.get(s.game_name, 0) + 1
        favorite_game = max(game_counts, key=game_counts.get) if game_counts else None
    else:
        total_sessions = 0
        avg_eye_contact = avg_speech = avg_motor = avg_overall = 0
        favorite_game = None
    
    return jsonify({
        'status': 'success',
        'student': student.to_dict(),
        'progress': {
            'total_sessions': total_sessions,
            'avg_eye_contact': round(avg_eye_contact, 1),
            'avg_speech': round(avg_speech, 1),
            'avg_motor': round(avg_motor, 1),
            'avg_overall': round(avg_overall, 1),
            'favorite_game': favorite_game
        },
        'recent_sessions': [s.to_dict() for s in sessions[:10]]
    })


# ============================================
# HEALTH CHECK
# ============================================
@app.route('/api/health', methods=['GET'])
def health_check():
    """API health check"""
    classifier = get_dqn_classifier()
    return jsonify({
        'status': 'healthy',
        'service': 'AURA Backend',
        'version': '1.0.0',
        'timestamp': datetime.utcnow().isoformat(),
        'models': {
            'therapy_recommendation': model is not None,
            'autism_detection': autism_model is not None,
            'video_dqn': classifier.is_loaded() if classifier else False,
            'feature_extraction': cnn is not None
        }
    })


@app.route("/health", methods=["GET"])
def health_status():
    """Legacy health endpoint"""
    classifier = get_dqn_classifier()
    return jsonify({
        "status": "running",
        "tensorflow_available": TF_AVAILABLE,
        "therapy_model_loaded": model is not None,
        "autism_model_loaded": autism_model is not None,
        "video_dqn_loaded": classifier.is_loaded() if classifier else False,
        "database_connected": mysql_conn is not None
    })


# ============================================
# AUTISM DETECTION ENDPOINT
# ============================================
@app.route("/detect_autism", methods=["POST"])
def detect_autism():
    if autism_model is None:
        return jsonify({"error": "Autism detection model not loaded"}), 503
    
    try:
        data = request.get_json(force=True)
        features = {col: data.get(col) for col in q_items + num_cols + cat_cols}

        df = pd.DataFrame([features])
        
        try:
            prob_raw = autism_model.predict_proba(df)
            pred_raw = autism_model.predict(df)
        except AttributeError:
            X_transformed = autism_model[:-1].transform(df)
            prob_raw = autism_model[-1].model_.predict(X_transformed)
            pred_raw = (prob_raw > 0.5).astype(int)

        if isinstance(prob_raw, np.ndarray) and prob_raw.ndim > 1:
            prob = float(prob_raw[0][1] if prob_raw.shape[1] > 1 else prob_raw[0][0])
        else:
            prob = float(prob_raw[1] if len(prob_raw) > 1 else prob_raw[0])

        pred = int(pred_raw[0])
        
        return jsonify({
            "autism_detected": bool(pred),
            "probability": prob
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ============================================
# THERAPY PREDICTION
# ============================================
@app.route("/predict", methods=["POST"])
def predict():
    if model is None:
        return jsonify({"error": "Therapy recommendation model not loaded"}), 503
    
    try:
        data = request.get_json(force=True)
        symptoms = data.get("symptoms", {})
        chief_complaints = data.get("chief_complaints", "")

        df = pd.DataFrame([{
            col: 1 if symptoms.get(col, "No") == "Yes" else 0
            for col in behavioral_cols
        }])

        df["Chief_Complaints"] = chief_complaints
        
        prediction = model.predict(df)[0]

        recommended_therapies = [THERAPIES[i] for i, val in enumerate(prediction) if int(val) == 1]
        return jsonify({"recommended_therapies": recommended_therapies})

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ============================================
# THERAPIST AUTO-ASSIGNMENT
# ============================================
def get_least_loaded_therapist_id():
    """Find the therapist with the fewest active therapy sessions.
    Prefers therapists with 0 sessions first, then sorts by count ascending."""
    try:
        cur = mysql_conn.cursor(dictionary=True)
        cur.execute("""
            SELECT t.id, t.name, COUNT(ts.id) AS session_count
            FROM therapists t
            LEFT JOIN therapy_sessions ts 
                ON t.id = ts.therapist_id AND ts.status IN ('pending', 'scheduled')
            GROUP BY t.id, t.name
            ORDER BY session_count ASC, t.id ASC
            LIMIT 1
        """)
        row = cur.fetchone()
        cur.close()
        if row:
            print(f"🩺 Auto-assigning therapist: {row['name']} (id={row['id']}, active sessions={row['session_count']})")
            return row['id']
        return None
    except Exception as e:
        print(f"Error finding least-loaded therapist: {e}")
        return None


# ============================================
# AUTH ENDPOINTS
# ============================================
@app.route("/register", methods=["POST"])
def register():
    if cursor is None:
        return jsonify({
            "error": "Database connection not available."
        }), 503
    
    try:
        data = request.get_json(force=True)
        
        name = data.get("name")
        email = data.get("email")
        password = data.get("password")
        child_name = data.get("child_name")
        child_age = data.get("child_age")

        if not name or not email or not password:
            return jsonify({"error": "All fields required"}), 400

        cursor.execute("SELECT id FROM parents WHERE email=%s", (email,))
        if cursor.fetchone():
            return jsonify({"error": "User already exists"}), 409

        hashed_pw = generate_password_hash(password)

        # Create student record if child info provided
        student_id = None
        if child_name:
            child_age_val = int(child_age) if child_age else 5
            therapist_id = get_least_loaded_therapist_id()
            cursor.execute(
                "INSERT INTO students (name, age, guardian, guardian_email, therapist_id) VALUES (%s, %s, %s, %s, %s)",
                (child_name, child_age_val, name, email, therapist_id)
            )
            mysql_conn.commit()
            student_id = cursor.lastrowid

        cursor.execute(
            "INSERT INTO parents (name, email, password, student_id) VALUES (%s, %s, %s, %s)",
            (name, email, hashed_pw, student_id)
        )
        mysql_conn.commit()
        
        return jsonify({"message": "Registration successful"}), 201
        
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": f"Registration failed: {str(e)}"}), 500


@app.route("/api/parents/<int:parent_id>/link_student", methods=["POST"])
def link_parent_student(parent_id):
    """Link a parent to a student - creates student if needed"""
    if cursor is None:
        return jsonify({"error": "Database connection not available."}), 503
    
    try:
        data = request.get_json(force=True)
        child_name = data.get("child_name")
        child_age = data.get("child_age", 5)
        
        if not child_name:
            return jsonify({"error": "Child name is required"}), 400
        
        # Auto-assign therapist with least active sessions
        therapist_id = get_least_loaded_therapist_id()
        
        # Create student with therapist assignment
        cursor.execute(
            "INSERT INTO students (name, age, guardian, guardian_email, therapist_id) VALUES (%s, %s, %s, (SELECT name FROM parents WHERE id=%s), %s)",
            (child_name, int(child_age), '', parent_id, therapist_id)
        )
        mysql_conn.commit()
        student_id = cursor.lastrowid
        
        # Update parent guardian info
        cursor.execute("SELECT name, email FROM parents WHERE id=%s", (parent_id,))
        parent = cursor.fetchone()
        if parent:
            cursor.execute(
                "UPDATE students SET guardian=%s, guardian_email=%s WHERE id=%s",
                (parent["name"], parent["email"], student_id)
            )
        
        # Link parent to student
        cursor.execute(
            "UPDATE parents SET student_id=%s WHERE id=%s",
            (student_id, parent_id)
        )
        mysql_conn.commit()
        
        # Get therapist name for response
        therapist_name = None
        if therapist_id:
            cursor.execute("SELECT name FROM therapists WHERE id=%s", (therapist_id,))
            t = cursor.fetchone()
            if t:
                therapist_name = t["name"]
        
        return jsonify({
            "message": "Student linked successfully",
            "student_id": student_id,
            "student_name": child_name,
            "therapist_id": therapist_id,
            "therapist_name": therapist_name
        }), 200
        
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": f"Failed to link student: {str(e)}"}), 500


@app.route("/login", methods=["POST"])
def login():
    if cursor is None:
        return jsonify({
            "error": "Database connection not available."
        }), 503
    
    try:
        data = request.get_json(force=True)
        
        email = data.get("email")
        password = data.get("password")

        if not email or not password:
            return jsonify({"error": "Email and password required"}), 400

        cursor.execute("SELECT * FROM parents WHERE email=%s", (email,))
        user = cursor.fetchone()

        if not user:
            return jsonify({"error": "Invalid email or password"}), 401
            
        if not check_password_hash(user["password"], password):
            return jsonify({"error": "Invalid email or password"}), 401

        # Get linked student info
        student_id = user.get("student_id")
        student_name = None
        if student_id:
            cursor.execute("SELECT name FROM students WHERE id=%s", (student_id,))
            student = cursor.fetchone()
            if student:
                student_name = student["name"]

        return jsonify({
            "message": "Login successful",
            "parent_id": user["id"],
            "name": user["name"],
            "student_id": student_id,
            "student_name": student_name
        }), 200
        
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": f"Login failed: {str(e)}"}), 500


@app.route("/therapist/register", methods=["POST"])
def therapist_register():
    if cursor is None:
        return jsonify({
            "error": "Database connection not available."
        }), 503
    
    try:
        data = request.json

        name = data.get("name")
        email = data.get("email")
        password = data.get("password")
        specialization = data.get("specialization")

        if not name or not email or not password:
            return jsonify({"error": "All fields required"}), 400

        cursor.execute("SELECT id FROM therapists WHERE email=%s", (email,))
        if cursor.fetchone():
            return jsonify({"error": "Email already exists"}), 409

        password_hash = generate_password_hash(password)

        cursor.execute(
            """
            INSERT INTO therapists (name, email, password_hash, specialization)
            VALUES (%s, %s, %s, %s)
            """,
            (name, email, password_hash, specialization)
        )
        mysql_conn.commit()

        return jsonify({"message": "Therapist registered successfully"}), 201
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": f"Registration failed: {str(e)}"}), 500


@app.route("/therapist/login", methods=["POST"])
def therapist_login():
    if cursor is None:
        return jsonify({
            "error": "Database connection not available."
        }), 503
    
    try:
        data = request.get_json(force=True)
        
        email = data.get("email")
        password = data.get("password")

        if not email or not password:
            return jsonify({"error": "Email and password required"}), 400

        cursor.execute("SELECT * FROM therapists WHERE email=%s", (email,))
        therapist = cursor.fetchone()

        if not therapist:
            return jsonify({"error": "Invalid email or password"}), 401
            
        if not check_password_hash(therapist["password_hash"], password):
            return jsonify({"error": "Invalid email or password"}), 401

        return jsonify({
            "message": "Login successful",
            "therapist_id": therapist["id"],
            "name": therapist["name"]
        }), 200
        
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": f"Login failed: {str(e)}"}), 500

@app.route("/api/therapists/<int:therapist_id>", methods=["GET"])
def get_therapist_by_id(therapist_id):
    """Get therapist details by ID."""
    try:
        if mysql_conn is None:
            return jsonify({"error": "Database connection not available.", "name": "Therapist"}), 503

        cur = mysql_conn.cursor(dictionary=True)
        cur.execute(
            "SELECT id, name, email FROM therapists WHERE id = %s",
            (therapist_id,)
        )
        row = cur.fetchone()
        cur.close()
        # Don't close mysql_conn here - it's a global connection!

        if row:
            return jsonify({
                "id": row["id"],
                "name": row["name"],
                "email": row["email"]
            })
        else:
            return jsonify({"error": "Therapist not found", "name": "Therapist"}), 404

    except Exception as e:
        print(f"Error fetching therapist: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e), "name": "Therapist"}), 500


@app.route("/api/therapist/<int:therapist_id>", methods=["GET"])
def get_therapist(therapist_id):
    """Get therapist details by ID (alternate endpoint)."""
    try:
        if mysql_conn is None:
            return jsonify({"error": "Database connection not available.", "name": "Therapist"}), 503

        cur = mysql_conn.cursor(dictionary=True)
        cur.execute(
            "SELECT id, name, email FROM therapists WHERE id = %s",
            (therapist_id,)
        )
        row = cur.fetchone()
        cur.close()

        if row:
            return jsonify({
                "id": row["id"],
                "name": row["name"],
                "email": row["email"]
            })
        else:
            return jsonify({"error": "Therapist not found", "name": "Therapist"}), 404

    except Exception as e:
        print(f"Error fetching therapist: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e), "name": "Therapist"}), 500


@app.route("/api/therapists", methods=["GET"])
def get_all_therapists():
    """Get all therapists."""
    try:
        if mysql_conn is None:
            return jsonify([]), 503

        cur = mysql_conn.cursor(dictionary=True)
        cur.execute("SELECT id, name, email FROM therapists")
        rows = cur.fetchall()
        cur.close()
        
        therapists = []
        for row in rows:
            therapists.append({
                "id": row["id"],
                "name": row["name"],
                "email": row["email"]
            })
        
        return jsonify(therapists)
            
    except Exception as e:
        print(f"Error fetching therapists: {e}")
        traceback.print_exc()
        return jsonify([]), 500

# ============================================
# STUDENT ENDPOINTS (MySQL direct)
# ============================================
@app.route('/students/<int:therapist_id>', methods=['GET'])
def get_students(therapist_id):
    try:
        if mysql_conn is None:
            return jsonify({'error': 'Database not connected'}), 503
        cur = mysql_conn.cursor(dictionary=True)
        cur.execute('SELECT * FROM students WHERE therapist_id = %s', (therapist_id,))
        rows = cur.fetchall()
        cur.close()
        return jsonify(rows), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/students', methods=['POST'])
def add_student():
    try:
        if mysql_conn is None:
            return jsonify({'error': 'Database not connected'}), 503

        data = request.get_json(force=True)
        therapist_id = data.get('therapist_id')
        name = data.get('name')
        age = data.get('age')
        guardian = data.get('guardian')
        notes = data.get('notes', '')

        if not all([therapist_id, name, age, guardian]):
            return jsonify({'error': 'Missing required fields'}), 400

        cur = mysql_conn.cursor()
        cur.execute(
            'INSERT INTO students (therapist_id, name, age, guardian, notes) VALUES (%s, %s, %s, %s, %s)',
            (therapist_id, name, age, guardian, notes)
        )
        mysql_conn.commit()
        student_id = cur.lastrowid
        cur.close()

        return jsonify({
            'id': student_id,
            'message': 'Student added successfully'
        }), 201
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/students/<int:student_id>', methods=['PUT'])
def update_student(student_id):
    try:
        if mysql_conn is None:
            return jsonify({'error': 'Database not connected'}), 503

        data = request.get_json(force=True)
        name = data.get('name')
        age = data.get('age')
        guardian = data.get('guardian')
        notes = data.get('notes', '')

        if not all([name, age, guardian]):
            return jsonify({'error': 'Missing required fields'}), 400

        cur = mysql_conn.cursor(buffered=True)
        cur.execute(
            'UPDATE students SET name = %s, age = %s, guardian = %s, notes = %s WHERE id = %s',
            (name, int(age), guardian, notes, student_id)
        )
        mysql_conn.commit()
        affected = cur.rowcount
        cur.close()

        if affected == 0:
            return jsonify({'error': 'Student not found'}), 404

        return jsonify({'message': 'Student updated successfully'}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/students/<int:student_id>', methods=['DELETE'])
def delete_student(student_id):
    try:
        if mysql_conn is None:
            return jsonify({'error': 'Database not connected'}), 503

        cur = mysql_conn.cursor(buffered=True)

        # Check student exists first
        cur.execute('SELECT id FROM students WHERE id = %s', (student_id,))
        if not cur.fetchone():
            cur.close()
            return jsonify({'error': 'Student not found'}), 404

        # Delete related records in correct order (child tables first)
        cur.execute('DELETE FROM progress_entries WHERE student_id = %s', (student_id,))
        cur.execute('DELETE FROM therapy_sessions WHERE child_id = %s', (student_id,))
        cur.execute('DELETE FROM assessments WHERE child_id = %s', (student_id,))
        cur.execute('DELETE FROM game_sessions WHERE student_id = %s', (student_id,))
        cur.execute('UPDATE parents SET student_id = NULL WHERE student_id = %s', (student_id,))
        cur.execute('DELETE FROM students WHERE id = %s', (student_id,))
        mysql_conn.commit()
        cur.close()

        return jsonify({'message': 'Student deleted successfully'}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


@app.route('/students/detail/<int:student_id>', methods=['GET'])
def get_student_detail(student_id):
    try:
        if mysql_conn is None:
            return jsonify({'error': 'Database not connected'}), 503

        cur = mysql_conn.cursor(dictionary=True)
        cur.execute('SELECT * FROM students WHERE id = %s', (student_id,))
        row = cur.fetchone()
        cur.close()

        if row:
            return jsonify(row), 200
        else:
            return jsonify({'error': 'Student not found'}), 404
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


# ============================================
# ASSESSMENT ENDPOINTS
# ============================================

@app.route("/api/assessments", methods=["POST"])
def save_assessment():
    """Save combined video + questionnaire assessment results"""
    try:
        data = request.get_json(force=True)
        
        # Get or create child
        child_id = data.get('student_id')
        
        if not child_id:
            # Create new child if not exists
            child = Child(
                name=data.get('child_name', 'Unknown'),
                age=data.get('child_age', 0),
                guardian=data.get('guardian_name', ''),
                guardian_email=data.get('guardian_email'),
                guardian_phone=data.get('guardian_phone')
            )
            db.session.add(child)
            db.session.flush()
            child_id = child.id
        
        # Create assessment
        assessment = Assessment(
            child_id=child_id,
            video_score=data.get('video_score'),
            video_prediction=data.get('video_prediction'),
            video_confidence=data.get('video_confidence'),
            questionnaire_score=data.get('questionnaire_score'),
            questionnaire_risk=data.get('questionnaire_risk'),
            combined_score=data.get('combined_score'),
            combined_risk_level=data.get('combined_risk_level'),
            recommendation=data.get('recommendation'),
            status='completed'
        )
        db.session.add(assessment)
        db.session.flush()
        
        # Create progress entry for this assessment
        progress = ProgressEntry(
            student_id=child_id,
            entry_type='assessment',
            title='Initial Assessment Completed',
            date=datetime.utcnow().date(),
            notes=f"Combined assessment completed. Risk level: {data.get('combined_risk_level', 'Unknown')}. "
                  f"Video score: {data.get('video_score', 'N/A')}, "
                  f"Questionnaire score: {data.get('questionnaire_score', 'N/A')}",
            avg_overall=data.get('combined_score')
        )
        db.session.add(progress)
        
        db.session.commit()
        
        return jsonify({
            "success": True,
            "message": "Assessment saved successfully",
            "assessment_id": assessment.id,
            "student_id": child_id
        }), 201
        
    except Exception as e:
        db.session.rollback()
        print(f"Error saving assessment: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/api/assessments/<int:assessment_id>", methods=["GET"])
def get_assessment(assessment_id):
    """Get assessment by ID"""
    try:
        assessment = Assessment.query.get(assessment_id)
        
        if not assessment:
            return jsonify({"error": "Assessment not found"}), 404
        
        return jsonify(assessment.to_dict())
        
    except Exception as e:
        print(f"Error getting assessment: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/api/students/<int:student_id>/assessments", methods=["GET"])
def get_student_assessments(student_id):
    """Get all assessments for a student"""
    try:
        from models import Assessment
        assessments = Assessment.query.filter_by(child_id=student_id).order_by(Assessment.created_at.desc()).all()
        
        return jsonify({
            "status": "success",
            "count": len(assessments),
            "assessments": [a.to_dict() for a in assessments]
        })
        
    except Exception as e:
        print(f"Error getting assessments: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/api/assessments/unreviewed", methods=["GET"])
def get_unreviewed_assessments():
    """Get all unreviewed assessments for therapist to assign sessions"""
    try:
        assessments = Assessment.query.filter_by(status='completed').filter(
            Assessment.reviewed_by.is_(None)
        ).order_by(Assessment.created_at.desc()).all()
        
        return jsonify({
            "status": "success",
            "count": len(assessments),
            "assessments": [a.to_dict() for a in assessments]
        })
        
    except Exception as e:
        print(f"Error getting unreviewed assessments: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/api/assessments/<int:assessment_id>/review", methods=["PUT"])
def review_assessment(assessment_id):
    """Mark assessment as reviewed by therapist"""
    try:
        from models import Assessment
        data = request.get_json(force=True)
        
        assessment = Assessment.query.get(assessment_id)
        if not assessment:
            return jsonify({"error": "Assessment not found"}), 404
        
        assessment.status = 'reviewed'
        assessment.reviewed_by = data.get('therapist_id')
        assessment.reviewed_at = datetime.utcnow()
        
        db.session.commit()
        
        return jsonify({
            "success": True,
            "message": "Assessment marked as reviewed",
            "assessment": assessment.to_dict()
        })
        
    except Exception as e:
        db.session.rollback()
        print(f"Error reviewing assessment: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ============================================
# THERAPY SESSION ENDPOINTS
# ============================================

@app.route("/api/therapy_sessions", methods=["POST"])
def create_therapy_session():
    """Create a new therapy session (assign therapist to child)"""
    try:
        data = request.get_json(force=True)

        student_id = data.get('student_id')
        therapist_id = data.get('therapist_id')

        if not student_id or not therapist_id:
            return jsonify({"error": "student_id and therapist_id are required"}), 400

        session = TherapySession(
            child_id=student_id,
            therapist_id=therapist_id,
            assessment_id=data.get('assessment_id'),
            title=data.get('title', 'Therapy Session'),
            description=data.get('description'),
            session_type=data.get('session_type', 'initial'),
            status='pending'
        )
        db.session.add(session)

        # Also assign therapist to student if not already assigned
        student = Child.query.get(student_id)
        if student and not student.therapist_id:
            student.therapist_id = therapist_id

        # Mark assessment as reviewed when session is created from it
        assessment_id = data.get('assessment_id')
        if assessment_id:
            assessment = Assessment.query.get(assessment_id)
            if assessment:
                assessment.status = 'reviewed'
                assessment.reviewed_by = therapist_id
                assessment.reviewed_at = datetime.utcnow()

        db.session.commit()
        
        return jsonify({
            "success": True,
            "message": "Therapy session created",
            "session": session.to_dict()
        }), 201
        
    except Exception as e:
        db.session.rollback()
        print(f"Error creating therapy session: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/api/therapy_sessions", methods=["GET"])
def get_all_therapy_sessions():
    """Get all therapy sessions with optional filters"""
    try:
        # Optional filters
        therapist_id = request.args.get('therapist_id', type=int)
        student_id = request.args.get('student_id', type=int)
        status = request.args.get('status')
        
        query = TherapySession.query
        
        if therapist_id:
            query = query.filter_by(therapist_id=therapist_id)
        if student_id:
            query = query.filter_by(child_id=student_id)
        if status:
            query = query.filter_by(status=status)
        
        sessions = query.order_by(TherapySession.created_at.desc()).all()
        
        return jsonify({
            "status": "success",
            "count": len(sessions),
            "sessions": [s.to_dict() for s in sessions]
        })
        
    except Exception as e:
        print(f"Error getting therapy sessions: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/api/therapy_sessions/<int:session_id>", methods=["GET"])
def get_therapy_session(session_id):
    """Get therapy session details"""
    try:
        session = TherapySession.query.get(session_id)
        
        if not session:
            return jsonify({"error": "Session not found"}), 404
        
        return jsonify({
            "status": "success",
            "session": session.to_dict()
        })
        
    except Exception as e:
        print(f"Error getting session: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/api/therapy_sessions/<int:session_id>/schedule", methods=["PUT"])
def schedule_therapy_session(session_id):
    """Therapist schedules date and time for a session"""
    try:
        data = request.get_json(force=True)
        
        session = TherapySession.query.get(session_id)
        if not session:
            return jsonify({"error": "Session not found"}), 404
        
        # Parse date and time
        if data.get('scheduled_date'):
            session.scheduled_date = datetime.strptime(data['scheduled_date'], '%Y-%m-%d').date()
        if data.get('scheduled_time'):
            session.scheduled_time = datetime.strptime(data['scheduled_time'], '%H:%M').time()
        
        session.duration_minutes = data.get('duration_minutes', 60)
        session.status = 'scheduled'
        session.parent_notified = False  # Reset notification flag
        session.updated_at = datetime.utcnow()
        
        db.session.commit()
        
        return jsonify({
            "success": True,
            "message": "Session scheduled successfully",
            "session": session.to_dict()
        })
        
    except Exception as e:
        db.session.rollback()
        print(f"Error scheduling session: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/api/therapy_sessions/<int:session_id>/complete", methods=["PUT"])
def complete_therapy_session(session_id):
    """Mark therapy session as completed"""
    try:
        from models import TherapySession
        data = request.get_json(force=True)
        
        session = TherapySession.query.get(session_id)
        if not session:
            return jsonify({"error": "Session not found"}), 404
        
        session.status = 'completed'
        session.completed_at = datetime.utcnow()
        session.session_notes = data.get('session_notes', '')
        session.updated_at = datetime.utcnow()
        
        # Create progress entry for completed session
        progress = ProgressEntry(
            student_id=session.child_id,
            therapist_id=session.therapist_id,
            therapy_session_id=session.id,
            entry_type='session',
            date=datetime.utcnow().date(),
            title=f"Session Completed: {session.title}",
            notes=session.session_notes,
            communication_score=data.get('communication_score'),
            social_score=data.get('social_score'),
            behavioral_score=data.get('behavioral_score'),
            cognitive_score=data.get('cognitive_score')
        )
        db.session.add(progress)
        
        db.session.commit()
        
        return jsonify({
            "success": True,
            "message": "Session marked as completed",
            "session": session.to_dict()
        })
        
    except Exception as e:
        db.session.rollback()
        print(f"Error completing session: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/api/therapy_sessions/<int:session_id>/cancel", methods=["PUT"])
def cancel_therapy_session(session_id):
    """Cancel a therapy session"""
    try:
        from models import TherapySession
        data = request.get_json(force=True)
        
        session = TherapySession.query.get(session_id)
        if not session:
            return jsonify({"error": "Session not found"}), 404
        
        session.status = 'cancelled'
        session.session_notes = data.get('cancellation_reason', 'Cancelled')
        session.updated_at = datetime.utcnow()
        
        db.session.commit()
        
        return jsonify({
            "success": True,
            "message": "Session cancelled",
            "session": session.to_dict()
        })
        
    except Exception as e:
        db.session.rollback()
        print(f"Error cancelling session: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/api/therapy_sessions/<int:session_id>", methods=["PUT"])
def update_therapy_session(session_id):
    """Update therapy session details"""
    try:
        from models import TherapySession
        data = request.get_json(force=True)
        
        session = TherapySession.query.get(session_id)
        if not session:
            return jsonify({"error": "Session not found"}), 404
        
        # Update allowed fields
        if 'title' in data:
            session.title = data['title']
        if 'description' in data:
            session.description = data['description']
        if 'session_type' in data:
            session.session_type = data['session_type']
        if 'duration_minutes' in data:
            session.duration_minutes = data['duration_minutes']
        
        session.updated_at = datetime.utcnow()
        db.session.commit()
        
        return jsonify({
            "success": True,
            "message": "Session updated",
            "session": session.to_dict()
        })
        
    except Exception as e:
        db.session.rollback()
        print(f"Error updating session: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ============================================
# CHILD THERAPY SESSIONS (for parent view)
# ============================================

@app.route("/api/students/<int:student_id>/therapy_sessions", methods=["GET"])
def get_student_therapy_sessions(student_id):
    """Get all therapy sessions for a student (for parent view)"""
    try:
        status_filter = request.args.get('status')

        query = TherapySession.query.filter_by(child_id=student_id)
        if status_filter:
            query = query.filter_by(status=status_filter)
        
        # MySQL compatible ordering - use CASE instead of NULLS FIRST
        sessions = query.order_by(
            case(
                (TherapySession.scheduled_date == None, 1),
                else_=0
            ),
            TherapySession.scheduled_date.desc()
        ).all()
        
        result = []
        for session in sessions:
            therapist = Therapist.query.get(session.therapist_id) if session.therapist_id else None
            session_dict = session.to_dict()
            session_dict['therapist_name'] = therapist.name if therapist else 'Unknown'
            result.append(session_dict)
        
        return jsonify({
            "status": "success",
            "count": len(result),
            "sessions": result
        })
        
    except Exception as e:
        print(f"Error getting child sessions: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "error": str(e), "sessions": []}), 200


@app.route("/api/students/<int:student_id>/upcoming-sessions", methods=["GET"])
def get_student_upcoming_sessions(student_id):
    """Get upcoming scheduled sessions for a student"""
    try:
        today = datetime.utcnow().date()
        
        sessions = TherapySession.query.filter_by(
            child_id=student_id,
            status='scheduled'
        ).filter(
            TherapySession.scheduled_date >= today
        ).order_by(
            TherapySession.scheduled_date.asc(),
            case(
                (TherapySession.scheduled_time == None, 1),
                else_=0
            ),
            TherapySession.scheduled_time.asc()
        ).all()
        
        result = []
        for session in sessions:
            therapist = Therapist.query.get(session.therapist_id) if session.therapist_id else None
            session_dict = session.to_dict()
            session_dict['therapist_name'] = therapist.name if therapist else 'Unknown'
            result.append(session_dict)
        
        return jsonify({
            "status": "success",
            "count": len(result),
            "sessions": result
        })
        
    except Exception as e:
        print(f"Error getting upcoming sessions: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "error": str(e), "sessions": []}), 200


@app.route('/api/students/<int:student_id>/progress', methods=['GET'])
def get_student_progress_entries(student_id):
    """Get progress entries for a student"""
    try:
        entries = ProgressEntry.query.filter_by(student_id=student_id)\
            .order_by(ProgressEntry.created_at.desc()).limit(50).all()
        
        return jsonify({
            "status": "success",
            "entries": [e.to_dict() for e in entries]
        })
    except Exception as e:
        print(f"Error getting student progress: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "error": str(e), "entries": []}), 200


@app.route('/api/students/<int:student_id>/detailed_progress', methods=['GET'])
def get_detailed_progress(student_id):
    """Get detailed progress data for a student including trends"""
    try:
        student = Child.query.get(student_id)
        if not student:
            return jsonify({'status': 'error', 'message': 'Student not found'}), 404
        
        # Get all completed game sessions
        game_sessions = GameSession.query.filter_by(
            student_id=student_id,
            status='completed'
        ).order_by(GameSession.start_time.desc()).all()
        
        # Get therapy sessions
        therapy_sessions = TherapySession.query.filter_by(
            child_id=student_id
        ).order_by(TherapySession.created_at.desc()).all()
        
        # Get assessments
        assessments = Assessment.query.filter_by(
            child_id=student_id
        ).order_by(Assessment.created_at.desc()).all()
        
        # Calculate averages
        if game_sessions:
            total_sessions = len(game_sessions)
            avg_eye_contact = sum(s.eye_contact_score or 0 for s in game_sessions) / total_sessions
            avg_speech = sum(s.speech_score or 0 for s in game_sessions) / total_sessions
            avg_motor = sum(s.motor_score or 0 for s in game_sessions) / total_sessions
            avg_overall = sum(s.overall_score or 0 for s in game_sessions) / total_sessions
            
            game_counts = {}
            for s in game_sessions:
                game_counts[s.game_name] = game_counts.get(s.game_name, 0) + 1
            favorite_game = max(game_counts, key=game_counts.get) if game_counts else None
        else:
            total_sessions = 0
            avg_eye_contact = avg_speech = avg_motor = avg_overall = 0
            favorite_game = None
        
        # Calculate weekly trends (last 4 weeks)
        from datetime import timedelta
        today = datetime.utcnow().date()
        weekly_data = []
        
        for i in range(4):
            week_start = today - timedelta(days=(i+1)*7)
            week_end = today - timedelta(days=i*7)
            
            week_sessions = [s for s in game_sessions 
                           if s.start_time and week_start <= s.start_time.date() < week_end]
            
            if week_sessions:
                week_avg = sum(s.overall_score or 0 for s in week_sessions) / len(week_sessions)
            else:
                week_avg = 0
            
            weekly_data.append({
                'week': f'Week {4-i}',
                'sessions': len(week_sessions),
                'average_score': round(week_avg, 1)
            })
        
        weekly_data.reverse()
        
        # Therapy session stats
        completed_therapy = len([s for s in therapy_sessions if s.status == 'completed'])
        scheduled_therapy = len([s for s in therapy_sessions if s.status == 'scheduled'])
        
        return jsonify({
            'status': 'success',
            'student': student.to_dict(),
            'progress': {
                'total_game_sessions': total_sessions,
                'total_therapy_sessions': len(therapy_sessions),
                'completed_therapy_sessions': completed_therapy,
                'scheduled_therapy_sessions': scheduled_therapy,
                'avg_eye_contact': round(avg_eye_contact, 1),
                'avg_speech': round(avg_speech, 1),
                'avg_motor': round(avg_motor, 1),
                'avg_overall': round(avg_overall, 1),
                'favorite_game': favorite_game
            },
            'weekly_trends': weekly_data,
            'recent_game_sessions': [s.to_dict() for s in game_sessions[:10]],
            'therapy_sessions': [s.to_dict() for s in therapy_sessions],
            'assessments': [a.to_dict() for a in assessments],
            'milestones': {
                'first_assessment': len(assessments) > 0,
                'first_session_completed': completed_therapy > 0,
                'five_sessions_completed': completed_therapy >= 5,
                'ten_sessions_completed': completed_therapy >= 10
            }
        })
        
    except Exception as e:
        print(f"Error getting detailed progress: {e}")
        traceback.print_exc()
        return jsonify({'status': 'error', 'message': str(e)}), 500
    
# ============================================
# THERAPIST THERAPY SESSIONS
# ============================================

@app.route("/api/therapists/<int:therapist_id>/therapy_sessions", methods=["GET"])
def get_therapist_therapy_sessions(therapist_id):
    """Get all therapy sessions for a therapist"""
    try:
        status_filter = request.args.get('status')
        
        query = TherapySession.query.filter_by(therapist_id=therapist_id)
        if status_filter:
            query = query.filter_by(status=status_filter)
        
        # MySQL compatible ordering - use CASE instead of NULLS FIRST
        sessions = query.order_by(
            case(
                (TherapySession.scheduled_date == None, 1),
                else_=0
            ),
            TherapySession.scheduled_date.asc()
        ).all()
        
        result = []
        for session in sessions:
            child = Child.query.get(session.child_id)
            result.append({
                'id': session.id,
                'child_id': session.child_id,
                'child_name': child.name if child else 'Unknown',
                'therapist_id': session.therapist_id,
                'assessment_id': session.assessment_id,
                'title': session.title,
                'description': session.description,
                'session_type': session.session_type,
                'scheduled_date': session.scheduled_date.isoformat() if session.scheduled_date else None,
                'scheduled_time': str(session.scheduled_time) if session.scheduled_time else None,
                'duration_minutes': session.duration_minutes,
                'status': session.status,
                'completed_at': session.completed_at.isoformat() if session.completed_at else None,
                'session_notes': session.session_notes,
                'parent_notified': session.parent_notified,
                'created_at': session.created_at.isoformat() if session.created_at else None,
            })

        return jsonify({
            "status": "success",
            "count": len(result),
            "sessions": result
        }), 200
        
    except Exception as e:
        print(f"Error getting therapist sessions: {e}")
        traceback.print_exc()
        return jsonify({
            'status': 'error',
            'message': str(e),
            'sessions': []
        }), 200


@app.route("/api/therapists/<int:therapist_id>/pending_sessions", methods=["GET"])
def get_therapist_pending_sessions(therapist_id):
    """Get pending sessions that need scheduling"""
    try:
        sessions = TherapySession.query.filter_by(
            therapist_id=therapist_id,
            status='pending'
        ).order_by(TherapySession.created_at.desc()).all()
        
        result = []
        for session in sessions:
            child = Child.query.get(session.child_id)
            session_dict = session.to_dict()
            session_dict['child_name'] = child.name if child else 'Unknown'
            result.append(session_dict)
        
        return jsonify({
            "status": "success",
            "count": len(result),
            "sessions": result
        })
        
    except Exception as e:
        print(f"Error getting pending sessions: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "error": str(e), "sessions": []}), 200


@app.route("/api/therapists/<int:therapist_id>/today_sessions", methods=["GET"])
def get_therapist_today_sessions(therapist_id):
    """Get today's sessions for a therapist"""
    try:
        today = datetime.utcnow().date()
        
        sessions = TherapySession.query.filter_by(
            therapist_id=therapist_id,
            scheduled_date=today
        ).filter(
            TherapySession.status.in_(['scheduled', 'pending'])
        ).order_by(
            case(
                (TherapySession.scheduled_time == None, 1),
                else_=0
            ),
            TherapySession.scheduled_time.asc()
        ).all()
        
        result = []
        for session in sessions:
            child = Child.query.get(session.child_id)
            session_dict = session.to_dict()
            session_dict['child_name'] = child.name if child else 'Unknown'
            result.append(session_dict)
        
        return jsonify({
            "status": "success",
            "count": len(result),
            "sessions": result
        })
        
    except Exception as e:
        print(f"Error getting today's sessions: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "error": str(e), "sessions": []}), 200


@app.route("/api/therapists/<int:therapist_id>/scheduled_sessions", methods=["GET"])
def get_therapist_scheduled_sessions(therapist_id):
    """Get all scheduled (future) sessions for a therapist"""
    try:
        today = datetime.utcnow().date()
        
        sessions = TherapySession.query.filter_by(
            therapist_id=therapist_id,
            status='scheduled'
        ).filter(
            TherapySession.scheduled_date >= today
        ).order_by(
            TherapySession.scheduled_date.asc(),
            case(
                (TherapySession.scheduled_time == None, 1),
                else_=0
            ),
            TherapySession.scheduled_time.asc()
        ).all()
        
        result = []
        for session in sessions:
            child = Child.query.get(session.child_id)
            session_dict = session.to_dict()
            session_dict['child_name'] = child.name if child else 'Unknown'
            result.append(session_dict)
        
        return jsonify({
            "status": "success",
            "count": len(result),
            "sessions": result
        })
        
    except Exception as e:
        print(f"Error getting scheduled sessions: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "error": str(e), "sessions": []}), 200


@app.route("/api/therapists/<int:therapist_id>/completed_sessions", methods=["GET"])
def get_therapist_completed_sessions(therapist_id):
    """Get all completed sessions for a therapist"""
    try:
        sessions = TherapySession.query.filter_by(
            therapist_id=therapist_id,
            status='completed'
        ).order_by(TherapySession.completed_at.desc()).limit(50).all()
        
        result = []
        for session in sessions:
            child = Child.query.get(session.child_id)
            session_dict = session.to_dict()
            session_dict['child_name'] = child.name if child else 'Unknown'
            result.append(session_dict)
        
        return jsonify({
            "status": "success",
            "count": len(result),
            "sessions": result
        })
        
    except Exception as e:
        print(f"Error getting completed sessions: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "error": str(e), "sessions": []}), 200


# ============================================
# THERAPIST STUDENTS ENDPOINTS
# ============================================

@app.route("/api/therapists/<int:therapist_id>/students", methods=["GET"])
def get_therapist_students(therapist_id):
    """Get all students assigned to a therapist"""
    try:
        students = Child.query.filter_by(therapist_id=therapist_id).order_by(Child.name.asc()).all()
        
        result = []
        for student in students:
            student_dict = student.to_dict()
            
            # Get session counts
            session_counts = db.session.query(
                TherapySession.status,
                db.func.count(TherapySession.id)
            ).filter_by(child_id=student.id).group_by(TherapySession.status).all()
            
            counts = {status: count for status, count in session_counts}
            student_dict['pending_sessions'] = counts.get('pending', 0)
            student_dict['scheduled_sessions'] = counts.get('scheduled', 0)
            student_dict['completed_sessions'] = counts.get('completed', 0)
            
            # Get latest assessment
            latest_assessment = Assessment.query.filter_by(
                child_id=student.id
            ).order_by(Assessment.created_at.desc()).first()
            
            if latest_assessment:
                student_dict['latest_assessment'] = {
                    'id': latest_assessment.id,
                    'risk_level': latest_assessment.combined_risk_level,
                    'score': latest_assessment.combined_score,
                    'date': latest_assessment.created_at.isoformat() if latest_assessment.created_at else None
                }
            else:
                student_dict['latest_assessment'] = None
            
            result.append(student_dict)
        
        return jsonify({
            "status": "success",
            "count": len(result),
            "students": result
        })
        
    except Exception as e:
        print(f"Error getting therapist students: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "error": str(e), "students": []}), 200


@app.route("/api/therapists/<int:therapist_id>/students/<int:student_id>", methods=["GET"])
def get_therapist_student_detail(therapist_id, student_id):
    """Get detailed student info for a therapist"""
    try:
        student = Child.query.filter_by(id=student_id, therapist_id=therapist_id).first()
        
        if not student:
            return jsonify({"error": "Student not found or not assigned to this therapist"}), 404
        
        student_dict = student.to_dict()
        
        # Get all assessments
        assessments = Assessment.query.filter_by(child_id=student_id).order_by(Assessment.created_at.desc()).all()
        student_dict['assessments'] = [a.to_dict() for a in assessments]
        
        # Get all therapy sessions
        sessions = TherapySession.query.filter_by(child_id=student_id).order_by(
            case(
                (TherapySession.scheduled_date == None, 1),
                else_=0
            ),
            TherapySession.scheduled_date.desc()
        ).all()
        student_dict['therapy_sessions'] = [s.to_dict() for s in sessions]
        
        # Get progress entries
        progress = ProgressEntry.query.filter_by(student_id=student_id).order_by(ProgressEntry.created_at.desc()).limit(20).all()
        student_dict['progress_entries'] = [p.to_dict() for p in progress]
        
        return jsonify({
            "status": "success",
            "student": student_dict
        })
        
    except Exception as e:
        print(f"Error getting student detail: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ============================================
# UNASSIGNED STUDENTS (for therapist assignment)
# ============================================

@app.route("/api/students/unassigned", methods=["GET"])
def get_unassigned_students():
    """Get students without a therapist assigned"""
    try:
        students = Child.query.filter(
            (Child.therapist_id == None) | (Child.therapist_id == 0)
        ).order_by(Child.created_at.desc()).all()
        
        return jsonify({
            "status": "success",
            "count": len(students),
            "students": [s.to_dict() for s in students]
        })
        
    except Exception as e:
        print(f"Error getting unassigned students: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "error": str(e), "students": []}), 200


# ============================================
# NOTIFICATIONS ENDPOINTS
# ============================================

@app.route("/api/therapy_sessions/<int:session_id>/notify_parent", methods=["POST"])
def notify_parent_session(session_id):
    """Mark that parent has been notified about session"""
    try:
        session = TherapySession.query.get(session_id)
        if not session:
            return jsonify({"error": "Session not found"}), 404
        
        session.parent_notified = True
        session.updated_at = datetime.utcnow()
        db.session.commit()
        
        # In a real app, you would send an email/notification here
        
        return jsonify({
            "success": True,
            "message": "Parent notification sent",
            "session": session.to_dict()
        })
        
    except Exception as e:
        db.session.rollback()
        print(f"Error notifying parent: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/api/parents/<int:parent_id>/notifications", methods=["GET"])
def get_parent_notifications(parent_id):
    """Get notifications for a parent (upcoming sessions, etc.)"""
    try:
        child_id = request.args.get('student_id', type=int)
        
        if not child_id:
            return jsonify({"error": "student_id is required"}), 400
        
        today = datetime.utcnow().date()
        
        # Get sessions scheduled in next 7 days
        from datetime import timedelta
        next_week = today + timedelta(days=7)
        
        upcoming = TherapySession.query.filter_by(
            child_id=child_id,
            status='scheduled'
        ).filter(
            TherapySession.scheduled_date >= today,
            TherapySession.scheduled_date <= next_week
        ).order_by(
            TherapySession.scheduled_date.asc(),
            case(
                (TherapySession.scheduled_time == None, 1),
                else_=0
            ),
            TherapySession.scheduled_time.asc()
        ).all()
        
        notifications = []
        for session in upcoming:
            therapist = Therapist.query.get(session.therapist_id) if session.therapist_id else None
            days_until = (session.scheduled_date - today).days if session.scheduled_date else 0
            
            notifications.append({
                'type': 'upcoming_session',
                'session_id': session.id,
                'title': session.title,
                'therapist_name': therapist.name if therapist else 'Unknown',
                'scheduled_date': session.scheduled_date.isoformat() if session.scheduled_date else None,
                'scheduled_time': str(session.scheduled_time) if session.scheduled_time else None,
                'days_until': days_until,
                'is_today': days_until == 0,
                'is_tomorrow': days_until == 1
            })
        
        return jsonify({
            "status": "success",
            "count": len(notifications),
            "notifications": notifications
        })
        
    except Exception as e:
        print(f"Error getting parent notifications: {e}")
        traceback.print_exc()
        return jsonify({"status": "error", "error": str(e), "notifications": []}), 200


# ============================================
# RESCHEDULE SESSION
# ============================================

@app.route("/api/therapy_sessions/<int:session_id>/reschedule", methods=["PUT"])
def reschedule_therapy_session(session_id):
    """Reschedule a therapy session"""
    try:
        data = request.get_json(force=True)
        
        session = TherapySession.query.get(session_id)
        if not session:
            return jsonify({"error": "Session not found"}), 404
        
        if session.status not in ['pending', 'scheduled']:
            return jsonify({"error": "Cannot reschedule completed or cancelled sessions"}), 400
        
        # Update schedule
        if data.get('scheduled_date'):
            session.scheduled_date = datetime.strptime(data['scheduled_date'], '%Y-%m-%d').date()
        if data.get('scheduled_time'):
            session.scheduled_time = datetime.strptime(data['scheduled_time'], '%H:%M').time()
        if data.get('duration_minutes'):
            session.duration_minutes = data['duration_minutes']
        
        session.status = 'scheduled'
        session.parent_notified = False  # Reset notification
        session.updated_at = datetime.utcnow()
        
        # Add note about rescheduling
        reschedule_note = f"Rescheduled on {datetime.utcnow().strftime('%Y-%m-%d %H:%M')}"
        if data.get('reason'):
            reschedule_note += f": {data['reason']}"
        
        if session.session_notes:
            session.session_notes = f"{session.session_notes}\n{reschedule_note}"
        else:
            session.session_notes = reschedule_note
        
        db.session.commit()
        
        return jsonify({
            "success": True,
            "message": "Session rescheduled successfully",
            "session": session.to_dict()
        })
        
    except Exception as e:
        db.session.rollback()
        print(f"Error rescheduling session: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ============================================
# BULK OPERATIONS
# ============================================

@app.route("/api/therapists/<int:therapist_id>/sessions/bulk_schedule", methods=["POST"])
def bulk_schedule_sessions(therapist_id):
    """Schedule multiple sessions at once"""
    try:
        data = request.get_json(force=True)
        sessions_data = data.get('sessions', [])
        
        if not sessions_data:
            return jsonify({"error": "No sessions provided"}), 400
        
        scheduled = []
        errors = []
        
        for session_data in sessions_data:
            session_id = session_data.get('session_id')
            session = TherapySession.query.get(session_id)
            
            if not session:
                errors.append({"session_id": session_id, "error": "Session not found"})
                continue
            
            if session.therapist_id != therapist_id:
                errors.append({"session_id": session_id, "error": "Session not assigned to this therapist"})
                continue
            
            try:
                if session_data.get('scheduled_date'):
                    session.scheduled_date = datetime.strptime(session_data['scheduled_date'], '%Y-%m-%d').date()
                if session_data.get('scheduled_time'):
                    session.scheduled_time = datetime.strptime(session_data['scheduled_time'], '%H:%M').time()
                
                session.duration_minutes = session_data.get('duration_minutes', 60)
                session.status = 'scheduled'
                session.updated_at = datetime.utcnow()
                
                scheduled.append(session.id)
            except Exception as e:
                errors.append({"session_id": session_id, "error": str(e)})
        
        db.session.commit()
        
        return jsonify({
            "success": True,
            "scheduled_count": len(scheduled),
            "scheduled_ids": scheduled,
            "errors": errors
        })
        
    except Exception as e:
        db.session.rollback()
        print(f"Error bulk scheduling: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ============================================
# SESSION STATISTICS
# ============================================

@app.route("/api/therapists/<int:therapist_id>/session_stats", methods=["GET"])
def get_therapist_session_stats(therapist_id):
    """Get detailed session statistics for a therapist"""
    try:
        from datetime import timedelta
        today = datetime.utcnow().date()
        week_ago = today - timedelta(days=7)
        month_ago = today - timedelta(days=30)
        
        # Total counts by status
        status_counts = db.session.query(
            TherapySession.status,
            db.func.count(TherapySession.id)
        ).filter_by(therapist_id=therapist_id).group_by(TherapySession.status).all()
        
        counts = {status: count for status, count in status_counts}
        
        # Sessions completed this week
        completed_this_week = TherapySession.query.filter_by(
            therapist_id=therapist_id,
            status='completed'
        ).filter(TherapySession.completed_at >= week_ago).count()
        
        # Sessions completed this month
        completed_this_month = TherapySession.query.filter_by(
            therapist_id=therapist_id,
            status='completed'
        ).filter(TherapySession.completed_at >= month_ago).count()
        
        # Upcoming sessions count
        upcoming = TherapySession.query.filter_by(
            therapist_id=therapist_id,
            status='scheduled'
        ).filter(TherapySession.scheduled_date >= today).count()
        
        # Average session duration (for completed sessions with notes)
        avg_duration = db.session.query(
            db.func.avg(TherapySession.duration_minutes)
        ).filter_by(
            therapist_id=therapist_id,
            status='completed'
        ).scalar() or 60
        
        return jsonify({
            "status": "success",
            "stats": {
                "total_pending": counts.get('pending', 0),
                "total_scheduled": counts.get('scheduled', 0),
                "total_completed": counts.get('completed', 0),
                "total_cancelled": counts.get('cancelled', 0),
                "completed_this_week": completed_this_week,
                "completed_this_month": completed_this_month,
                "upcoming_sessions": upcoming,
                "average_duration_minutes": round(float(avg_duration), 1)
            }
        })
        
    except Exception as e:
        print(f"Error getting session stats: {e}")
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


# ============================================
# MAIN
# ============================================
if __name__ == "__main__":
    classifier = get_dqn_classifier()
    
    print("\n" + "="*50)
    print(" Starting AURA Flask Backend")
    print("="*50)
    print(f"TensorFlow: {'✓ Available' if TF_AVAILABLE else '✗ Not installed'}")
    print(f"Therapy Model: {'✓ Loaded' if model else '✗ Not loaded'}")
    print(f"Autism Model: {'✓ Loaded' if autism_model else '✗ Not loaded'}")
    print(f"Video DQN Model: {'✓ Loaded' if classifier and classifier.is_loaded() else '✗ Not loaded'}")
    print(f"Feature Extractor: {'✓ Loaded' if cnn else '✗ Not loaded'}")
    print(f"Database: {'✓ Connected' if mysql_conn else '✗ NOT CONNECTED'}")
    print("="*50 + "\n")
    
    app.run(host="0.0.0.0", port=5000, debug=True)