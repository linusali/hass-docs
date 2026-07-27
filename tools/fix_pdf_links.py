#!/usr/bin/env python3
"""Rewrite an Asciidoctor-generated HTML file's internal hrefs to absolute
GitHub URLs, in place, before it's fed to a PDF renderer.

Why: `link:` targets in the .adoc sources are relative paths meant for
browsing the repo (on GitHub or a checkout). Asciidoctor passes them through
to the HTML verbatim. A PDF built from that HTML and shared standalone (e.g.
on WhatsApp) has no repo context, so those relative hrefs resolve to
meaningless local paths. This rewrites anything that isn't already an
absolute http(s)/mailto URL or a same-page "#anchor" into a
github.com/<repo>/blob|tree/<branch>/<path> URL, resolved relative to the
source .adoc file's own location in the repo.

Usage: fix_pdf_links.py <html_path> <source_repo_relative_adoc_path>
Example: fix_pdf_links.py /tmp/out.html phases/phase-4/guide-simple.adoc

Same-page anchors (table of contents, etc.) are left untouched.
See tools/build-pdfs.sh for how this fits into the PDF build.
"""
import re
import sys
import os

REPO_BASE_URL = "https://github.com/linusali/hass-docs"
REPO_BRANCH = "main"


def rewrite(html_path, source_repo_relpath):
    source_dir = os.path.dirname(source_repo_relpath)
    text = open(html_path, encoding="utf-8").read()

    def repl(m):
        href = m.group(1)
        if href.startswith(("http://", "https://", "mailto:", "#")):
            return m.group(0)
        if "#" in href:
            path_part, anchor = href.split("#", 1)
            anchor = "#" + anchor
        else:
            path_part, anchor = href, ""
        is_dir = path_part.endswith("/")
        repo_path = os.path.normpath(os.path.join(source_dir, path_part)).replace(os.sep, "/")
        kind = "tree" if is_dir else "blob"
        new_href = f"{REPO_BASE_URL}/{kind}/{REPO_BRANCH}/{repo_path}{anchor}"
        return f'href="{new_href}"'

    new_text = re.sub(r'href="([^"]+)"', repl, text)
    open(html_path, "w", encoding="utf-8").write(new_text)
    return new_text.count(REPO_BASE_URL)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    html_path, source_repo_relpath = sys.argv[1], sys.argv[2]
    n = rewrite(html_path, source_repo_relpath)
    print(f"Rewrote links in {html_path}: {n} {REPO_BASE_URL} hrefs now present")
