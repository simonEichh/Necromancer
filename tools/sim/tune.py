"""Quick tuning helper: python tools/sim/tune.py "HP=3.5,3.5,..." "GOLD=..." "COST=..." """
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import economy_sim as s
for a in sys.argv[1:]:
    k, v = a.split("=")
    vals = [float(x) for x in v.split(",")]
    {"HP": s.HP_STEP, "GOLD": s.GOLD_STEP, "COST": s.COST_STEP}[k][:] = vals
runs = [s.run(s.PRESETS["proposed"], 1 + i, 800) for i in range(5)]
s.report(runs, "proposed", 2.0)
