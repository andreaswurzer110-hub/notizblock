#!/usr/bin/env python3
# Fasst eine FC_DEBUG=1-Ausgabe von fontconfig zusammen: wie viele Schrift-
# Abgleiche, wie viele Familiennamen pro Anfrage, für welche Zeichen eine
# Ersatzschrift gesucht wurde. Zeigt nur Zeichen-Codes, keine Notiztexte.
# Aufruf:
#   pkill -f 'notizblock --show-main'; sleep 1
#   FC_DEBUG=1 timeout 8 snap run notizblock-aw --show-main > /tmp/fcdebug.txt 2>&1
#   python3 scripts/fc_auswertung.py /tmp/fcdebug.txt
import re, sys, collections
text = open(sys.argv[1], errors="replace").read()
bloecke = re.findall(r"^(Match|Sort) Pattern has (\d+) elts.*?\n(.*?)\n\n", text, re.S | re.M)
gruppen, beispiele, gesucht = collections.Counter(), {}, collections.Counter()

def zeichen_aus(rumpf):
    # Gesuchte Zeichen aus der charset-Angabe der Anfrage (Seite: 8 x 32 Bit).
    out = []
    for seite, worte in re.findall(r"^\t([0-9a-f]{4}): ((?:[0-9a-f]{8} ?){8})$", rumpf, re.M):
        for i, w in enumerate(worte.split()):
            v = int(w, 16)
            out += [int(seite, 16) * 256 + i * 32 + b for b in range(32) if v >> b & 1]
    return out

for art, elts, rumpf in bloecke:
    fam = re.search(r"^\tfamily: (.*)$", rumpf, re.M)
    namen = re.findall(r'"([^"]*)"', fam.group(1)) if fam else []
    zeichen = "mit Zeichen" if re.search(r"^\tcharset:", rumpf, re.M) else "ohne Zeichen"
    if zeichen == "mit Zeichen":
        z = zeichen_aus(rumpf)
        if 0 < len(z) <= 3:
            gesucht.update(f"U+{c:04X}" for c in z)
    n = len(namen)
    stufe = "1" if n <= 1 else "2-20" if n <= 20 else "21-100" if n <= 100 else ">100"
    gruppen[(art, stufe, zeichen)] += 1
    beispiele.setdefault((art, stufe, zeichen), (namen[0] if namen else "-", n))
print(f"{len(bloecke)} Abgleiche insgesamt")
for (art, stufe, zeichen), n in sorted(gruppen.items(), key=lambda x: -x[1]):
    e = beispiele[(art, stufe, zeichen)]
    print(f"{art:6} {stufe:>7} Familien {zeichen:12} {n:>7}x  z.B. {e[0]} ({e[1]})")
if gesucht:
    print("Gesuchte Zeichen:", ", ".join(f"{k} x{n}" for k, n in gesucht.most_common(15)))
