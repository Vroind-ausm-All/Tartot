#!/usr/bin/env python3
"""Vergleicht eine C#-Spur mit einer GDScript-Spur (siehe tools/paritaet.sh).

Zeilen S/T/E muessen exakt gleich sein. Die J-Zeile (Speicherstand am Ende)
wird als JSON verglichen: Karten-Instanz-Ids sind in C# Guids und im Port
Zaehler - sie werden ueber ihre Position im Kartenpool angeglichen. Zahlen
werden als Zahlen verglichen (1 == 1.0).
"""
import json
import sys


def lines(path):
    with open(path, encoding="utf-8") as f:
        return [l.rstrip("\n") for l in f if l[:2] in ("S ", "T ", "E ", "J ", "R ", "M ")]


def canon_save(text):
    root = json.loads(text)
    ids = {c["id"]: f"karte{i}" for i, c in enumerate(root.get("cards", []))}

    def walk(x):
        if isinstance(x, dict):
            out = {k: walk(v) for k, v in x.items()}
            # Mengen, die nach Instanz-Id sortiert gespeichert werden: Guid und
            # Zaehler sortieren verschieden - als Menge vergleichen.
            if isinstance(out.get("veiled"), list):
                out["veiled"] = sorted(out["veiled"])
            return out
        if isinstance(x, list):
            return [walk(v) for v in x]
        if isinstance(x, str) and x in ids:
            return ids[x]
        if isinstance(x, bool) or x is None:
            return x
        if isinstance(x, (int, float)):
            return float(x)
        return x

    return walk(root)


def first_diff(a, b, path="$"):
    if type(a) != type(b):
        return f"{path}: {a!r} != {b!r}"
    if isinstance(a, dict):
        for k in sorted(set(a) | set(b)):
            if k not in a or k not in b:
                return f"{path}.{k}: fehlt auf einer Seite"
            d = first_diff(a[k], b[k], f"{path}.{k}")
            if d:
                return d
        return None
    if isinstance(a, list):
        if len(a) != len(b):
            return f"{path}: Laenge {len(a)} != {len(b)}"
        for i, (x, y) in enumerate(zip(a, b)):
            d = first_diff(x, y, f"{path}[{i}]")
            if d:
                return d
        return None
    return None if a == b else f"{path}: {a!r} != {b!r}"


def main():
    cs, gd = lines(sys.argv[1]), lines(sys.argv[2])
    for i, (a, b) in enumerate(zip(cs, gd)):
        if a[:2] in ("J ", "M ") and a[:2] == b[:2]:
            d = first_diff(canon_save(a[2:]), canon_save(b[2:]))
            if d:
                print(f"Zeile {i + 1} ({'Speicherstand' if a[0] == 'J' else 'Meta-Fortschritt'}): {d}")
                return 1
            continue
        if a != b:
            print(f"Zeile {i + 1} weicht ab.")
            wa, wb = a.split(" "), b.split(" ")
            for x, y in zip(wa, wb):
                if x != y:
                    print(f"  C#:     {x[:300]}")
                    print(f"  Godot:  {y[:300]}")
                    break
            print(f"  C#-Zeile:    {a[:400]}")
            print(f"  Godot-Zeile: {b[:400]}")
            return 1
    if len(cs) != len(gd):
        print(f"Unterschiedliche Laenge: C# {len(cs)} Zeilen, Godot {len(gd)} Zeilen.")
        return 1
    if not cs:
        print("Leere Spur.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
