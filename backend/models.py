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
    guardian_email = db.Column(db.String(255), nullable=True)
    guardian_phone = db.Column(db.String(50), nullable=True)
    notes = db.Column(db.Text, nullable=True)
    therapist_id = db.Column(db.Integer, db.ForeignKey('therapists.id'), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationships
    sessions = db.relationship('GameSession', backref='child', lazy=True)
    assessments = db.relationship('Assessment', backref='child', lazy=True)
    therapy_sessions = db.relationship('TherapySession', backref='child', lazy=True)
    progress_entries = db.relationship('ProgressEntry', backref='child', lazy=True)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'age': self.age,
            'guardian': self.guardian,
            'guardian_email': self.guardian_email,
            'guardian_phone': self.guardian_phone,
            'notes': self.notes,
            'therapist_id': self.therapist_id,
            'therapist_name': self.therapist.name if self.therapist else None,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }


class Therapist(db.Model):
    __tablename__ = 'therapists'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), nullable=False, unique=True)
    password_hash = db.Column(db.String(255), nullable=False)
    specialization = db.Column(db.String(255), nullable=True)
    phone = db.Column(db.String(20), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    students = db.relationship('Child', backref='therapist', lazy=True)
    therapy_sessions = db.relationship('TherapySession', backref='therapist', lazy=True)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'email': self.email,
            'specialization': self.specialization,
            'phone': self.phone,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }


class Parent(db.Model):
    """Parent profile linked to a student"""
    __tablename__ = 'parents'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120), nullable=False, unique=True)
    password = db.Column(db.String(255), nullable=False)
    student_id = db.Column(db.Integer, db.ForeignKey('students.id'), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationship
    student = db.relationship('Child', backref='parent', lazy=True)
    
    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'email': self.email,
            'student_id': self.student_id,
            'student_name': self.student.name if self.student else None,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }


class Assessment(db.Model):
    """Stores combined video + questionnaire assessment results"""
    __tablename__ = 'assessments'
    
    id = db.Column(db.Integer, primary_key=True)
    child_id = db.Column(db.Integer, db.ForeignKey('students.id'), nullable=False)
    
    # Video analysis results
    video_score = db.Column(db.Float, nullable=True)
    video_prediction = db.Column(db.String(50), nullable=True)  # 'ASD' or 'Non-ASD'
    video_confidence = db.Column(db.Float, nullable=True)
    
    # Questionnaire results
    questionnaire_score = db.Column(db.Float, nullable=True)
    questionnaire_risk = db.Column(db.String(50), nullable=True)  # 'High', 'Medium', 'Low'
    
    # Combined results
    combined_score = db.Column(db.Float, nullable=True)
    combined_risk_level = db.Column(db.String(50), nullable=True)  # 'High', 'Medium', 'Low'
    recommendation = db.Column(db.Text, nullable=True)
    
    # Status
    status = db.Column(db.String(50), default='completed')  # 'pending', 'completed', 'reviewed'
    reviewed_by = db.Column(db.Integer, db.ForeignKey('therapists.id'), nullable=True)
    reviewed_at = db.Column(db.DateTime, nullable=True)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationship to reviewer
    reviewer = db.relationship('Therapist', backref='reviewed_assessments', foreign_keys=[reviewed_by])
    
    def to_dict(self):
        return {
            'id': self.id,
            'child_id': self.child_id,
            'child_name': self.child.name if self.child else None,
            'video_score': self.video_score,
            'video_prediction': self.video_prediction,
            'video_confidence': self.video_confidence,
            'questionnaire_score': self.questionnaire_score,
            'questionnaire_risk': self.questionnaire_risk,
            'combined_score': self.combined_score,
            'combined_risk_level': self.combined_risk_level,
            'recommendation': self.recommendation,
            'status': self.status,
            'reviewed_by': self.reviewed_by,
            'reviewer_name': self.reviewer.name if self.reviewer else None,
            'reviewed_at': self.reviewed_at.isoformat() if self.reviewed_at else None,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }


