#!/usr/bin/env python3
"""Zeichnet die aus dem Regelkern abgezogenen Zustaende als HTML.

WICHTIG: Das ist kein Unity-Render. Die Zahlen und Karten stammen aus dem
echten Kern (src/Tartot.Sim -- --snapshot=...), die Gestaltung bildet
unity/Assets/Resources/Tartot/Tartot.uss nach. Schriftart, Abstaende und
Theme koennen in Unity abweichen. Zweck ist ein erster Eindruck ohne
Unity-Installation.

    dotnet run --project src/Tartot.Sim -c Release -- --snapshot=/tmp/tartot_state
    python3 tools/screenshots/render.py /tmp/tartot_state /tmp/tartot_html
"""
import html
import json
import os
import sys

# Palette "Occult Clean" - dieselben Werte wie in Tartot.uss.
CSS = """
* { margin:0; padding:0; box-sizing:border-box; }
:root {
  --schwarz:#161616; --tief:#0e0e10; --elfenbein:#f2ecdd; --papier:#e4dcc6;
  --grau:#6b6659; --indigo:#2e3a67; --indigo-hell:#4a5a96;
  --ocker:#c89b3c; --ocker-hell:#e3bc63; --blut:#8e2b2b;
}
body { width:1080px; height:1920px; background:var(--tief); color:var(--elfenbein);
       font-family:"DejaVu Sans","Noto Sans",sans-serif; padding:32px;
       display:flex; flex-direction:column; }

/* ---- Gegner ---- */
.gegner { display:flex; flex-direction:column; align-items:center; padding-bottom:14px; }
.silhouette { width:260px; height:260px; background:var(--elfenbein);
              clip-path:polygon(50% 0%, 18% 100%, 82% 100%); margin-bottom:12px; }
.gname { font-size:44px; font-weight:700; letter-spacing:1px; text-align:center; }
.ghp { font-size:36px; color:var(--blut); margin-top:6px; }
.gstance { font-size:26px; color:var(--indigo-hell); margin-top:8px; }
.gintent { font-size:32px; color:var(--ocker); margin-top:10px; }
.balken { height:10px; width:72%; background:var(--schwarz); margin-top:6px; }
.fuell { height:100%; background:var(--blut); }
.fuell.haltung { background:var(--indigo-hell); }

/* ---- Leisten ---- */
.leiste { display:flex; justify-content:space-between; align-items:center;
          padding:12px 0; border-top:1px solid var(--grau); border-bottom:1px solid var(--grau); }
.wert { font-size:28px; }
.schild { color:var(--indigo-hell); } .fate { color:var(--ocker); } .matt { color:var(--grau); }
.charmleiste { display:flex; flex-wrap:wrap; gap:14px; padding:12px 0; min-height:46px; }
.charm { font-size:22px; color:var(--ocker); border:1px solid var(--grau); padding:3px 8px; }

/* ---- Legung ---- */
.legung { display:flex; gap:14px; margin-top:18px; }
.platz { flex:1; border:2px solid var(--grau); display:flex; flex-direction:column;
         align-items:center; padding:12px 6px; gap:10px; min-height:300px; }
.platz.belegt { border-color:var(--ocker); }
.ptitel { font-size:22px; color:var(--ocker); font-weight:700; letter-spacing:1px; }
.phinweis { font-size:18px; color:var(--grau); margin-top:auto; text-align:center; }
.pinhalt { display:flex; align-items:flex-start; justify-content:center; }

/* ---- Karten ---- */
.karte { width:184px; height:264px; background:var(--papier); border:3px solid var(--grau);
         display:flex; flex-direction:column; align-items:center; justify-content:space-between;
         padding:10px 6px; color:var(--schwarz); }
.karte.klein { width:150px; height:216px; }
.karte.Swords { border-color:var(--blut); } .karte.Wands { border-color:var(--ocker); }
.karte.Cups { border-color:var(--indigo-hell); } .karte.Pentacles { border-color:var(--indigo); }
.karte.Major { border-color:var(--ocker-hell); background:var(--schwarz); color:var(--elfenbein); }
.sh-White{background:#d8d0ba;} .sh-Indigo{background:#a8a493;}
.sh-Gold{background:#7c765f;color:var(--elfenbein);}
.sh-Blood{background:#4a3230;color:var(--elfenbein);}
.sh-Black{background:#201c1c;color:var(--elfenbein);}
.kkopf { font-size:30px; font-weight:700; }
.ksym { font-size:64px; line-height:1; }
.ksym.rev { transform:rotate(180deg); }
.ktext { font-size:14px; text-align:center; line-height:1.2; overflow:hidden;
          display:-webkit-box; -webkit-line-clamp:4; -webkit-box-orient:vertical; }
.krage { font-size:15px; color:var(--blut); font-weight:700; }

.hand { display:flex; justify-content:center; gap:10px; flex-wrap:wrap; margin-top:14px; }
.vorschau { font-size:30px; color:var(--ocker-hell); text-align:center; margin:14px 0; min-height:36px; }
.protokoll { font-size:22px; color:var(--grau); text-align:center; min-height:34px; }
.knopf { height:96px; background:var(--ocker); color:var(--schwarz); font-size:36px; font-weight:700;
         border:3px solid var(--ocker-hell); border-radius:4px; display:flex;
         align-items:center; justify-content:center; letter-spacing:1px; margin-top:14px; }

/* ---- Overlay ---- */
.overlay { flex:1; display:flex; flex-direction:column; justify-content:center; }
.otitel { font-size:52px; font-weight:700; text-align:center; letter-spacing:1px; }
.ountertitel { font-size:26px; color:var(--grau); text-align:center; margin:12px 0 28px; }
.oknopf { background:var(--schwarz); border:3px solid var(--ocker); border-radius:4px;
          padding:22px; margin-bottom:16px; }
.oknopf .t { font-size:32px; font-weight:700; }
.oknopf .s { font-size:22px; color:var(--grau); margin-top:6px; line-height:1.3; }
.oreihe { display:flex; flex-wrap:wrap; gap:10px; justify-content:center; margin-bottom:20px; }
.fussnote { font-size:20px; color:var(--grau); text-align:center; margin-top:auto; padding-top:16px;
            border-top:1px solid var(--grau); }
"""

