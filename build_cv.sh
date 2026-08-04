#!/usr/bin/env bash
#
# Build a new version of the CV PDFs and wire them into index.html.
#
#   latext/main.tex        -> CV/pkYYYYMMen.pdf
#   latext/mainspanish.tex -> CV/pkYYYYMMes.pdf
#
# Usage:
#   ./build_cv.sh            # uses the current year+month
#   ./build_cv.sh 202608     # force a specific YYYYMM stamp

set -euo pipefail

# ---------------------------------------------------------------- config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LATEX_DIR="$SCRIPT_DIR/latext"
CV_DIR="$SCRIPT_DIR/CV"
BUILD_DIR="$SCRIPT_DIR/temp"
INDEX_HTML="$SCRIPT_DIR/index.html"

# YYYYMM stamp: first argument, or current year+month.
STAMP="${1:-$(date +%Y%m)}"

if ! [[ "$STAMP" =~ ^[0-9]{6}$ ]]; then
    echo "error: version stamp must be YYYYMM (6 digits), got '$STAMP'" >&2
    exit 1
fi

command -v pdflatex >/dev/null 2>&1 || {
    echo "error: pdflatex not found in PATH" >&2
    exit 1
}

# --------------------------------------------------------------- preflight
# Map required .sty files -> tlmgr package names (only non-trivial ones).
declare -a REQUIRED_STY=(fontawesome raleway paracol smartdiagram tikz-3dplot titlesec)
missing=()
for pkg in "${REQUIRED_STY[@]}"; do
    kpsewhich "${pkg}.sty" >/dev/null 2>&1 || missing+=("$pkg")
done
# raleway pulls in the LY1 font encoding (ly1enc.def, tlmgr package: ly1).
kpsewhich ly1enc.def >/dev/null 2>&1 || missing+=(ly1)
if [ "${#missing[@]}" -gt 0 ]; then
    echo "error: missing LaTeX packages: ${missing[*]}" >&2
    echo "install them with:" >&2
    echo "  sudo tlmgr install ${missing[*]}" >&2
    exit 1
fi

mkdir -p "$CV_DIR" "$BUILD_DIR"

# ---------------------------------------------------------- source links
# Update the "English CV | Español CV" cross-links embedded in the .tex
# sources to point at the version being built, so the compiled PDFs link to
# the current date instead of a stale one.
echo ">> updating CV links in .tex sources"
sed -i '' -E \
    -e "s#CV/pk[0-9]{6}en\.pdf#CV/pk${STAMP}en.pdf#g" \
    -e "s#CV/pk[0-9]{6}es\.pdf#CV/pk${STAMP}es.pdf#g" \
    "$LATEX_DIR/main.tex" "$LATEX_DIR/mainspanish.tex"

# ---------------------------------------------------------------- build
# args: <source.tex> <output-basename>
build_pdf() {
    local src="$1"
    local out="$2"

    echo ">> building $out.pdf from $(basename "$src")"

    # Two passes so references/layout settle. Run inside the latext dir so
    # relative asset paths (images, .cls, .sty) resolve correctly.
    for _ in 1 2; do
        (cd "$LATEX_DIR" && pdflatex \
            -interaction=nonstopmode \
            -halt-on-error \
            -jobname="$out" \
            -output-directory="$BUILD_DIR" \
            "$(basename "$src")" >/dev/null)
    done

    cp "$BUILD_DIR/$out.pdf" "$CV_DIR/$out.pdf"
    echo "   -> $CV_DIR/$out.pdf"
}

build_pdf "$LATEX_DIR/main.tex"        "pk${STAMP}en"
build_pdf "$LATEX_DIR/mainspanish.tex" "pk${STAMP}es"

# ---------------------------------------------------------------- index
echo ">> updating index.html references"
# Point both links at the freshly built versions.
# Matches both the href (CV/pk######en.pdf) and any bare filename shown as
# link text (pk######en.pdf), so displayed names stay in sync.
sed -i '' -E \
    -e "s#pk[0-9]{6}en\.pdf#pk${STAMP}en.pdf#g" \
    -e "s#pk[0-9]{6}es\.pdf#pk${STAMP}es.pdf#g" \
    "$INDEX_HTML"

echo ">> done: CV updated to version ${STAMP}"
