import numpy as np
import pandas as pd
import networkx as nx
import matplotlib.pyplot as plt
from pgmpy.models import DiscreteBayesianNetwork
from pgmpy.factors.discrete import TabularCPD
from pgmpy.inference import VariableElimination
from pgmpy.estimators import MaximumLikelihoodEstimator, BayesianEstimator

TabularCPD._truncate_strtable = lambda self, t: t  # print full CPTs
SEED = 42
SIZES = [500, 5000, 20000]

STATES = {
    "Weather": ["Hot", "Mild", "Cold"],
    "DayType": ["Weekday", "Weekend"],
    "Occupancy": ["High", "Low"],
    "AC": ["On", "Off"],
    "ApplianceLoad": ["Heavy", "Light"],
    "Energy": ["High", "Low"],
}
EDGES = [("Weather", "AC"), ("DayType", "Occupancy"), ("Occupancy", "AC"),
         ("Occupancy", "ApplianceLoad"), ("AC", "Energy"), ("ApplianceLoad", "Energy")]

# ---------------- Part A ----------------
def build_expert():
    m = DiscreteBayesianNetwork(EDGES)
    cpd_w = TabularCPD("Weather", 3, [[0.5], [0.3], [0.2]], state_names=STATES)
    cpd_d = TabularCPD("DayType", 2, [[0.7], [0.3]], state_names=STATES)
    cpd_o = TabularCPD("Occupancy", 2, [[0.45, 0.80], [0.55, 0.20]],
                       evidence=["DayType"], evidence_card=[2], state_names=STATES)
    # Hot/Mild/Cold x High/Low
    on = [0.90, 0.60, 0.40, 0.15, 0.10, 0.05]
    cpd_a = TabularCPD("AC", 2, [on, [1 - p for p in on]],
                       evidence=["Weather", "Occupancy"], evidence_card=[3, 2], state_names=STATES)
    cpd_l = TabularCPD("ApplianceLoad", 2, [[0.75, 0.35], [0.25, 0.65]],
                       evidence=["Occupancy"], evidence_card=[2], state_names=STATES)
    # On/Off x Heavy/Light
    hi = [0.92, 0.68, 0.55, 0.12]
    cpd_e = TabularCPD("Energy", 2, [hi, [1 - p for p in hi]],
                       evidence=["AC", "ApplianceLoad"], evidence_card=[2, 2], state_names=STATES)
    m.add_cpds(cpd_w, cpd_d, cpd_o, cpd_a, cpd_l, cpd_e)
    return m


def verify_cpds(m):
    for cpd in m.get_cpds():
        sums = cpd.get_values().sum(axis=0)
        ok = np.allclose(sums, 1.0)
        print(f"{cpd.variable:14s} column sums={np.round(sums, 6)} -> {'OK' if ok else 'FAIL'}")
        assert ok
    print("model.check_model():", m.check_model())


def draw(m, fname="bn_structure.png"):
    g = nx.DiGraph(m.edges())
    pos = {"Weather": (0, 2), "DayType": (2, 3), "Occupancy": (2, 2),
           "AC": (1, 1), "ApplianceLoad": (3, 1), "Energy": (2, 0)}
    plt.figure(figsize=(8, 6))
    nx.draw(g, pos, with_labels=True, node_size=5200, node_color="lightblue",
            font_size=9, arrowsize=20, edgecolors="black")
    plt.title("Smart Home Energy Bayesian Network")
    plt.savefig(fname, dpi=150, bbox_inches="tight")
    plt.close()
    print("saved", fname)


QUERIES = {
    "Q1": ("Energy", "High", {}),
    "Q2": ("Energy", "High", {"Weather": "Hot"}),
    "Q3": ("Energy", "High", {"DayType": "Weekend"}),
    "Q4": ("Energy", "High", {"Weather": "Cold", "Occupancy": "High"}),
    "Q5": ("Weather", "Hot", {"Energy": "High"}),
    "Q6": ("AC", "On", {"Energy": "High"}),
    "Q7": ("AC", "On", {"Energy": "High", "ApplianceLoad": "Heavy"}),
}


def prob(infer, var, val, ev):
    f = infer.query([var], evidence=ev, show_progress=False)
    return float(f.get_value(**{var: val}))


def run_queries(m):
    inf = VariableElimination(m)
    return {q: prob(inf, *QUERIES[q]) for q in QUERIES}


