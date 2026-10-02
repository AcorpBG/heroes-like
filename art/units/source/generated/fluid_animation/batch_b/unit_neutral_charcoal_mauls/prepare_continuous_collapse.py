"""Second collapse correction: remove incompatible imposed plateau guides."""
import prepare as q
import produce as p

if __name__ == '__main__':
    q.config('death', [q.ref(13), q.ref(12)], [], 1,
        'A single uninterrupted five-second physical collapse from upright ready to the supplied grounded corpse. Start bending knees immediately. Hips progressively descend, shoulders sag and both hands continuously lower the SAME maul. Knees touch ground then the man loses balance onto his LEFT side, rolls gently and extends his legs rightward. His head and shoulder settle onto the ground, maul rests flat beside his hands. Do not pause in kneeling or sitting stages: continuously change the hips, knees, elbows and torso through the entire descent. Show all intermediate positions, slow real weight transfer and deceleration at the floor. Never teleport between standing, kneeling, sitting and prone. Original adult proportions and two arms/two legs; same clothes, original maul and correct grips until settled. Last half-second is a motionless grounded corpse. No effects, falling objects, camera motion or stand-up.',
        2026102110, 'v3')
    p.write(p.SOURCE_DIR/'death_h3_v3'/'correction_reason.json', {
        'defect': 'Earlier intermediate guide conditioning held each posture then jumped between knee, seated and reclined states.',
        'control_change': 'Keep only original ready and original terminal corpse, remove all intermediate hard guide plateaus; request uninterrupted descent.',
        'acceptance': 'Review every observed frame and native timing; no generated-count acceptance or synthetic transitions.'})