SYMBOL = {"Swords": "⚔", "Wands": "✸", "Cups": "♥",
          "Pentacles": "◆", "Major": "★"}
SLOT_LABEL = [("Past", "VERGANGENHEIT", "90 % — Vorbereitung"),
              ("Present", "GEGENWART", "100 % — sicher"),
              ("Future", "ZUKUNFT", "150 % — nach dem Gegner")]


def esc(text):
    return html.escape(str(text))


def card_html(card, small=False):
    if not card:
        return ""
    classes = ["karte", card["suit"], "sh-" + card["shimmer"]]
    if small:
        classes.append("klein")
    rage = f'<div class="krage">RAGE {card["rage"]}/3</div>' if card.get("rage") else '<div class="krage"></div>'
    sym_class = "ksym rev" if card.get("reversed") else "ksym"
    return (f'<div class="{" ".join(classes)}">'
            f'<div class="kkopf">{esc(card["head"])}</div>'
            f'<div class="{sym_class}">{SYMBOL.get(card["suit"], "?")}</div>'
            f'{rage}'
            f'<div class="ktext">{esc(card["text"][:46])}</div>'
            f'</div>')


def bar(value, maximum, extra=""):
    pct = 0 if not maximum else max(0, min(100, round(100 * value / maximum)))
    return f'<div class="balken"><div class="fuell {extra}" style="width:{pct}%"></div></div>'


def charms_html(charms):
    if not charms:
        return '<div class="charmleiste"></div>'
    chips = "".join(f'<span class="charm">{esc(c["name"])} ×{c["count"]}</span>' for c in charms)
    return f'<div class="charmleiste">{chips}</div>'


def footer(caption):
    return (f'<div class="fussnote">{esc(caption)} · '
            'Gestaltung nach Tartot.uss, Zahlen aus dem Regelkern — kein Unity-Render.</div>')