def hand_q1():
    print("\nHand calculation of Q1")
    pO = 0.7 * 0.45 + 0.3 * 0.80
    print(f"P(O=High) = 0.7*0.45 + 0.3*0.80 = {pO:.4f};  P(O=Low) = {1 - pO:.4f}")
    pW = {"Hot": 0.5, "Mild": 0.3, "Cold": 0.2}
    acH = {"Hot": 0.9, "Mild": 0.4, "Cold": 0.1}
    acL = {"Hot": 0.6, "Mild": 0.15, "Cold": 0.05}
    pA = {"High": sum(pW[w] * acH[w] for w in pW), "Low": sum(pW[w] * acL[w] for w in pW)}
    print(f"P(A=On|O=High) = 0.5*0.9 + 0.3*0.4 + 0.2*0.1 = {pA['High']:.4f}")
    print(f"P(A=On|O=Low)  = 0.5*0.6 + 0.3*0.15 + 0.2*0.05 = {pA['Low']:.4f}")
    pL = {"High": 0.75, "Low": 0.35}
    pE = {("On", "Heavy"): 0.92, ("On", "Light"): 0.68, ("Off", "Heavy"): 0.55, ("Off", "Light"): 0.12}
    total = 0.0
    for o, po in [("High", pO), ("Low", 1 - pO)]:
        s = 0.0
        terms = []
        for a, pa in [("On", pA[o]), ("Off", 1 - pA[o])]:
            for l, pl in [("Heavy", pL[o]), ("Light", 1 - pL[o])]:
                t = pa * pl * pE[(a, l)]
                terms.append(f"{pa:.3f}*{pl:.2f}*{pE[(a, l)]:.2f}")
                s += t
        print(f"P(E=High|O={o}) = " + " + ".join(terms) + f" = {s:.6f}")
        total += po * s
    print(f"P(E=High) = {pO:.3f}*P(E=High|O=High) + {1 - pO:.3f}*P(E=High|O=Low) = {total:.6f}")
    return total


# ---------------- Part B ----------------
def part_b(m):
    inf = VariableElimination(m)
    print("\nPart B: numerical check")
    a = prob(inf, "Weather", "Hot", {})
    b = prob(inf, "Weather", "Hot", {"DayType": "Weekend"})
    print(f"1) P(W=Hot)={a:.6f}  P(W=Hot|D=Weekend)={b:.6f}  -> {'independent' if np.isclose(a, b) else 'dependent'}")
    a = prob(inf, "Weather", "Hot", {"Energy": "High"})
    b = prob(inf, "Weather", "Hot", {"Energy": "High", "DayType": "Weekend"})
    print(f"2) P(W=Hot|E=High)={a:.6f}  P(W=Hot|E=High,D=Weekend)={b:.6f}  -> {'independent' if np.isclose(a, b) else 'dependent'}")
    a = prob(inf, "Weather", "Hot", {"Occupancy": "High"})
    b = prob(inf, "Weather", "Hot", {"Occupancy": "High", "ApplianceLoad": "Heavy"})
    print(f"3) P(W=Hot|O=High)={a:.6f}  P(W=Hot|O=High,L=Heavy)={b:.6f}  -> {'independent' if np.isclose(a, b) else 'dependent'}")


# ---------------- Part C ----------------
def ancestral_sample(m, n, seed):
    rng = np.random.default_rng(seed)
    order = list(nx.topological_sort(nx.DiGraph(m.edges())))
    cpds = {c.variable: c for c in m.get_cpds()}
    rows = []
    for _ in range(n):
        s = {}
        for v in order:
            c = cpds[v]
            parents = c.variables[1:]
            # pick column for parents
            idx = tuple(c.name_to_no[p][s[p]] for p in parents)
            p = c.get_values().reshape([c.cardinality[0]] + list(c.cardinality[1:]))[(slice(None),) + idx]
            s[v] = c.state_names[v][rng.choice(len(p), p=p)]
        rows.append(s)
    return pd.DataFrame(rows)[list(STATES)]


