import os
import sys
import uuid
import traceback
import joblib
import pandas as pd
import numpy as np
import mysql.connector
from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from sklearn.pipeline import Pipeline
from moviepy.editor import VideoFileClip
import librosa

os.environ["KERAS_BACKEND"] = "tensorflow"

try:
    import keras
    import tensorflow as tf
    from scikeras.wrappers import KerasClassifier
    
    from keras.applications.mobilenet_v2 import MobileNetV2, preprocess_input
    from keras import Sequential, layers, optimizers, metrics, regularizers

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
    # Dummy function for unpickling when TF not available
    def build_mlp_model(input_shape):
        raise ImportError("TensorFlow not installed. Cannot rebuild model architecture.")
    
def extract_video_features(video_path, fps=1):
    cap = cv2.VideoCapture(video_path)
    features = []

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
    return np.mean(features, axis=0)

def extract_audio_features(audio_path, n_mfcc=13):
    y, sr = librosa.load(audio_path, sr=None)
    mfcc = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=n_mfcc)
    return np.mean(mfcc, axis=1)
    
def generate_explanation(probability):
    if probability >= 0.8:
        return [
            "Reduced eye contact",
            "Repetitive motor behaviors",
            "Atypical vocal patterns"
        ]
    elif probability >= 0.5:
        return [
            "Mild social disengagement",
            "Inconsistent attention patterns"
        ]
    else:
        return ["No prominent ASD-related behavioral cues detected"]

app = Flask(__name__)
CORS(app, resources={r"/*": {
        "origins": "*",
        "methods": ["GET", "POST", "OPTIONS"],
        "allow_headers": ["Content-Type", "Authorization"]
    }})  # allow cross-origin requests
# Try to connect to database automatically
db = None
cursor = None

try:
    db = mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASS", "anuuu1212"),
        database=os.getenv("DB_NAME", "aura_db"),
        connect_timeout=5,
        use_pure=True
    )
    cursor = db.cursor(dictionary=True)
    print("✓ Connected to MySQL database.")
except mysql.connector.Error as err:
    print(f" WARNING: Cannot connect to MySQL database!")
    print(f"    Error: {err}")
    print(f"    Please ensure:")
    print(f"    1. MySQL is running")
    print(f"    2. Database 'aura_db' exists")
    print(f"    3. User 'root' has correct password")
    print(f"    Authentication endpoints will not work without database.")
    db = None
    cursor = None

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
    print(f" Error loading therapy recommendation model: {e}")
    traceback.print_exc()
    model = None

# Load the autism detection pipeline
try:
    autism_model = joblib.load("autism_model_mlp_pipeline.pkl")
    print("✓ Autism detection model loaded")
except Exception as e:
    print(f" Error loading autism model: {e}")
    traceback.print_exc()
    autism_model = None
print("step 10: defining /detect_autism endpoint")
sys.stdout.flush()
# Features for autism detection
q_items = [f"A{i}" for i in range(1, 11)]  # A1..A10
num_cols = ["Age_Mons", "Qchat-10-Score"]
cat_cols = ["Sex", "Ethnicity", "Jaundice", "Family_mem_with_ASD", "Who completed the test"]


svm_model = joblib.load("models/asd_video_audio_svm.joblib")
scaler = joblib.load("models/scaler.pkl")

MAX_VIDEO_SIZE_MB = 50
MAX_VIDEO_DURATION_SEC = 60
ALLOWED_EXTENSIONS = {"mp4"}
UPLOAD_FOLDER = "temp_uploads"

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

cnn = MobileNetV2(
    weights="imagenet",
    include_top=False,
    pooling="avg"
)

