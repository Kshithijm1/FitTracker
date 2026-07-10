#!/usr/bin/env python3
"""One-off generator for the built-in exercise seed JSON (PLAN.md #2/#7).
Not run by the app; re-run manually if the exercise table changes.
"""
import json
import os

# (name, [muscleGroups], equipment)
EXERCISES = [
    # Chest
    ("Barbell Bench Press", ["chest", "triceps", "shoulders"], "barbell"),
    ("Incline Barbell Bench Press", ["chest", "shoulders", "triceps"], "barbell"),
    ("Decline Barbell Bench Press", ["chest", "triceps"], "barbell"),
    ("Dumbbell Bench Press", ["chest", "triceps", "shoulders"], "dumbbell"),
    ("Incline Dumbbell Bench Press", ["chest", "shoulders"], "dumbbell"),
    ("Decline Dumbbell Bench Press", ["chest"], "dumbbell"),
    ("Dumbbell Fly", ["chest"], "dumbbell"),
    ("Incline Dumbbell Fly", ["chest", "shoulders"], "dumbbell"),
    ("Cable Fly", ["chest"], "cable"),
    ("Cable Crossover", ["chest"], "cable"),
    ("Machine Chest Press", ["chest", "triceps"], "machine"),
    ("Pec Deck", ["chest"], "machine"),
    ("Push-Up", ["chest", "triceps", "core"], "bodyweight"),
    ("Diamond Push-Up", ["triceps", "chest"], "bodyweight"),
    ("Dips (Chest)", ["chest", "triceps"], "bodyweight"),
    ("Smith Machine Bench Press", ["chest", "triceps"], "machine"),

    # Back
    ("Deadlift", ["back", "hamstrings", "glutes"], "barbell"),
    ("Sumo Deadlift", ["glutes", "hamstrings", "back"], "barbell"),
    ("Trap Bar Deadlift", ["back", "glutes", "hamstrings"], "barbell"),
    ("Rack Pull", ["back", "hamstrings"], "barbell"),
    ("Barbell Row", ["back", "biceps"], "barbell"),
    ("Pendlay Row", ["back", "biceps"], "barbell"),
    ("T-Bar Row", ["back", "biceps"], "machine"),
    ("Meadows Row", ["back", "biceps"], "barbell"),
    ("Dumbbell Row", ["back", "biceps"], "dumbbell"),
    ("Chest Supported Row", ["back", "biceps"], "dumbbell"),
    ("Seated Cable Row", ["back", "biceps"], "cable"),
    ("Machine Row", ["back", "biceps"], "machine"),
    ("Lat Pulldown", ["back", "biceps"], "cable"),
    ("Close-Grip Lat Pulldown", ["back", "biceps"], "cable"),
    ("Pull-Up", ["back", "biceps"], "bodyweight"),
    ("Chin-Up", ["back", "biceps"], "bodyweight"),
    ("Straight-Arm Pulldown", ["back"], "cable"),
    ("Face Pull", ["shoulders", "back"], "cable"),
    ("Good Morning", ["hamstrings", "back", "glutes"], "barbell"),
    ("Hyperextension", ["back", "glutes", "hamstrings"], "bodyweight"),
    ("Superman", ["back", "core"], "bodyweight"),

    # Shoulders
    ("Overhead Press", ["shoulders", "triceps"], "barbell"),
    ("Seated Dumbbell Press", ["shoulders", "triceps"], "dumbbell"),
    ("Arnold Press", ["shoulders", "triceps"], "dumbbell"),
    ("Machine Shoulder Press", ["shoulders", "triceps"], "machine"),
    ("Landmine Press", ["shoulders", "chest"], "barbell"),
    ("Lateral Raise", ["shoulders"], "dumbbell"),
    ("Cable Lateral Raise", ["shoulders"], "cable"),
    ("Front Raise", ["shoulders"], "dumbbell"),
    ("Rear Delt Fly", ["shoulders", "back"], "dumbbell"),
    ("Reverse Pec Deck", ["shoulders", "back"], "machine"),
    ("Upright Row", ["shoulders", "back"], "barbell"),
    ("Barbell Shrug", ["shoulders", "back"], "barbell"),
    ("Dumbbell Shrug", ["shoulders", "back"], "dumbbell"),

    # Quads
    ("Back Squat", ["quads", "glutes"], "barbell"),
    ("Front Squat", ["quads", "glutes"], "barbell"),
    ("Zercher Squat", ["quads", "glutes", "back"], "barbell"),
    ("Smith Machine Squat", ["quads", "glutes"], "machine"),
    ("Hack Squat", ["quads", "glutes"], "machine"),
    ("Leg Press", ["quads", "glutes"], "machine"),
    ("Single-Leg Press", ["quads", "glutes"], "machine"),
    ("Leg Extension", ["quads"], "machine"),
    ("Goblet Squat", ["quads", "glutes"], "dumbbell"),
    ("Bulgarian Split Squat", ["quads", "glutes"], "dumbbell"),
    ("Walking Lunge", ["quads", "glutes"], "dumbbell"),
    ("Reverse Lunge", ["quads", "glutes"], "dumbbell"),
    ("Curtsy Lunge", ["quads", "glutes"], "dumbbell"),
    ("Cossack Squat", ["quads", "glutes", "hamstrings"], "bodyweight"),
    ("Step-Up", ["quads", "glutes"], "dumbbell"),
    ("Sissy Squat", ["quads"], "bodyweight"),

    # Hamstrings / Glutes
    ("Romanian Deadlift", ["hamstrings", "glutes", "back"], "barbell"),
    ("Stiff-Leg Deadlift", ["hamstrings", "glutes"], "barbell"),
    ("Single-Leg Romanian Deadlift", ["hamstrings", "glutes"], "dumbbell"),
    ("Leg Curl (Seated)", ["hamstrings"], "machine"),
    ("Leg Curl (Lying)", ["hamstrings"], "machine"),
    ("Nordic Curl", ["hamstrings"], "bodyweight"),
    ("Hip Thrust", ["glutes", "hamstrings"], "barbell"),
    ("Glute Bridge", ["glutes", "hamstrings"], "bodyweight"),
    ("Cable Pull-Through", ["glutes", "hamstrings"], "cable"),
    ("Glute Kickback", ["glutes"], "cable"),
    ("Frog Pump", ["glutes"], "bodyweight"),
    ("Copenhagen Plank", ["hamstrings", "core"], "bodyweight"),

    # Calves
    ("Standing Calf Raise", ["calves"], "machine"),
    ("Seated Calf Raise", ["calves"], "machine"),
    ("Leg Press Calf Raise", ["calves"], "machine"),
    ("Donkey Calf Raise", ["calves"], "machine"),

    # Biceps
    ("Barbell Curl", ["biceps"], "barbell"),
    ("EZ-Bar Curl", ["biceps"], "barbell"),
    ("Dumbbell Curl", ["biceps"], "dumbbell"),
    ("Hammer Curl", ["biceps", "forearms"], "dumbbell"),
    ("Incline Dumbbell Curl", ["biceps"], "dumbbell"),
    ("Preacher Curl", ["biceps"], "barbell"),
    ("Spider Curl", ["biceps"], "dumbbell"),
    ("Concentration Curl", ["biceps"], "dumbbell"),
    ("Cable Curl", ["biceps"], "cable"),
    ("Zottman Curl", ["biceps", "forearms"], "dumbbell"),
    ("Cross-Body Hammer Curl", ["biceps", "forearms"], "dumbbell"),

    # Triceps
    ("Triceps Pushdown", ["triceps"], "cable"),
    ("Rope Pushdown", ["triceps"], "cable"),
    ("Overhead Triceps Extension", ["triceps"], "dumbbell"),
    ("Cable Overhead Extension", ["triceps"], "cable"),
    ("Skull Crusher", ["triceps"], "barbell"),
    ("JM Press", ["triceps", "chest"], "barbell"),
    ("Close-Grip Bench Press", ["triceps", "chest"], "barbell"),
    ("Dips (Triceps)", ["triceps", "chest"], "bodyweight"),
    ("Tricep Dip Machine", ["triceps", "chest"], "machine"),
    ("Cable Kickback", ["triceps"], "cable"),

    # Forearms
    ("Wrist Curl", ["forearms"], "barbell"),
    ("Reverse Wrist Curl", ["forearms"], "barbell"),
    ("Reverse Curl", ["forearms", "biceps"], "barbell"),
    ("Farmer's Carry", ["forearms", "core"], "dumbbell"),

    # Core
    ("Plank", ["core"], "bodyweight"),
    ("Side Plank", ["core"], "bodyweight"),
    ("Crunch", ["core"], "bodyweight"),
    ("Cable Crunch", ["core"], "cable"),
    ("Hanging Leg Raise", ["core"], "bodyweight"),
    ("Hanging Knee Raise", ["core"], "bodyweight"),
    ("Russian Twist", ["core"], "bodyweight"),
    ("Ab Wheel Rollout", ["core"], "bodyweight"),
    ("Sit-Up", ["core"], "bodyweight"),
    ("V-Up", ["core"], "bodyweight"),
    ("Mountain Climber", ["core", "shoulders"], "bodyweight"),
    ("Dead Bug", ["core"], "bodyweight"),
    ("Bicycle Crunch", ["core"], "bodyweight"),
    ("Woodchopper", ["core"], "cable"),
    ("Pallof Press", ["core"], "cable"),
    ("Landmine Twist", ["core"], "barbell"),

    # Olympic / Full body
    ("Clean", ["back", "quads", "shoulders"], "barbell"),
    ("Power Clean", ["back", "quads", "shoulders"], "barbell"),
    ("Snatch", ["back", "quads", "shoulders"], "barbell"),
    ("Clean and Jerk", ["back", "quads", "shoulders"], "barbell"),
    ("Thruster", ["quads", "shoulders"], "barbell"),
    ("Kettlebell Swing", ["glutes", "hamstrings", "core"], "kettlebell"),
    ("Turkish Get-Up", ["core", "shoulders"], "kettlebell"),
    ("Burpee", ["core", "chest", "quads"], "bodyweight"),
    ("Wall Ball", ["quads", "shoulders"], "medicine ball"),
    ("Box Jump", ["quads", "glutes"], "bodyweight"),
    ("Renegade Row", ["back", "core"], "dumbbell"),
    ("Man Maker", ["chest", "back", "quads"], "dumbbell"),
    ("Sled Push", ["quads", "glutes"], "machine"),
    ("Sled Pull", ["back", "hamstrings"], "machine"),
    ("Battle Ropes", ["shoulders", "core"], "bodyweight"),

    # Cardio
    ("Treadmill Run", ["cardio"], "machine"),
    ("Running (Outdoor)", ["cardio"], "bodyweight"),
    ("Walking", ["cardio"], "bodyweight"),
    ("Incline Walk", ["cardio", "quads", "glutes"], "machine"),
    ("Cycling (Stationary)", ["cardio", "quads"], "machine"),
    ("Cycling (Outdoor)", ["cardio", "quads"], "bodyweight"),
    ("Assault Bike", ["cardio", "quads"], "machine"),
    ("Rowing Machine", ["cardio", "back"], "machine"),
    ("Ski Erg", ["cardio", "back", "shoulders"], "machine"),
    ("Jump Rope", ["cardio", "calves"], "bodyweight"),
    ("Stair Climber", ["cardio", "quads", "glutes"], "machine"),
    ("Elliptical", ["cardio"], "machine"),
    ("Swimming", ["cardio", "back", "shoulders"], "bodyweight"),
    ("Hiking", ["cardio", "quads", "glutes"], "bodyweight"),
]

