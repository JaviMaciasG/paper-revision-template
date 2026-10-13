# IEEE manuscript and rebuttal template

A standalone publication workflow with a first submission (`original`), an example revision (`revised1`), and matching responses (`reply1`). The IEEE paper is also a short manual. All example bibliography entries are fictional.

## Starting your paper

From a clone of the template, create a separate project:

```sh
make init-project DEST=../my-paper
cd ../my-paper
make help
make check-tools
make
```

The destination must not already exist and must be outside the template repository. Initialization leaves the template untouched. It creates a self-contained project with only `original/` as an active manuscript stage, plus shared build tools, documentation, tests, and CI configuration. No Git history, generated PDFs, or active demonstration revisions are copied. Git initialization and commits remain your choice.

The first PDF is `original/paper.pdf`. It is a minimal IEEE starter that explicitly instructs you to replace **`original/paper.tex` with your real manuscript and `original/paper.bib` with your real bibliography**, keeping those filenames. Replace the title, authors, abstract, keywords, and placeholder sections. Remove the fictional starter reference and its citation when adding your real references. Initialization always uses this minimal starter, even if the template's descriptive example has been edited.

Keep included source files and figures inside `original/`. Once the original is submitted, freeze its source files and start the first revision as described below. The project is independent of the template: its builds, tests, container wrapper, and later round creation do not need the original clone.

## Trying the worked example

In the template repository itself, run:

```sh
make -j4
```

Open `original/paper.pdf`, `revised1/paper.pdf`, `revised1/paper-diff.pdf`, and `reply1/responses.pdf`. Here the IEEE paper is a descriptive manual, and the revision demonstrates text changes plus an unchanged reference, a corrected reference, a removed reference, and a new reference. Blue underlining indicates additions and red strikeout indicates deletions. The template's root example is retained for exploration; use `init-project` to start your own author project.

Finished PDFs appear beside the manuscript or response `.tex` files. Auxiliaries and generated comparison sources stay in `build/`; SyncTeX files accompany PDFs for editor navigation. Generated outputs are ignored, while PDF figure assets remain trackable. The stage-root filenames `paper.pdf`, `paper-diff.pdf`, `responses.pdf`, `editor.pdf`, `reviewerN.pdf`, and their response bundles are reserved for build outputs; put figures with these names in `figures/`.

## Local dependencies

Use GNU Make, Python 3.9 or newer on Linux/macOS, and TeX Live with pdfLaTeX, BibTeX, IEEEtran, latexmk, latexpand, and latexdiff. Optional bundles require Poppler's `pdfunite`; Ghostscript (`gs`) is a fallback, including in the pinned container. The helpers use Python's standard library, with no pip dependencies. Native Windows users can use WSL or the Linux container.

On Debian/Ubuntu, the relevant packages are:

```sh
sudo apt install make python3 latexmk latexdiff \
  texlive-latex-extra texlive-publishers texlive-fonts-recommended \
  texlive-extra-utils poppler-utils
```

TeX Live installations on other systems can use their package manager to install the same tools. `make check-tools` reports missing commands and verifies the IEEE class and bibliography style.

## Pinned container

Docker users can build without installing TeX locally:

```sh
make container
make container-bundle
sh support/container.sh check-tools all bundle zip test
```

