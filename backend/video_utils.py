import cv2
import numpy as np
import tensorflow as tf
from tensorflow.keras.applications.mobilenet_v2 import MobileNetV2, preprocess_input

cnn = MobileNetV2(
    weights="imagenet",
    include_top=False,
    pooling="avg"
)

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