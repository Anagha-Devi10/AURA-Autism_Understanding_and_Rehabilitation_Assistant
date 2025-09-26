from flask import Flask, request, jsonify
import joblib
from flask_cors import CORS
from typing import List

# List of behavioral columns used in preprocessing
behavioral_cols = [
    'Social Smile', 'Attention', 'Eye contact', 'Sitting behavior',
    'Hyperactivity', 'Echolalia', 'Recognition of parents',
    'Excessive crying', 'Restlessness', 'Temper tantrums',
    'Self-injurious behaviour (when young)', 'Head banging',
    'Vacant staring', 'Self-muttering', 'Stubborn', 'Laziness'
]

# Function required for unpickling the model
def map_behavioral_cols(df):
    df_mapped = df.copy()
    mapping = {'P': 1, 'A': 0, 'NaN': 0}  # Keep NaN for imputation
    for col in behavioral_cols:
        df_mapped[col] = df_mapped[col].astype(str).map(mapping)
    return df_mapped

app = Flask(__name__)
CORS(app)

# Load your trained model
model = joblib.load("therapy_recommendation_pipeline.pkl")

THERAPIES = [
    'Medical Consultation',
    'Psychology Consultation',
    'Speech and Audiology',
    'Physical Therapy',
    'Occupational Therapy',
    'Special Education'
]

@app.route("/predict", methods=["POST"])
def predict():
    data = request.get_json()
    symptoms = data.get("symptoms", {})

    # Convert symptoms to binary features
    features = [1 if symptoms.get(s, "No") == "Yes" else 0 for s in [
        'Social Smile', 'Attention', 'Eye contact', 'Sitting behavior',
        'Hyperactivity', 'Echolalia', 'Recognition of parents',
        'Excessive crying', 'Restlessness', 'Temper tantrums',
        'Self-injurious behaviour (when young)', 'Head banging',
        'Vacant staring', 'Self-muttering', 'Stubborn', 'Laziness'
    ]]

    # Predict therapy (single label classification)
    prediction = model.predict([features])[0]

    # Map prediction to therapy name
    recommended_therapy = [THERAPIES[i] for i, val in enumerate(prediction) if val == 1]
    # predicted_therapies = [therapy_cols[i] for i, pred in enumerate(prediction[0]) if pred == 1]
    return jsonify({
        "recommended_therapy": recommended_therapy
    })

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)