def part_c(m):
    print("\nPart C: synthetic data (seed =", SEED, ")")
    print("Topological order:", list(nx.topological_sort(nx.DiGraph(m.edges()))))
    data = {}
    for n in SIZES:
        df = ancestral_sample(m, n, SEED)
        data[n] = df
        df.to_csv(f"data_{n}.csv", index=False)
        print(f"\n--- n = {n} ---")
        print("Weather frequency:")
        print(df["Weather"].value_counts(normalize=True).reindex(STATES["Weather"]).round(4).to_string())
        print("(Weather, Occupancy) counts:")
        ct = df.groupby(["Weather", "Occupancy"]).size().reindex(
            pd.MultiIndex.from_product([STATES["Weather"], STATES["Occupancy"]]), fill_value=0)
        print(ct.to_string())
    return data


# ---------------- Part D ----------------
def learn(df, est):
    m = DiscreteBayesianNetwork(EDGES)
    if est == "MLE":
        cpds = MaximumLikelihoodEstimator(m, df, state_names=STATES).get_parameters()
    else:
        cpds = BayesianEstimator(m, df, state_names=STATES).get_parameters(
            prior_type="BDeu", equivalent_sample_size=10)
    m.add_cpds(*cpds)
    return m


def ac_table(models):
    cols = pd.MultiIndex.from_product([STATES["Weather"], STATES["Occupancy"]], names=["Weather", "Occupancy"])
    out = {}
    for name, m in models.items():
        c = m.get_cpds("AC")
        out[name] = pd.Series([c.get_value(AC="On", Weather=w, Occupancy=o) for w, o in cols], index=cols)
    return pd.DataFrame(out).round(4)


def part_d_e(expert, data):
    exp_q = run_queries(expert)
    mean_diff = {"MLE": [], "Bayesian": []}
    results = {}
    for n, df in data.items():
        mle, bay = learn(df, "MLE"), learn(df, "Bayes")
        print(f"\n===== Part D: n = {n} =====")
        print("P(AC=On | Weather, Occupancy):")
        print(ac_table({"Expert": expert, "MLE": mle, "Bayesian": bay}).to_string())
        mq, bq = run_queries(mle), run_queries(bay)
        tab = pd.DataFrame({
            "Expert Model": exp_q, "MLE Model": mq, "Bayesian Model": bq,
            "|Diff| MLE": {q: abs(mq[q] - exp_q[q]) for q in QUERIES},
            "|Diff| Bayesian": {q: abs(bq[q] - exp_q[q]) for q in QUERIES},
        }).round(4)
        tab.index.name = "Query"
        print(f"\n===== Part E: comparison, n = {n} =====")
        print(tab.to_string())
        mean_diff["MLE"].append(tab["|Diff| MLE"].mean())
        mean_diff["Bayesian"].append(tab["|Diff| Bayesian"].mean())
        results[n] = tab

    print("\nMean |Diff| over Q1-Q7:")
    print(pd.DataFrame(mean_diff, index=SIZES).round(5).to_string())

    plt.figure(figsize=(7, 5))
    plt.plot(SIZES, mean_diff["MLE"], "o-", label="MLE")
    plt.plot(SIZES, mean_diff["Bayesian"], "s-", label="Bayesian (BDeu, ESS=10)")
    plt.xscale("log")
    plt.xlabel("Dataset size")
    plt.ylabel("Mean |Diff| over Q1-Q7")
    plt.title("Learned vs Expert: Mean Absolute Difference")
    plt.legend(); plt.grid(True, alpha=0.3)
    plt.savefig("mean_abs_diff.png", dpi=150, bbox_inches="tight")
    plt.close()
    print("saved mean_abs_diff.png")

    t = results[500]
    worst = t[["|Diff| MLE", "|Diff| Bayesian"]].max(axis=1).idxmax()
    print(f"\nLargest error at n=500: {worst}")
    df = data[500]
    for q, (_, _, ev) in QUERIES.items():
        cnt = len(df) if not ev else int((df[list(ev)] == pd.Series(ev)).all(axis=1).sum())
        print(f"  {q}: evidence rows in data = {cnt}")


if __name__ == "__main__":
    expert = build_expert()
    print("Part A: CPT verification")
    verify_cpds(expert)
    for c in expert.get_cpds():
        print(c)
    draw(expert)
    print("\nPart A: expert queries")
    eq = run_queries(expert)
    for q, v in eq.items():
        print(f"{q}: {v:.6f}")
    h = hand_q1()
    print(f"Code Q1 = {eq['Q1']:.6f}, hand Q1 = {h:.6f}, match = {np.isclose(h, eq['Q1'])}")
    part_b(expert)
    data = part_c(expert)
    part_d_e(expert, data)
