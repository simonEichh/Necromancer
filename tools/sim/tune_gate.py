"""python tools/sim/tune_gate.py WALLS HPMULT [runs]  -- pace table of the gate preset with a different wall count / gate HP."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import economy_sim as s
walls, mult = int(sys.argv[1]), float(sys.argv[2])
for a in sys.argv[4:]:
    k, v = a.split("=")
    {"HP": s.HP_STEP, "GOLD": s.GOLD_STEP}[k][:] = [float(x) for x in v.split(",")]
rules = dict(s.PRESETS["gate"], gate=dict(walls=walls, hp_mult=mult))
runs = [s.run(rules, 1 + i, 800) for i in range(int(sys.argv[3]) if len(sys.argv) > 3 else 5)]
s.report(runs, f"gate walls={walls} gate_hp x{mult}", 2.0)
