#!/usr/bin/env python3
"""progress/log.py "<message>" [piece_id status] — append to the activity log and optionally set a piece's status."""
import json, os, sys, time
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, "progress/state.json")
S = json.load(open(P))
S["log"].append({"t": time.strftime("%H:%M"), "msg": sys.argv[1]})
if len(sys.argv) >= 4:
    for p in S["pieces"]:
        if p["id"] == sys.argv[2]:
            p["status"] = sys.argv[3]
json.dump(S, open(P, "w"), indent=2)
