#!/usr/bin/env python3
# Startet Notizblock AW und zeigt, welcher Thread wann wie viel CPU braucht.
# Aufruf:  python3 linux_threads_messen.py [Sekunden] [Befehl ...]
# Standard: 8 Sekunden, Befehl "snap run notizblock-aw --show-main".
import os, subprocess, sys, time

dauer = float(sys.argv[1]) if len(sys.argv) > 1 else 8.0
befehl = sys.argv[2:] or ["snap", "run", "notizblock-aw", "--show-main"]
TICK_MS = 1000.0 / os.sysconf("SC_CLK_TCK")
FENSTER = 0.25  # Sekunden pro Zeile
LOG = "/tmp/nb_threads_app.log"

def threads(pid):
    out = {}
    try:
        tids = os.listdir(f"/proc/{pid}/task")
    except OSError:
        return out
    for tid in map(int, tids):
        try:
            with open(f"/proc/{pid}/task/{tid}/stat") as f:
                s = f.read()
        except OSError:
            continue
        name = s[s.index("(") + 1:s.rindex(")")]
        felder = s[s.rindex(")") + 2:].split()
        out[tid] = (name, int(felder[11]) + int(felder[12]))
    return out

def alle_pids(wurzel):
    pids, offen = [], [wurzel]
    while offen:
        p = offen.pop()
        pids.append(p)
        try:
            with open(f"/proc/{p}/task/{p}/children") as f:
                offen += [int(x) for x in f.read().split()]
        except OSError:
            pass
    return pids

with open(LOG, "w") as log:
    proc = subprocess.Popen(befehl, stdout=log, stderr=log)
t0 = time.monotonic()
cpu_ms, namen, letzte = {}, {}, {}
while time.monotonic() - t0 < dauer:
    zeile = int((time.monotonic() - t0) / FENSTER)
    for pid in alle_pids(proc.pid):
        for tid, (name, cpu) in threads(pid).items():
            key = (pid, tid)
            namen[key] = name
            if key in letzte and cpu > letzte[key]:
                cpu_ms.setdefault(key, {}).setdefault(zeile, 0)
                cpu_ms[key][zeile] += (cpu - letzte[key]) * TICK_MS
            letzte[key] = cpu
    time.sleep(0.02)
proc.terminate()

top = sorted(cpu_ms, key=lambda k: -sum(cpu_ms[k].values()))[:6]
def kurz(k):
    return ("*" if k[0] == k[1] else "") + namen[k][:11]
print("CPU-Zeit in ms je Thread und Viertelsekunde (* = Hauptthread: GTK + Dart)")
print("  Zeit |" + "".join(f"{kurz(k):>13}" for k in top))
for z in range(int(dauer / FENSTER)):
    werte = [cpu_ms[k].get(z, 0) for k in top]
    print(f"{z*FENSTER:5.2f}s |" + "".join(f"{int(w):>13}" if w else f"{'.':>13}" for w in werte))
print("Summe  |" + "".join(f"{int(sum(cpu_ms[k].values())):>13}" for k in top))
with open(LOG) as f:
    warn = [l.strip() for l in f if "Timed out" in l or "CRITICAL" in l]
for w in warn[:5]:
    print("App:", w)
