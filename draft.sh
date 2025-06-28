#!/bin/bash

rm output.pdf || true
pdflatex -synctex=1 -interaction=batchmode -recorder --jobname=output --shell-escape dolgozat.tex || true

if [[ -f output.pdf ]]; then
    echo "PDF generated successfully."
    exit 0
else
    echo "Failed to generate PDF."
    exit 1
fi
