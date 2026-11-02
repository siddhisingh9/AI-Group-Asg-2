import re, sys
from pyperplan.pddl.parser import Parser
from pyperplan.grounding import ground

# usage: domain problem log section
dom, prob, log, section = sys.argv[1:5]
p = Parser(dom, prob)
task = ground(p.parse_problem(p.parse_domain()))
ops = {o.name: o for o in task.operators}

# extract plan from log
text = open(log).read().split(f"===== {prob} | {section} =====")[1].split("=====")[0]
steps = ["(" + m + ")" for m in re.findall(r"^([a-z-]+(?: \w+)+) \(1\)$", text, re.M)]

state = task.initial_state
for i, a in enumerate(steps, 1):
    op = ops[a]
    assert op.applicable(state), f"step {i} not applicable: {a}"
    state = op.apply(state)
    print(f"{i:2d}. {a}  OK")

print("\nFinal state:")
for f in sorted(state):
    if f.startswith(("(at ", "(rock-at", "(empty", "(in-bay", "(has-drill")):
        print("  ", f)
print("\nGoal satisfied:", task.goal_reached(state))