@app.route("/analyze_video", methods=["POST"])
def analyze_video():
    if svm_model is None or scaler is None:
        return jsonify({"error": "Video Analysis models not loaded"}), 503
    try:
        file = request.files.get("video")
        if not file:
            return jsonify({"error": "No video uploaded"}), 400

        ext = file.filename.split(".")[-1].lower()
        if ext not in ALLOWED_EXTENSIONS:
            return jsonify({"error": "Invalid file format"}), 400

        temp_id = str(uuid.uuid4())
        video_path = os.path.join(UPLOAD_FOLDER, f"{temp_id}.mp4")
        audio_path = os.path.join(UPLOAD_FOLDER, f"{temp_id}.wav")

        file.save(video_path)

        try:
            video_clip = VideoFileClip(video_path)
            # logger=None silences the console output
            video_clip.audio.write_audiofile(audio_path, logger=None)
            video_clip.close() # Critical: Release the file so it can be deleted later
        except Exception as e:
            print(f"Error extracting audio: {e}")
            return jsonify({"error": "Failed to process video audio"}), 500

        video_feat = extract_video_features(video_path)
        audio_feat = extract_audio_features(audio_path)

        X = np.concatenate([video_feat, audio_feat]).reshape(1, -1)
        X = scaler.transform(X)

        prob = svm_model.predict_proba(X)[0][1]
        prediction = int(prob >= 0.3)

        explanation = generate_explanation(prob)

        # Cleanup
        os.remove(video_path)
        os.remove(audio_path)

        return jsonify({
            "asd_related": bool(prediction),
            "probability": float(prob),
            "explanation": explanation
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/detect_autism", methods=["POST"])
def detect_autism():
    if autism_model is None:
        return jsonify({"error": "Autism detection model not loaded"}), 503
    
    try:
        data = request.get_json(force=True)
        # Collect all features
        features = {col: data.get(col) for col in q_items + num_cols + cat_cols}

        df = pd.DataFrame([features])
        
        try:
            # Standard way
            prob_raw = autism_model.predict_proba(df)
            pred_raw = autism_model.predict(df)
        except AttributeError:
            # Fallback if the 'tags' error persists
            # We transform the data through the pipeline steps except the last one
            X_transformed = autism_model[:-1].transform(df)
            # Use the Keras model directly
            prob_raw = autism_model[-1].model_.predict(X_transformed)
            pred_raw = (prob_raw > 0.5).astype(int)

        # Handle formatting
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

# Add this line to see exactly which feature names your model expects
if model and hasattr(model, "feature_names_in_"):
    print("Model expects features:", model.feature_names_in_)

THERAPIES = [
    'Medical Consultation',
    'Psychology Consultation',
    'Speech and Audiology',
    'Physical Therapy',
    'Occupational Therapy',
    'Special Education'
]

@app.route("/register", methods=["POST"])
def register():
    if cursor is None:
        return jsonify({
            "error": "Database connection not available. Please ensure MySQL is running and database is configured."
        }), 503
    
    try:
        # Get raw data and log it
        data = request.get_json(force=True)
        print(f" Register request data: {data}")
        
        name = data.get("name")
        email = data.get("email")
        password = data.get("password")
        
        print(f"   Name: {name}, Email: {email}, Password: {'***' if password else None}")

        if not name or not email or not password:
            print(f" Missing fields - Name: {bool(name)}, Email: {bool(email)}, Password: {bool(password)}")
            return jsonify({"error": "All fields required"}), 400

        cursor.execute("SELECT id FROM parents WHERE email=%s", (email,))
        if cursor.fetchone():
            print(f" User already exists: {email}")
            return jsonify({"error": "User already exists"}), 409

        hashed_pw = generate_password_hash(password)

        cursor.execute(
            "INSERT INTO parents (name, email, password) VALUES (%s, %s, %s)",
            (name, email, hashed_pw)
        )
        db.commit()
        
        print(f" Registration successful: {email}")
        return jsonify({"message": "Registration successful"}), 201
        
    except Exception as e:
        print(f" Registration error: {e}")
        traceback.print_exc()
        return jsonify({"error": f"Registration failed: {str(e)}"}), 500

@app.route("/login", methods=["POST"])
def login():
    if cursor is None:
        return jsonify({
            "error": "Database connection not available. Please ensure MySQL is running and database is configured."
        }), 503
    
    try:
        # Get raw data and log it
        data = request.get_json(force=True)
        print(f" Login request data: {data}")
        
        email = data.get("email")
        password = data.get("password")
        
        print(f"   Email: {email}, Password: {'***' if password else None}")

        if not email or not password:
            print(f" Missing fields - Email: {bool(email)}, Password: {bool(password)}")
            return jsonify({"error": "Email and password required"}), 400

        cursor.execute("SELECT * FROM parents WHERE email=%s", (email,))
        user = cursor.fetchone()

        if not user:
            print(f" User not found: {email}")
            return jsonify({"error": "Invalid email or password"}), 401
            
        if not check_password_hash(user["password"], password):
            print(f" Invalid password for: {email}")
            return jsonify({"error": "Invalid email or password"}), 401

        print(f" Login successful: {email}")
        return jsonify({
            "message": "Login successful",
            "parent_id": user["id"],
            "name": user["name"]
        }), 200
        
    except Exception as e:
        print(f" Login error: {e}")
        traceback.print_exc()
        return jsonify({"error": f"Login failed: {str(e)}"}), 500

@app.route("/therapist/register", methods=["POST"])
def therapist_register():
    if cursor is None:
        return jsonify({
            "error": "Database connection not available. Please ensure MySQL is running and database is configured."
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
        db.commit()

        return jsonify({"message": "Therapist registered successfully"}), 201
    except Exception as e:
        print(f"Therapist registration error: {e}")
        traceback.print_exc()
        return jsonify({"error": f"Registration failed: {str(e)}"}), 500

@app.route("/therapist/login", methods=["POST"])
def therapist_login():
    if cursor is None:
        return jsonify({
            "error": "Database connection not available. Please ensure MySQL is running and database is configured."
        }), 503
    
    try:
        # Get raw data and log it
        data = request.get_json(force=True)
        print(f" Therapist login request data: {data}")
        
        email = data.get("email")
        password = data.get("password")
        
        print(f"   Email: {email}, Password: {'***' if password else None}")

        if not email or not password:
            print(f" Missing fields - Email: {bool(email)}, Password: {bool(password)}")
            return jsonify({"error": "Email and password required"}), 400

        cursor.execute("SELECT * FROM therapists WHERE email=%s", (email,))
        therapist = cursor.fetchone()

        if not therapist:
            print(f" Therapist not found: {email}")
            return jsonify({"error": "Invalid email or password"}), 401
            
        if not check_password_hash(therapist["password_hash"], password):
            print(f" Invalid password for therapist: {email}")
            return jsonify({"error": "Invalid email or password"}), 401

        print(f" Therapist login successful: {email}")
        return jsonify({
            "message": "Login successful",
            "therapist_id": therapist["id"],
            "name": therapist["name"]
        }), 200
        
    except Exception as e:
        print(f" Therapist login error: {e}")
        traceback.print_exc()
        return jsonify({"error": f"Login failed: {str(e)}"}), 500

@app.route("/predict", methods=["POST"])
def predict():
    if model is None:
        return jsonify({"error": "Therapy recommendation model not loaded"}), 503
    
    print("Received /predict request")
    try:
        data = request.get_json(force=True)
        symptoms = data.get("symptoms", {})
        chief_complaints = data.get("chief_complaints", "")

        # Create DataFrame with all expected columns
        df = pd.DataFrame([{
            col: 1 if symptoms.get(col, "No") == "Yes" else 0
            for col in behavioral_cols
        }])

        # Add the text column
        df["Chief_Complaints"] = chief_complaints
        
        print("Incoming symptoms:", symptoms)
        print("DataFrame sent to model:")
        print(df)
        prediction = model.predict(df)[0]
        print("Raw model prediction:", prediction)

        # Map output to therapy names
        recommended_therapies = [THERAPIES[i] for i, val in enumerate(prediction) if int(val) == 1]
        print("Recommended therapies:", recommended_therapies)
        return jsonify({"recommended_therapies": recommended_therapies})

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

@app.route('/students/<int:therapist_id>', methods=['GET'])
def get_students(therapist_id):
    try:
        if db is None:
            return jsonify({'error': 'Database not connected'}), 503
        cur = db.cursor(dictionary=True)
        cur.execute('SELECT * FROM students WHERE therapist_id = %s', (therapist_id,))
        rows = cur.fetchall()
        cur.close()
        return jsonify(rows), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

# POST - Add new student
@app.route('/students', methods=['POST'])
def add_student():
    try:
        if db is None:
            return jsonify({'error': 'Database not connected'}), 503

        data = request.get_json(force=True)
        therapist_id = data.get('therapist_id')
        name = data.get('name')
        age = data.get('age')
        guardian = data.get('guardian')
        notes = data.get('notes', '')

        if not all([therapist_id, name, age, guardian]):
            return jsonify({'error': 'Missing required fields'}), 400

        cur = db.cursor()
        cur.execute(
            'INSERT INTO students (therapist_id, name, age, guardian, notes) VALUES (%s, %s, %s, %s, %s)',
            (therapist_id, name, age, guardian, notes)
        )
        db.commit()
        student_id = cur.lastrowid
        cur.close()

        return jsonify({
            'id': student_id,
            'message': 'Student added successfully'
        }), 201
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

# PUT - Update student
@app.route('/students/<int:student_id>', methods=['PUT'])
def update_student(student_id):
    try:
        if db is None:
            return jsonify({'error': 'Database not connected'}), 503

        data = request.get_json(force=True)
        name = data.get('name')
        age = data.get('age')
        guardian = data.get('guardian')
        notes = data.get('notes', '')

        if not all([name, age, guardian]):
            return jsonify({'error': 'Missing required fields'}), 400

        try:
            age = int(age)
        except Exception:
            return jsonify({'error': 'age must be an integer'}), 400

        cur = db.cursor(buffered=True)
        cur.execute(
            'UPDATE students SET name = %s, age = %s, guardian = %s, notes = %s WHERE id = %s',
            (name, age, guardian, notes, student_id)
        )
        db.commit()
        affected = cur.rowcount
        cur.close()

        if affected == 0:
            return jsonify({'error': 'Student not found'}), 404

        return jsonify({'message': 'Student updated successfully'}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

# DELETE - Remove student
@app.route('/students/<int:student_id>', methods=['DELETE'])
def delete_student(student_id):
    try:
        if db is None:
            return jsonify({'error': 'Database not connected'}), 503

        cur = db.cursor(buffered=True)
        cur.execute('DELETE FROM students WHERE id = %s', (student_id,))
        db.commit()
        affected = cur.rowcount
        cur.close()

        if affected == 0:
            return jsonify({'error': 'Student not found'}), 404

        return jsonify({'message': 'Student deleted successfully'}), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

# GET single student (optional, for detail view)
@app.route('/students/detail/<int:student_id>', methods=['GET'])
def get_student_detail(student_id):
    try:
        if db is None:
            return jsonify({'error': 'Database not connected'}), 503

        cur = db.cursor(dictionary=True)
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

@app.route("/health", methods=["GET"])
def health_check():
    return jsonify({
        "status": "running",
        "tensorflow_available": TF_AVAILABLE,
        "therapy_model_loaded": model is not None,
        "autism_model_loaded": autism_model is not None,
        "database_connected": USE_DB and db is not None
    })

if __name__ == "__main__":
    print("\n" + "="*50)
    print(" Starting AURA Flask Backend")
    print("="*50)
    print(f"TensorFlow: {'✓ Available' if TF_AVAILABLE else '✗ Not installed'}")
    print(f"Therapy Model: {'✓ Loaded' if model else '✗ Not loaded'}")
    print(f"Autism Model: {'✓ Loaded' if autism_model else '✗ Not loaded'}")
    print(f"Video model:{'✓ Loaded' if svm_model and scaler else '✗ Not loaded'}")
    print(f"Database: {'✓ Connected' if db else '✗ NOT CONNECTED - Auth endpoints will fail'}")
    print("="*50 + "\n")
    app.run(host="0.0.0.0", port=5000, debug=True)