"""
AURA Game Definitions
8 therapy games targeting eye contact, speech, and fine motor skills
"""

# Game definitions with therapy targets
GAMES = {
    "G1": {
        "id": "G1",
        "name": "Magnet Catch",
        "description": "Track floating objects with your eyes to catch them!",
        "therapy_focus": "Eye Contact",
        "instructions": [
            "Watch the floating magnet carefully",
            "Follow it with your eyes as it moves",
            "Tap when it reaches the target zone"
        ],
        "difficulty_levels": ["Easy", "Medium", "Hard"],
        "icon": "magnet",
        "color": "#E3F2FD",
        "target_age": "4-5"
    },
    "G2": {
        "id": "G2",
        "name": "Sound Match",
        "description": "Listen to sounds and match them to the right pictures!",
        "therapy_focus": "Speech & Hearing",
        "instructions": [
            "Listen to the sound that plays",
            "Look at the pictures on screen",
            "Tap the picture that matches the sound"
        ],
        "difficulty_levels": ["Easy", "Medium", "Hard"],
        "icon": "music_note",
        "color": "#F3E5F5",
        "target_age": "4-5"
    },
    "G3": {
        "id": "G3",
        "name": "Invisible Maze",
        "description": "Navigate through the maze by feeling the path!",
        "therapy_focus": "Fine Motor Skills",
        "instructions": [
            "Place your finger on the start",
            "Drag slowly to find the path",
            "Reach the end without touching walls"
        ],
        "difficulty_levels": ["Easy", "Medium", "Hard"],
        "icon": "grid_view",
        "color": "#E8F5E9",
        "target_age": "4-5"
    },
    "G4": {
        "id": "G4",
        "name": "Jumping Numbers",
        "description": "Count the jumping objects and tap the right number!",
        "therapy_focus": "Counting & Movement",
        "instructions": [
            "Watch the objects jump on screen",
            "Count how many there are",
            "Tap the correct number"
        ],
        "difficulty_levels": ["Easy", "Medium", "Hard"],
        "icon": "123",
        "color": "#FFF3E0",
        "target_age": "4-5"
    },
    "G5": {
        "id": "G5",
        "name": "Alphabet Fish",
        "description": "Catch the fish with the right letters to spell words!",
        "therapy_focus": "Letter Recognition",
        "instructions": [
            "Look at the word to spell",
            "Find fish with the right letters",
            "Tap them in the correct order"
        ],
        "difficulty_levels": ["Easy", "Medium", "Hard"],
        "icon": "abc",
        "color": "#E1F5FE",
        "target_age": "4-5"
    },
    "G6": {
        "id": "G6",
        "name": "Emotion Slider",
        "description": "Match the faces to the right emotions!",
        "therapy_focus": "Emotional Awareness",
        "instructions": [
            "Look at the face shown",
            "Slide to find the matching emotion",
            "Tap when you find the right one"
        ],
        "difficulty_levels": ["Easy", "Medium", "Hard"],
        "icon": "emoji_emotions",
        "color": "#FCE4EC",
        "target_age": "4-5"
    },
    "G7": {
        "id": "G7",
        "name": "Simon Says",
        "description": "Follow the pattern of colors and sounds!",
        "therapy_focus": "Following Instructions",
        "instructions": [
            "Watch and listen to the pattern",
            "Remember the sequence",
            "Repeat it by tapping the colors"
        ],
        "difficulty_levels": ["Easy", "Medium", "Hard"],
        "icon": "gamepad",
        "color": "#FFFDE7",
        "target_age": "4-5"
    },
    "G8": {
        "id": "G8",
        "name": "Glow Race",
        "description": "Follow the glowing light with your eyes!",
        "therapy_focus": "Visual Tracking",
        "instructions": [
            "Watch the glowing light",
            "Follow it as it moves in patterns",
            "Tap when it stops"
        ],
        "difficulty_levels": ["Easy", "Medium", "Hard"],
        "icon": "lightbulb",
        "color": "#E0F7FA",
        "target_age": "4-5"
    }
}


def get_all_games():
    """Return list of all games"""
    return list(GAMES.values())


def get_game_by_id(game_id):
    """Return a specific game by ID"""
    return GAMES.get(game_id)


def get_games_by_focus(therapy_focus):
    """Return games filtered by therapy focus"""
    return [g for g in GAMES.values() if g['therapy_focus'].lower() == therapy_focus.lower()]
