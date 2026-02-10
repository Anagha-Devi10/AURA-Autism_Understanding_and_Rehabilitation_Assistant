import os
import sys
import uuid
import traceback
import joblib
import pandas as pd
import numpy as np
import mysql.connector
import json
from flask import Flask, request, jsonify
from flask_cors import CORS
from sqlalchemy import Table
from werkzeug.security import generate_password_hash, check_password_hash
from sklearn.pipeline import Pipeline
from moviepy.editor import VideoFileClip
import librosa
from datetime import datetime
from models import db, Child, GameSession, ProgressEntry, Therapist
from games import get_all_games, get_game_by_id

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
     "mysql+pymysql://root:anuuu1212@localhost:3306/aura_db")
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

# MySQL connection
mysql_conn = None
cursor = None

try:
    mysql_conn = mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASS", "anuuu1212"),
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
            notes=notes,
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
    """Delete a child profile"""
    child = Child.query.get(student_id)
    if not child:
        return jsonify({'status': 'error', 'message': 'Child not found'}), 404
    
    db.session.delete(child)
    db.session.commit()
    
    return jsonify({
        'status': 'success',
        'message': f"Profile for {child.name} deleted"
    })


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

        if not name or not email or not password:
            return jsonify({"error": "All fields required"}), 400

        cursor.execute("SELECT id FROM parents WHERE email=%s", (email,))
        if cursor.fetchone():
            return jsonify({"error": "User already exists"}), 409

        hashed_pw = generate_password_hash(password)

        cursor.execute(
            "INSERT INTO parents (name, email, password) VALUES (%s, %s, %s)",
            (name, email, hashed_pw)
        )
        mysql_conn.commit()
        
        return jsonify({"message": "Registration successful"}), 201
        
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": f"Registration failed: {str(e)}"}), 500


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

        return jsonify({
            "message": "Login successful",
            "parent_id": user["id"],
            "name": user["name"]
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
        cur.execute('DELETE FROM students WHERE id = %s', (student_id,))
        mysql_conn.commit()
        affected = cur.rowcount
        cur.close()

        if affected == 0:
            return jsonify({'error': 'Student not found'}), 404

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