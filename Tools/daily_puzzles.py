#!/usr/bin/env python3
"""Generate daily puzzles for Firebase Realtime Database.

Writes JSON shaped like the database: {"daily": {"2026": {"11": {"01": [...5 puzzles...]}}}}.
Each day has four easy answers from different categories, then one hard answer. Every answer is
used once before any repeats (about 7 months with the current list), then a new round starts. Import it in the Firebase console (Realtime Database ->
⋮ -> Import JSON) at the root, or paste one month under daily/<year>/<month>.

Only answer, category and level are written: the app fills in hints from its bundled puzzles.
To add a brand-new answer, give it "hints": ["cryptic", "clear"] too.

Usage: python3 Tools/daily_puzzles.py 2026-11 2027-12 > daily.json
"""
import calendar, json, random, sys
from pathlib import Path

PUZZLES = Path(__file__).resolve().parent.parent / "Vowelless/Vowelless/Resources/puzzles.json"


def months(start, end):
    y, m = map(int, start.split("-"))
    ey, em = map(int, end.split("-"))
    while (y, m) <= (ey, em):
        yield y, m
        y, m = (y + 1, 1) if m == 12 else (y, m + 1)


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    puzzles = json.loads(PUZZLES.read_text())
    rng = random.Random(f"{sys.argv[1]}..{sys.argv[2]}")
    everything = {level: [p for p in puzzles if p["level"] == level] for level in ("easy", "hard")}
    pools = {level: [] for level in everything}

    def take(level, avoid):
        for _ in range(2):
            pool = pools[level]
            for i, p in enumerate(pool):
                if p["category"] not in avoid:
                    return pool.pop(i)
            # This round is used up: start a new one.
            pool.extend(rng.sample(everything[level], len(everything[level])))
        sys.exit("Not enough categories to fill a day.")

    out = {}
    for y, m in months(sys.argv[1], sys.argv[2]):
        month = out.setdefault(str(y), {}).setdefault(f"{m:02d}", {})
        for d in range(1, calendar.monthrange(y, m)[1] + 1):
            day = []
            for _ in range(4):
                day.append(take("easy", {p["category"] for p in day}))
            day.append(take("hard", {p["category"] for p in day}))
            month[f"{d:02d}"] = [{"answer": p["answer"], "category": p["category"], "level": p["level"]} for p in day]
    json.dump({"daily": out}, sys.stdout, ensure_ascii=False, indent=1)
    print()


if __name__ == "__main__":
    main()
