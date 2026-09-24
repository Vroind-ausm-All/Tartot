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
.grule { font-size:24px; color:var(--blut); font-weight:700; text-align:center; margin:6px 24px 0; }
.dunkel-1 { background:#0d0c0e; } .dunkel-2 { background:#100b0c; } .dunkel-3 { background:#130a0a; }
.dunkel-4 { background:#160808; } .dunkel-5 { background:#1a0606; }
.platz.eingestuerzt { border-color:var(--blut); background:#1b0d0d; }
.platz.eingestuerzt .ptitel { color:var(--blut); }
.platz.verschoben { border-color:var(--indigo-hell); }
.karte.verdeckt { background:var(--indigo); border-color:var(--indigo-hell); color:var(--elfenbein); }
.karte.gezeichnet { border-color:var(--blut); border-width:5px; }
.kzeichen { font-size:18px; color:var(--elfenbein); background:var(--blut); font-weight:700; padding:0 8px; }
.kopfzeile { font-size:22px; color:var(--grau); text-align:center; letter-spacing:3px; margin-bottom:4px; }
.hinweis { font-size:24px; color:var(--ocker); text-align:center; min-height:30px; }
.vorschau.toedlich { color:var(--blut); font-weight:700; }
.dunkelwert { color:var(--blut); }
.pakt { border:3px solid var(--blut); background:#1b0d0d; padding:16px; margin-top:10px; }
.pakt .t { font-size:22px; text-align:center; line-height:1.35; }
.pakt .k { display:flex; gap:12px; margin-top:12px; }
.pakt .k div { flex:1; height:70px; display:flex; align-items:center; justify-content:center;
               font-size:26px; font-weight:700; border:3px solid var(--ocker); }
.pakt .ja { background:var(--blut); } .pakt .nein { background:var(--schwarz); }
.szenebild { height:300px; background:var(--schwarz); border:1px solid var(--grau); margin-bottom:24px;
             display:flex; align-items:center; justify-content:center; font-size:120px; color:var(--grau); }
.beat { font-size:30px; text-align:center; line-height:1.4; margin-bottom:16px; }
.beat.neu { color:var(--ocker-hell); }
.story { font-size:22px; color:var(--grau); text-align:center; font-style:italic; margin-bottom:18px; }
.oknopf.aus { opacity:.45; }
.abschnitt { font-size:24px; color:var(--ocker); font-weight:700; text-align:center; margin:22px 0 8px; letter-spacing:1px; }
.zeile { font-size:24px; text-align:center; line-height:1.35; }
.neu { font-size:24px; color:var(--ocker-hell); text-align:center; line-height:1.35; }
.beinahe { border:2px solid var(--ocker); padding:12px 16px; margin-top:10px; }
.beinahe .t { font-size:26px; font-weight:700; }
.beinahe .s { font-size:20px; color:var(--grau); margin-top:4px; line-height:1.3; }
.beinahe .b { height:8px; background:var(--schwarz); margin-top:8px; }
.beinahe .f { height:100%; background:var(--ocker); }
.marke { font-size:110px; font-weight:700; text-align:center; letter-spacing:22px; }
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
    size = " klein" if small else ""
    if card.get("veiled"):
        return (f'<div class="karte verdeckt{size}"><div class="kkopf">?</div>'
                f'<div class="ksym">☾</div><div class="krage"></div>'
                f'<div class="ktext">Im Mondlicht verborgen.</div></div>')
    classes = ["karte", card["suit"], "sh-" + card["shimmer"]]
    if small:
        classes.append("klein")
    if card.get("mark"):
        classes.append("gezeichnet")
    rage = f'<div class="krage">RAGE {card["rage"]}/3</div>' if card.get("rage") else '<div class="krage"></div>'
    sym_class = "ksym rev" if card.get("reversed") else "ksym"
    return (f'<div class="{" ".join(classes)}">'
            f'<div class="kkopf">{esc(card["head"])}</div>'
            f'<div class="{sym_class}">{SYMBOL.get(card["suit"], "?")}</div>'
            + (f'<div class="kzeichen">☠ {card["mark"]}</div>' if card.get("mark") else '')
            + f'{rage}'
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
        slot = d["slots"].get(key) or {}
        card = slot.get("card")
        cls = ["platz"]
        if card:
            cls.append("belegt")
        if slot.get("blocked"):
            cls.append("eingestuerzt")
        elif slot.get("hint"):
            cls.append("verschoben")
        slots += (f'<div class="{" ".join(cls)}"><div class="ptitel">{title}</div>'
                  f'<div class="pinhalt">{card_html(card, small=True)}</div>'
                  f'<div class="phinweis">{esc(slot.get("hint") or hint)}</div></div>')
    hand = "".join(card_html(c) for c in d["hand"])
    sigils = f'   ✦ {e["sigils"]} Siegel' if e["sigils"] else ""
    stance = ("HALTUNG GEBROCHEN — Schadensfenster offen" if e["stance"] <= 0
              else f'Haltung {e["stance"]} / {e["maxStance"]}')
    rule = f'<div class="grule">{esc(e["rule"])}</div>' if e.get("rule") else ""
    dark = f'<span class="wert dunkelwert">Dunkel {p["darkness"]}</span>' if p.get("darkness") else ""
    pact = ""
    if d.get("pact"):
        pact = (f'<div class="pakt"><div class="t">{esc(d["pact"])}</div>'
                '<div class="k"><div class="ja">UNTERSCHREIBEN</div><div class="nein">ABLEHNEN</div></div></div>')
    vclass = "vorschau toedlich" if d.get("lethal") else "vorschau"
    return f"""
<div class="kopfzeile">{esc(p["where"].upper())} · RUNDE {p["turn"]}</div>
<div class="gegner">
  <div class="silhouette"></div>
  <div class="gname">{esc(e["name"].upper())}</div>
  {rule}
  <div class="ghp">{esc(e.get("hpText", e["hp"]))} / {e["maxHp"]} HP{esc(sigils)}</div>
  {bar(e["hp"], e["maxHp"])}
  <div class="gstance">{esc(stance)}</div>
  {bar(e["stance"], max(1, e["maxStance"]), "haltung")}
  <div class="gintent">Nächster Zug: {esc(e["intent"])}</div>
</div>
<div class="leiste">
  <span class="wert">{p["hp"]} / {p["maxHp"]} HP</span>
  <span class="wert schild">{p["shield"]} Schild</span>
  <span class="wert fate">{p["fate"]} Fate · {p["gold"]} Gold</span>
  {dark}
</div>
{charms_html(d["charms"])}
<div class="legung">{slots}</div>
<div style="flex:1"></div>
<div class="{vclass}">{esc(d["preview"])}</div>
<div class="hinweis">{esc(d.get("hints", ""))}</div>
<div class="protokoll">{esc(d["log"][:150])}</div>
{pact}
<div class="hand">{hand}</div>
<div class="knopf">SCHICKSAL AUSFÜHREN</div>
{footer(d["caption"])}
"""


def options_html(d):
    section = ""
    if d.get("section"):
        section = (f'<div class="abschnitt">{esc(d["section"])}</div>'
                   f'<div class="zeile" style="margin-bottom:22px">{esc(d.get("sectionText", ""))}</div>')
    buttons = "".join(
        f'<div class="oknopf"><div class="t">{esc(o["title"])}</div>'
        f'<div class="s">{esc(o["text"][:140])}</div></div>' for o in d["options"])
    return f"""
<div class="overlay">
  <div class="otitel">{esc(d["title"])}</div>
  <div class="ountertitel">{esc(d["subtitle"]).replace(chr(10), "<br>")}</div>
  {section}
  {buttons}
</div>
{footer(d["caption"])}
"""


def event_html(d):
    beats = d["beats"]
    beat_html = "".join(
        f'<div class="beat{" neu" if i == len(beats) - 1 else ""}">{esc(b)}</div>' for i, b in enumerate(beats))
    story = '<div class="story">— eine Geschichte, die sich erinnert —</div>' if d.get("story") else ""
    choices = "".join(
        f'<div class="oknopf{"" if c["enabled"] else " aus"}"><div class="t">{esc(c["label"])}</div>'
        f'<div class="s">{esc(c["hint"])}</div></div>' for c in d["choices"])
    return f"""
<div class="overlay">
  <div class="otitel">{esc(d["title"])}</div>
  {story}
  <div class="szenebild">☗</div>
  {beat_html}
  <div style="height:18px"></div>
  {choices}
</div>
{footer(d["caption"])}
"""


def report_html(d):
    parts = []
    if d.get("best"):
        parts.append(f'<div class="zeile">{esc(d["best"])}</div>')
    if d["records"]:
        parts.append('<div class="abschnitt">REKORDE</div>')
        parts += [f'<div class="neu">{esc(r)}</div>' for r in d["records"]]
    if d["unlocked"]:
        parts.append('<div class="abschnitt">NEU FREIGESCHALTET</div>')
        parts += [f'<div class="neu">{esc(u)}</div>' for u in d["unlocked"]]
    if d["near"]:
        parts.append('<div class="abschnitt">BEINAHE</div>')
        for n in d["near"]:
            reward = f'<br>→ {esc(n["reward"])}' if n.get("reward") else ""
            pct = max(0, min(100, round(100 * n["progress"])))
            parts.append(f'<div class="beinahe"><div class="t">{esc(n["title"])}</div>'
                         f'<div class="s">{esc(n["detail"])}{reward}</div>'
                         f'<div class="b"><div class="f" style="width:{pct}%"></div></div></div>')
    return f"""
<div class="overlay">
  <div class="otitel">{esc(d["title"])}</div>
  <div class="ountertitel">{esc(d["subtitle"])}</div>
  {"".join(parts)}
  <div class="knopf" style="margin-top:34px">NOCH EINMAL</div>
  <div class="oknopf" style="margin-top:14px;text-align:center"><div class="t">ANDERE FIGUR, ANDERER SCHLEIER</div></div>
</div>
{footer(d["caption"])}
"""


def title_html(d):
    deuters = "".join(
        f'<div class="oknopf{"" if x["unlocked"] else " aus"}"><div class="t">{"▸ " if x["selected"] else ""}'
        f'{esc(x["name"])} — {esc(x["subtitle"])}</div><div class="s">{esc(x["text"])}</div></div>'
        for x in d["deuters"])
    return f"""
<div class="overlay">
  <div class="marke">TARTOT</div>
  <div class="ountertitel">{esc(d["subtitle"])}</div>
  <div class="abschnitt">DEUTER</div>
  {deuters}
  <div class="oknopf"><div class="t">{esc(d["veil"])}</div><div class="s">tippen zum Wechseln</div></div>
  <div class="knopf">RUN BEGINNEN</div>
  <div class="oknopf" style="margin-top:14px"><div class="t">{esc(d["daily"])}</div><div class="s">Für alle derselbe Seed.</div></div>
</div>
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
  <div class="ountertitel">VERGESSEN — {d["removalPrice"]} Gold je Karte · VEREDELN — {d.get("refinePrice", "?")} Gold · Karte antippen</div>
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
        body = {"combat": combat_html, "reward": reward_html, "options": options_html,
                "shop": shop_html, "event": event_html, "report": report_html,
                "title": title_html}[data["screen"]](data)
        dark = data.get("darkness", 0)
        body_class = f" class='dunkel-{dark}'" if dark else ""
        page = f"<!doctype html><meta charset='utf-8'><style>{CSS}</style><body{body_class}>{body}</body>"
        out = os.path.join(dst, name.replace(".json", ".html"))
        open(out, "w", encoding="utf-8").write(page)
        print("geschrieben:", out)


if __name__ == "__main__":
    main()