class TherapySession(db.Model):
    """Therapy sessions assigned to children"""
    __tablename__ = 'therapy_sessions'
    
    id = db.Column(db.Integer, primary_key=True)
    child_id = db.Column(db.Integer, db.ForeignKey('students.id'), nullable=False)
    therapist_id = db.Column(db.Integer, db.ForeignKey('therapists.id'), nullable=False)
    assessment_id = db.Column(db.Integer, db.ForeignKey('assessments.id'), nullable=True)
    
    # Session details
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=True)
    session_type = db.Column(db.String(50), default='initial')  # 'initial', 'followup', 'review'
    
    # Scheduling
    scheduled_date = db.Column(db.Date, nullable=True)
    scheduled_time = db.Column(db.Time, nullable=True)
    duration_minutes = db.Column(db.Integer, default=60)
    
    # Status: pending -> scheduled -> completed/cancelled
    status = db.Column(db.String(50), default='pending')
    
    # Completion details
    completed_at = db.Column(db.DateTime, nullable=True)
    session_notes = db.Column(db.Text, nullable=True)
    
    # Notifications
    parent_notified = db.Column(db.Boolean, default=False)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    assessment = db.relationship('Assessment', backref='therapy_sessions')
    
    def to_dict(self):
        return {
            'id': self.id,
            'child_id': self.child_id,
            'child_name': self.child.name if self.child else None,
            'therapist_id': self.therapist_id,
            'therapist_name': self.therapist.name if self.therapist else None,
            'assessment_id': self.assessment_id,
            'title': self.title,
            'description': self.description,
            'session_type': self.session_type,
            'scheduled_date': self.scheduled_date.isoformat() if self.scheduled_date else None,
            'scheduled_time': self.scheduled_time.isoformat() if self.scheduled_time else None,
            'duration_minutes': self.duration_minutes,
            'status': self.status,
            'completed_at': self.completed_at.isoformat() if self.completed_at else None,
            'session_notes': self.session_notes,
            'parent_notified': self.parent_notified,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }


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
    therapist_id = db.Column(db.Integer, db.ForeignKey('therapists.id'), nullable=True)
    therapy_session_id = db.Column(db.Integer, db.ForeignKey('therapy_sessions.id'), nullable=True)
    
    # Entry type
    entry_type = db.Column(db.String(50), default='session')  # 'assessment', 'session', 'game', 'milestone'
    date = db.Column(db.Date, nullable=True)
    title = db.Column(db.String(200), nullable=True)
    notes = db.Column(db.Text, nullable=True)
    
    # Aggregated daily scores
    sessions_completed = db.Column(db.Integer, nullable=True)
    avg_eye_contact = db.Column(db.Float, nullable=True)
    avg_speech = db.Column(db.Float, nullable=True)
    avg_motor = db.Column(db.Float, nullable=True)
    avg_overall = db.Column(db.Float, nullable=True)
    
    # Individual area scores (1-10)
    communication_score = db.Column(db.Integer, nullable=True)
    social_score = db.Column(db.Integer, nullable=True)
    behavioral_score = db.Column(db.Integer, nullable=True)
    cognitive_score = db.Column(db.Integer, nullable=True)
    
    # Engagement metrics
    total_play_time_minutes = db.Column(db.Integer, nullable=True)
    favorite_game = db.Column(db.String(100), nullable=True)
    
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    
    # Relationships
    therapist = db.relationship('Therapist', backref='progress_entries')
    therapy_session = db.relationship('TherapySession', backref='progress_entries')
    
    def to_dict(self):
        return {
            'id': self.id,
            'student_id': self.student_id,
            'therapist_id': self.therapist_id,
            'therapist_name': self.therapist.name if self.therapist else None,
            'therapy_session_id': self.therapy_session_id,
            'entry_type': self.entry_type,
            'date': self.date.isoformat() if self.date else None,
            'title': self.title,
            'notes': self.notes,
            'sessions_completed': self.sessions_completed,
            'avg_eye_contact': self.avg_eye_contact,
            'avg_speech': self.avg_speech,
            'avg_motor': self.avg_motor,
            'avg_overall': self.avg_overall,
            'communication_score': self.communication_score,
            'social_score': self.social_score,
            'behavioral_score': self.behavioral_score,
            'cognitive_score': self.cognitive_score,
            'total_play_time_minutes': self.total_play_time_minutes,
            'favorite_game': self.favorite_game,
            'created_at': self.created_at.isoformat() if self.created_at else None
        }