# Tracking kind: which inputs a set of this exercise records.
# Mirrors `ExerciseTrackingKind` in ios/FitTrack/Models/Training.swift.
TIME_ONLY = {
    "Plank", "Side Plank", "Copenhagen Plank", "Dead Bug",
    "Battle Ropes", "Mountain Climber",
}
SPEED_INCLINE = {  # duration + speed + incline
    "Treadmill Run", "Incline Walk", "Stair Climber", "Elliptical",
}
DISTANCE = {  # duration + distance
    "Running (Outdoor)", "Walking", "Cycling (Stationary)", "Cycling (Outdoor)",
    "Assault Bike", "Rowing Machine", "Ski Erg", "Swimming", "Hiking",
    "Jump Rope", "Sled Push", "Sled Pull", "Farmer's Carry",
}


def kind_for(name: str, groups: list[str], equipment: str) -> str:
    if name in TIME_ONLY:
        return "timeOnly"
    if name in SPEED_INCLINE:
        return "cardioSpeedIncline"
    if name in DISTANCE:
        return "cardioDistance"
    if equipment == "bodyweight":
        return "bodyweightReps"
    return "weightReps"


out = [
    {
        "name": name,
        "muscleGroups": groups,
        "equipment": equipment,
        "kind": kind_for(name, groups, equipment),
    }
    for name, groups, equipment in EXERCISES
]

path = os.path.join("ios", "FitTrack", "Resources", "exercises.json")
with open(path, "w", encoding="utf-8") as f:
    json.dump(out, f, indent=2, ensure_ascii=False)

print(f"Wrote {len(out)} exercises to {path}")
