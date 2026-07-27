#!/usr/bin/env bash
# Build WhatsApp-shareable PDFs from every guide-*.adoc file in a phase
# directory.
#
# Usage:
#   tools/build-pdfs.sh phases/phase-4
#
# Output goes to <phase-directory>/pdf/, e.g. phases/phase-4/pdf/. Internal
# links between docs are rewritten to point at github.com/linusali/hass-docs
# (see tools/fix_pdf_links.py) since a shared PDF has no repo context of its
# own.
#
# Requires: npx (Node/npm, used to run Asciidoctor without a global install),
# python3, and weasyprint (`pip install weasyprint`).

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <phase-directory>  (e.g. phases/phase-4)" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$REPO_ROOT/tools"
PHASE_DIR="${1%/}"
PHASE_ABS="$REPO_ROOT/$PHASE_DIR"
OUT_DIR="$PHASE_ABS/pdf"

command -v npx >/dev/null 2>&1 || { echo "error: npx not found (need Node.js/npm)" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "error: python3 not found" >&2; exit 1; }
command -v weasyprint >/dev/null 2>&1 || { echo "error: weasyprint not found (pip install weasyprint)" >&2; exit 1; }

if [ ! -d "$PHASE_ABS" ]; then
  echo "error: $PHASE_DIR does not exist" >&2
  exit 1
fi

shopt -s nullglob
guides=("$PHASE_ABS"/guide-*.adoc)
shopt -u nullglob

if [ ${#guides[@]} -eq 0 ]; then
  echo "error: no guide-*.adoc files found in $PHASE_DIR" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

for guide in "${guides[@]}"; do
  base="$(basename "$guide" .adoc)"           # e.g. guide-simple
  rel_path="${guide#"$REPO_ROOT"/}"           # e.g. phases/phase-4/guide-simple.adoc
  html="$tmp_dir/$base.html"

  case "$base" in
    *simple*)    pdf_name="SSC-Home-Assistant-Simple-Guide.pdf" ;;
    *technical*) pdf_name="SSC-Home-Assistant-Technical-Guide.pdf" ;;
    *)           pdf_name="SSC-Home-Assistant-${base#guide-}.pdf" ;;
  esac

  echo "==> $rel_path"
  npx --yes asciidoctor@2.2.6 -a data-uri -a toc=preamble -o "$html" "$guide"
  python3 "$TOOLS_DIR/fix_pdf_links.py" "$html" "$rel_path"
  weasyprint -s "$TOOLS_DIR/print.css" "$html" "$OUT_DIR/$pdf_name" 2>&1 | grep -v "WARNING\|ttfont =" || true
  echo "    -> $PHASE_DIR/pdf/$pdf_name"
done

echo "Done."
