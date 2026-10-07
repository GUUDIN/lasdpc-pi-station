#!/usr/bin/env python3
"""Garante no rc.xml do labwc (do proprio sistema) so o que a estacao precisa:
o atalho Super+Esc -> menu e as regras de janela dos apps. Mantem tema, fontes e
o resto como o Raspberry Pi OS definiu (Bookworm e Trixie usam temas diferentes).
Uso: labwc_patch.py /etc/xdg/labwc/rc.xml   (sai 0 se mudou, 1 se ja estava ok)"""
import sys, xml.etree.ElementTree as ET

NS = "http://openbox.org/3.4/rc"
ET.register_namespace("", NS)
q = lambda t: f"{{{NS}}}{t}"

KEYBIND = ("W-Escape", "lasdpc-mode menu")
RULES = [
    # tela de carregamento (fallback Chromium) sempre por cima
    {"attrs": {"title": "Carregando*"}, "actions": ["ToggleFullscreen", "ToggleAlwaysOnTop", "Focus", "Raise"],
     "extra": {"skipTaskbar": "yes", "skipWindowSwitcher": "yes"}},
    # RetroArch abre em janela (video_fullscreen=false) e o labwc poe em tela cheia
    {"attrs": {"identifier": "com.libretro.RetroArch", "serverDecoration": "no"}, "actions": ["ToggleFullscreen"]},
    {"attrs": {"identifier": "Kodi", "serverDecoration": "yes"}, "actions": []},
]

def main(path):
    tree = ET.parse(path); root = tree.getroot(); changed = False
    kb_parent = root.find(q("keyboard"))
    if kb_parent is None:
        kb_parent = ET.SubElement(root, q("keyboard")); changed = True
    if not any(k.get("key") == KEYBIND[0] for k in kb_parent.findall(q("keybind"))):
        kb = ET.SubElement(kb_parent, q("keybind"), {"key": KEYBIND[0]})
        a = ET.SubElement(kb, q("action"), {"name": "Execute"})
        ET.SubElement(a, q("command")).text = KEYBIND[1]
        changed = True
    rules = root.find(q("windowRules"))
    if rules is None:
        rules = ET.SubElement(root, q("windowRules")); changed = True
    for r in RULES:
        key = next(iter(r["attrs"].items()))
        if any(w.get(key[0]) == key[1] for w in rules.findall(q("windowRule"))):
            continue
        w = ET.SubElement(rules, q("windowRule"), r["attrs"])
        for k, v in r.get("extra", {}).items():
            ET.SubElement(w, q(k)).text = v
        for act in r["actions"]:
            ET.SubElement(w, q("action"), {"name": act})
        changed = True
    if changed:
        ET.indent(tree, "  ")
        tree.write(path, encoding="UTF-8", xml_declaration=True)
    return 0 if changed else 1

if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
