#!/usr/bin/env python3
"""Überträgt den Store-Eintrag (Texte, Vorstellungsgrafik, Handy- und
Tablet-Bildschirmfotos) über die Google-Play-Developer-API.

Quelle der Texte: docs/store-eintrag.md, Bilder: store/ (wie bei Wetter AW).
Das App-Symbol bleibt unangetastet (muss dem Symbol in der App entsprechen).
Dienstkonto `play-ci@notizblock-app-497918` – die Schlüsseldatei liegt unter
C:\\Users\\awurz\\Apps\\ und wird nie kopiert. Ersetzt die vorhandenen
Bildschirmfotos und die Vorstellungsgrafik vollständig.

  python scripts/play_listing.py --dry-run  # nur anzeigen, was übertragen würde
  python scripts/play_listing.py            # übertragen (geht danach bei Google in Prüfung)
"""
import argparse
import glob
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
KEYS = [
    os.path.join(ROOT, "android", "play-service-account.json"),
    r"C:\Users\awurz\Apps\notizblock-app-497918-8b46db648a55.json",
]
PACKAGE = "at.aw.notizblock"
LANG = "de-DE"


def read_listing():
    text = open(os.path.join(ROOT, "docs", "store-eintrag.md"), encoding="utf-8").read()

    def section(heading):
        return text.split(heading, 1)[1].split("\n## ", 1)[0]

    def line(heading):
        # eingerückte Zeile (4 Leerzeichen) unter der Überschrift
        return re.search(r"\n    (.+)\n", section(heading)).group(1).strip()

    def fenced(heading):
        return re.search(r"```\n(.*?)\n```", section(heading), re.S).group(1).strip()

    title = line("## App-Name")
    short = line("## Kurzbeschreibung")
    full = fenced("## Vollständige Beschreibung")
    assert len(title) <= 30, (len(title), title)
    assert len(short) <= 80, (len(short), short)
    assert len(full) <= 4000, len(full)
    return title, short, full


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()
    try:
        sys.stdout.reconfigure(errors="replace")
    except Exception:
        pass

    title, short, full = read_listing()
    phone = sorted(glob.glob(os.path.join(ROOT, "store", "telefon_*.png")))
    tablet = sorted(glob.glob(os.path.join(ROOT, "store", "tablet_*.png")))
    feature = os.path.join(ROOT, "store", "vorstellungsgrafik.png")
    print(f"Titel ({len(title)}): {title}\nKurz ({len(short)}): {short}\nLang: {len(full)} Zeichen")
    print(f"Grafik: {os.path.basename(feature)}\nHandy: {len(phone)}  Tablet (7\" + 10\"): {len(tablet)}")
    assert 2 <= len(phone) <= 8 and len(tablet) <= 8 and os.path.exists(feature)
    if args.dry_run:
        return

    key = next((k for k in KEYS if os.path.exists(k)), None)
    if key is None:
        sys.exit("Service-Account-JSON nicht gefunden")
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
    from googleapiclient.http import MediaFileUpload

    creds = service_account.Credentials.from_service_account_file(
        key, scopes=["https://www.googleapis.com/auth/androidpublisher"])
    edits = build("androidpublisher", "v3", credentials=creds, cache_discovery=False).edits()
    try:
        edit = edits.insert(packageName=PACKAGE, body={}).execute()["id"]
        edits.listings().update(packageName=PACKAGE, editId=edit, language=LANG, body={
            "language": LANG, "title": title, "shortDescription": short, "fullDescription": full,
        }).execute()
        print("Texte übertragen.")

        def upload(kind, path):
            edits.images().upload(packageName=PACKAGE, editId=edit, language=LANG, imageType=kind,
                                  media_body=MediaFileUpload(path, mimetype="image/png")).execute()
            print(f"  {kind}: {os.path.basename(path)}")

        for kind in ("featureGraphic", "phoneScreenshots", "sevenInchScreenshots", "tenInchScreenshots"):
            edits.images().deleteall(packageName=PACKAGE, editId=edit, language=LANG, imageType=kind).execute()
        upload("featureGraphic", feature)
        for s in phone:
            upload("phoneScreenshots", s)
        for s in tablet:
            upload("sevenInchScreenshots", s)
            upload("tenInchScreenshots", s)
        edits.commit(packageName=PACKAGE, editId=edit).execute()
        print("OK - Store-Eintrag gespeichert (Google prüft die Änderung, meist binnen Stunden).")
    except HttpError as e:
        sys.exit(f"\nPlay-API-Fehler:\n{e}")


if __name__ == "__main__":
    main()
