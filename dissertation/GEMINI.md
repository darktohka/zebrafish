# GEMINI.md

This file provides guidance to Gemini when working with the LaTeX project in this directory.

## Build

To build the project, you can use the `build.sh` script:

```bash
./build.sh
```

This script runs the following command:

```bash
pdflatex -synctex=1 -interaction=batchmode -recorder --jobname=output dolgozat.tex
```

This will create a file named `output.pdf`.

## Structure

The main LaTeX file is `dolgozat.tex`. It includes several other files to form the complete document:
- `content/packages.tex`: LaTeX package imports.
- `content/thesis-hu.tex`: Language configuration.
- `content/preamble.tex`: Preamble and custom commands.
- `abstract.tex`: The abstract of the dissertation.
- `chapter*.tex`: The chapters of the dissertation.
- `bibliography.bib`: The bibliography.

The final PDF includes title pages in different languages and some embedded PDF documents.