The image is recorded once in `support/container-image.txt` using an immutable SHA-256 digest. It is the upstream [TeX Live full image](https://github.com/xu-cheng/latex-docker/pkgs/container/texlive-full), pinned to its 20261001 Linux amd64 release. The wrapper mounts this repository, uses your user ID, and writes the same outputs as local builds. It explicitly selects amd64; other architectures require Docker emulation. The full image is large, so allow several GB for its first pull.

CI uses the same wrapper and digest. Updating the toolchain means changing that file and rerunning the checks. Local TeX installations may produce different line breaks or PDF metadata. The pinned environment provides a fixed toolchain, not a guarantee of byte-identical PDFs.

## Layout and commands

```text
Makefile                 Discover stages and expose root commands
support/                 Shared rules, latexmk configuration, and helpers
original/                Initial manuscript and its own bibliography/figures
revised1/                Created by new-round; baseline is ../original
reply1/                  Created with revised1; responses for that manuscript
tests/                   Workflow checks and fixed demonstration fixtures
```

Initialized projects start without `revised1/` and `reply1/`; the template clone already has those demonstration folders.

Root `make` builds all manuscript PDFs, revision comparisons, and combined/editor/individual response letters. It does not append comparisons to response PDFs unless you request bundles. `make help` works at the root and in every stage without Python or TeX installed.

| Command | Result |
| --- | --- |
| `make -C original` | Initial manuscript |
| `make -C revised1` | Revised manuscript and comparison |
| `make -C revised1 diff` | Build both versions and compare them |
| `make -C reply1` | Combined, editor, and individual letters |
| `make -C reply1 reviewer1` | Reviewer 1's letter |
| `make -C reply1 bundle` | Each letter plus the manuscript comparison |
| `make bundle` | Bundles for every rebuttal stage |
| `make zip` | Standalone source archives for every manuscript |
| `make init-project DEST=../my-paper` | Independent project with a minimal IEEE starter |
| `make new-round` | First or next numbered revision and rebuttal pair |
| `make clean` | Remove auxiliaries, retaining final PDFs and ZIPs |
| `make distclean` | Remove all generated outputs |
| `make test` | Integration checks in temporary copies |

Every manuscript uses `paper.tex` and `paper.bib`. A revision's short Makefile declares its baseline explicitly:

```make
TYPE := revision
BASELINE := ../original
include ../support/manuscript.mk
```

A rebuttal's Makefile declares its manuscript and reviewer numbers:

```make
REVISION := ../revised1
REVIEWERS := 1 2
include ../support/reply.mk
```

## First and subsequent revisions

After submitting the original manuscript in your initialized project, run:

```sh
make new-round
```

With no existing revisions, this creates `revised1` from your `original` sources and `reply1` from a blank rebuttal skeleton. `revised1/Makefile` sets `original` as the comparison baseline. The rebuttal has an editor and two reviewers, with explicit placeholders rather than the demonstration's comments or answers.

Edit `revised1/paper.tex`, its bibliography and figures as needed. Fill in `reply1/metadata.tex` with the actual manuscript title, authors, and submission ID, and enter comments and responses in the reviewer/editor files. Then build:

```sh
make -C revised1
make -C reply1 bundle
```

After submitting `revised1`, another `make new-round` creates `revised2` and `reply2`, with `revised1` as the baseline. It preserves the preceding rebuttal's metadata, formatting, reviewer/editor structure, and letter wrappers, while clearing all old comments and answers in `*-comments.tex`. Update the new metadata for the submission identifier. Keep round-specific comments in those files, rather than custom shared inputs, so clearing remains reliable.

The same command creates `revised3`/`reply3` and later rounds. It skips generated PDFs, SyncTeX files, and `build/` contents while preserving PDF figures. It rejects symlinked sources, refuses overwrites, and rejects unpaired rebuttal stages. Root commands discover each new pair automatically. In the template clone itself, the first invocation creates round two because its worked-example round one already exists.

To add a reviewer, create `reviewer3-comments.tex` and a `reviewer3.tex` wrapper following the existing examples, include that comment file in `responses.tex`, and add `3` to `REVIEWERS` in the Makefile. Subsequent stages preserve this structure.

## How comparisons work

1. Compile both baseline and revised `paper.tex` with latexmk, including BibTeX and needed reruns.
2. Expand their section inputs and insert each generated `.bbl` using `latexpand --expand-bbl`.
3. Compare the expanded documents with latexdiff.
4. Compile the result with latexmk without running BibTeX again.

Generated names are stable: `build/paper-expanded.tex` and `paper-diff.pdf`. The enclosing directory identifies the manuscript version. Never maintain numbered flattened snapshots by hand. Bibliography corrections should retain citation keys; deleted references should also have their manuscript citations removed.

Each invocation consults latexmk's actual dependencies. Comparison source files are replaced only when their content changes. Builds lock each stage so concurrent root jobs cannot write to the same document at once. Do not run cleanup concurrently with a build.

Review the comparison before submission: complex mathematics, tables, and figure replacements can require latexdiff configuration. The supplied text, local section, figure, and bibliography example is tested. A comparison uses the revised stage as its working directory, so retain any assets needed by deleted content when preparing a diff. Manuscript sources and bibliography remain local to each stage; only build machinery is shared.

## Response letters

`metadata.tex` contains manuscript title, authors, and submission ID. `preamble.tex` provides comment/response formatting. `editor-comments.tex` and `reviewerN-comments.tex` hold the actual comments and answers. The individual wrappers and `responses.tex` reuse those files.

`bundle` builds the matching revision comparison first and appends it to each letter. Output names are `responses-with-diff.pdf`, `editor-with-diff.pdf`, and `reviewerN-with-diff.pdf`, placed directly in the reply folder. Plain response letters can be built independently of the manuscript comparison.

## Submission archives and history

`make -C revised1 zip` creates `revised1/build/paper.zip`. It collects actual project-local TeX inputs from the compiler's recorder output, adds referenced bibliography databases and local bibliography styles, and includes minimal build helpers and the license. System TeX packages are excluded. Inputs outside the stage are rejected if they belong to this repository.

Extract the ZIP into an empty folder and run `make`. It builds a clean manuscript without needing other rounds. Its `paper.pdf` appears beside `paper.tex`. Its source helpers are in `support/`, so cleanup cannot remove them. TeX Live's IEEEtran class and style must be installed on the recipient's system. Response PDFs and bundles are submitted separately; source ZIPs contain manuscripts only.

If you want version control in the initialized author project, run `git init -b main` first. After submission, freeze that stage's source files and record it in Git:

```sh
git add .
git commit -m "Record first submission"
git tag submitted-original
```

Use a matching tag such as `submitted-revised1` for later submissions. Build targets never commit, push, or create tags. Initialized projects contain no copied Git history and have no dependency on the template clone or the paper from which the workflow was extracted.

## Validation and license

`make test` uses fixed demonstration fixtures in temporary projects, so authors can replace the live manuscript without breaking the checks. It verifies project initialization, the minimal starter, first and subsequent revisions, fresh parallel builds, unresolved references, dependency updates, no-op comparisons, stage creation, overwrite protection, source archive extraction/compilation, help without TeX, missing-tool diagnostics, build failures, PDF placement, and cleanup that preserves PDF figures. CI retains generated PDFs and ZIPs as artifacts.

The build scripts and example documents are MIT licensed. TeX Live, IEEEtran, and other tools retain their own licenses; their files are not redistributed in the source template.
