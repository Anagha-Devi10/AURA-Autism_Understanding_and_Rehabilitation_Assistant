"""
AURA Database Models
Defines Child profiles, Game Sessions, and Progress tracking
"""

from flask_sqlalchemy import SQLAlchemy
from datetime import datetime

db = SQLAlchemy()


class Child(db.Model):
    """Child profile for therapy tracking"""
    __tablename__ = 'students'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    age = db.Column(db.Integer, nullable=False)
    guardian = db.Column(db.String(255), nullable=False, default='')
    notes = db.Column(db.Text, nullable=True)
    therapist_id = db.Column(db.Integer, db.ForeignKey('therapists.id'), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationships
    sessions = db.relationship('GameSession', backref='child', lazy=True)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'age': self.age,
            'guardian': self.guardian,
            'notes': self.notes,
            'therapist_id': self.therapist_id,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }

class Therapist(db.Model):
    __tablename__ = 'therapists'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), nullable=False, unique=True)
    password_hash = db.Column(db.String(255), nullable=False)
    specialization = db.Column(db.String(255), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    students = db.relationship('Child', backref='therapist', lazy=True)

    def to_dict(self):
        return {'id': self.id, 'name': self.name, 'email': self.email, 'specialization': self.specialization,
            'created_at': self.created_at.isoformat() if self.created_at else None}

class GameSession(db.Model):
    """Records a game play session"""
    __tablename__ = 'game_sessions'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    student_id = db.Column(db.Integer, db.ForeignKey('students.id'), nullable=False)
    game_id = db.Column(db.String(10), nullable=False)
    game_name = db.Column(db.String(100), nullable=False)
    status = db.Column(db.String(20), default='active')  # active, completed, cancelled
    start_time = db.Column(db.DateTime, default=datetime.utcnow)
    end_time = db.Column(db.DateTime, nullable=True)
    
    # Therapy scores (0-100)
    eye_contact_score = db.Column(db.Integer, default=0)
    speech_score = db.Column(db.Integer, default=0)
    motor_score = db.Column(db.Integer, default=0)
    overall_score = db.Column(db.Integer, default=0)
    therapist_notes = db.Column(db.Text, nullable=True)
    
    def to_dict(self):
        return {
            'id': self.id,
            'student_id': self.student_id,
            'game_id': self.game_id,
            'game_name': self.game_name,
            'status': self.status,
            'start_time': self.start_time.isoformat() if self.start_time else None,
            'end_time': self.end_time.isoformat() if self.end_time else None,
            'eye_contact_score': self.eye_contact_score,
            'speech_score': self.speech_score,
            'motor_score': self.motor_score,
            'overall_score': self.overall_score,
            'therapist_notes': self.therapist_notes
        }


class ProgressEntry(db.Model):
    """Daily progress summary for a child"""
    __tablename__ = 'progress_entries'
    
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    student_id = db.Column(db.Integer, db.ForeignKey('students.id'), nullable=False)
    date = db.Column(db.Date, nullable=True)
    
    # Aggregated daily scores
    sessions_completed = db.Column(db.Integer, nullable=True)
    avg_eye_contact = db.Column(db.Float, nullable=True)
    avg_speech = db.Column(db.Float, nullable=True)
    avg_motor = db.Column(db.Float, nullable=True)
    avg_overall = db.Column(db.Float, nullable=True)
    
    # Engagement metrics
    total_play_time_minutes = db.Column(db.Integer, nullable=True)
    favorite_game = db.Column(db.String(100), nullable=True)
    
    def to_dict(self):
        return {
            'id': self.id,
            'student_id': self.student_id,
            'date': self.date.isoformat() if self.date else None,
            'sessions_completed': self.sessions_completed,
            'avg_eye_contact': self.avg_eye_contact,
            'avg_speech': self.avg_speech,
            'avg_motor': self.avg_motor,
            'avg_overall': self.avg_overall,
            'total_play_time_minutes': self.total_play_time_minutes,
            'favorite_game': self.favorite_game
        }
