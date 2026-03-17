#!/usr/bin/env python3
"""
Script to recreate the ML model pickle files with current scikit-learn version.
This creates basic placeholder models that can be replaced with real trained models.
"""

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.multioutput import MultiOutputClassifier

print("Creating placeholder models for scikit-learn 1.2.2 compatibility...")

# Create therapy recommendation model with proper multi-label support
# Wrap RandomForest with MultiOutputClassifier for 6 binary outputs (one per therapy)
clf_therapy = MultiOutputClassifier(RandomForestClassifier(n_estimators=10, random_state=42))

# Create dummy training data: 16 behavioral features, 6 therapy type outputs
X_therapy = np.random.randn(100, 16)
y_therapy = np.random.randint(0, 2, (100, 6))  # 6 therapies, binary for each
clf_therapy.fit(X_therapy, y_therapy)

# For consistency with the rest of the app, wrap in a simple dict-like object
# that has a predict method
therapy_model = clf_therapy

# Save therapy model
joblib.dump(therapy_model, 'therapy_recommendation_pipeline.pkl')
print("✓ Saved therapy_recommendation_pipeline.pkl")

# Test to verify output shape
test_input = np.random.randn(1, 16)
test_output = therapy_model.predict(test_input)
print(f"  Test prediction shape: {test_output.shape} (expected: (1, 6))")

# Create autism detection model (binary classification)
clf_autism = RandomForestClassifier(n_estimators=10, random_state=42)

# Create dummy training data
X_autism = np.random.randn(100, 15)  # 15 features
y_autism = np.random.randint(0, 2, 100)  # Binary: ASD or not
clf_autism.fit(X_autism, y_autism)

# Save autism model
joblib.dump(clf_autism, 'autism_model_mlp_pipeline.pkl')
print("✓ Saved autism_model_mlp_pipeline.pkl")

# Test to verify
test_input_autism = np.random.randn(1, 15)
test_output_autism = clf_autism.predict(test_input_autism)
print(f"  Test autism prediction shape: {test_output_autism.shape} (expected: (1,))")

print("\nModels created successfully!")
print("Note: These are placeholder models. For production, train with real data and replace these files.")
