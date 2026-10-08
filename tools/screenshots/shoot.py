#!/usr/bin/env python3
"""Fotografiert die gerenderten HTML-Seiten mit dem vorinstallierten Chromium.

    python3 tools/screenshots/shoot.py /tmp/tartot_html /tmp/tartot_shots
"""
import os
import sys
from playwright.sync_api import sync_playwright

WIDTH, HEIGHT = 1080, 1920


def main():
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    with sync_playwright() as p:
        # Der vorinstallierte Chromium der Umgebung. Playwright laedt sonst
        # eine eigene Kopie herunter, die hier nicht noetig ist.
        preinstalled = "/opt/pw-browsers/chromium"
        browser = (p.chromium.launch(executable_path=preinstalled)
                   if os.path.exists(preinstalled) else p.chromium.launch())
        page = browser.new_page(viewport={"width": WIDTH, "height": HEIGHT},
                                device_scale_factor=1)
        for name in sorted(os.listdir(src)):
            if not name.endswith(".html"):
                continue
            page.goto("file://" + os.path.abspath(os.path.join(src, name)))
            page.wait_for_timeout(250)
            out = os.path.join(dst, name.replace(".html", ".png"))
            page.screenshot(path=out)
            print("fotografiert:", out)
        browser.close()


if __name__ == "__main__":
    main()