def combat_html(d):
    e, p = d["enemy"], d["player"]
    slots = ""
    for key, title, hint in SLOT_LABEL:
        card = d["slots"].get(key)
        cls = "platz belegt" if card else "platz"
        slots += (f'<div class="{cls}"><div class="ptitel">{title}</div>'
                  f'<div class="pinhalt">{card_html(card, small=True)}</div>'
                  f'<div class="phinweis">{esc(hint)}</div></div>')
    hand = "".join(card_html(c) for c in d["hand"])
    sigils = f'   ✦ {e["sigils"]} Siegel' if e["sigils"] else ""
    stance = ("HALTUNG GEBROCHEN — Schadensfenster offen" if e["stance"] <= 0
              else f'Haltung {e["stance"]} / {e["maxStance"]}')
    return f"""
<div class="gegner">
  <div class="silhouette"></div>
  <div class="gname">{esc(e["name"].upper())}</div>
  <div class="ghp">{e["hp"]} / {e["maxHp"]} HP{esc(sigils)}</div>
  {bar(e["hp"], e["maxHp"])}
  <div class="gstance">{esc(stance)}</div>
  {bar(e["stance"], max(1, e["maxStance"]), "haltung")}
  <div class="gintent">Nächster Zug: {esc(e["intent"])}</div>
</div>
<div class="leiste">
  <span class="wert">{p["hp"]} / {p["maxHp"]} HP</span>
  <span class="wert schild">{p["shield"]} Schild</span>
  <span class="wert fate">{p["fate"]} Fate</span>
  <span class="wert matt">Luck {p["luck"]}</span>
  <span class="wert matt">Kampf {p["fight"]} · Runde {p["turn"]}</span>
</div>
{charms_html(d["charms"])}
<div class="legung">{slots}</div>
<div style="flex:1"></div>
<div class="vorschau">{esc(d["preview"])}</div>
<div class="protokoll">{esc(d["log"][:150])}</div>
<div class="hand">{hand}</div>
<div class="knopf">SCHICKSAL AUSFÜHREN</div>
{footer(d["caption"])}
"""


def reward_html(d):
    buttons = "".join(
        f'<div class="oknopf"><div class="t">{esc(o["title"])}</div>'
        f'<div class="s">{esc(o["text"][:110])}</div></div>' for o in d["options"])
    return f"""
<div class="overlay">
  <div class="otitel">{esc(d["title"])}</div>
  <div class="ountertitel">{esc(d["subtitle"])}</div>
  {buttons}
  <div class="oknopf"><div class="t">ÜBERSPRINGEN</div>
    <div class="s">Fate statt Karte — dein Deck bleibt dünn.</div></div>
</div>
{footer(d["caption"])}
"""


def shop_html(d):
    offers = "".join(
        f'<div class="oknopf"><div class="t">{esc(o["title"])} — {o["price"]} Gold</div>'
        f'<div class="s">{esc(o["text"][:100])}</div></div>' for o in d["offers"])
    deck = "".join(card_html(c, small=True) for c in d["deck"][:10])
    return f"""
<div class="overlay">
  <div class="otitel">{esc(d["title"])}</div>
  <div class="ountertitel">{esc(d["subtitle"])}</div>
  {offers}
  <div class="ountertitel">VERGESSEN — {d["removalPrice"]} Gold je Karte · Karte antippen</div>
  <div class="oreihe">{deck}</div>
</div>
{footer(d["caption"])}
"""


def main():
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    for name in sorted(os.listdir(src)):
        if not name.endswith(".json"):
            continue
        data = json.load(open(os.path.join(src, name), encoding="utf-8"))
        body = {"combat": combat_html, "reward": reward_html,
                "shop": shop_html}[data["screen"]](data)
        page = f"<!doctype html><meta charset='utf-8'><style>{CSS}</style>{body}"
        out = os.path.join(dst, name.replace(".json", ".html"))
        open(out, "w", encoding="utf-8").write(page)
        print("geschrieben:", out)


if __name__ == "__main__":
    main()
