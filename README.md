# IEEE manuscript and rebuttal template

A standalone publication workflow with a first submission (`original`), an example revision (`revised1`), and matching responses (`reply1`). The IEEE paper is also a short manual. All example bibliography entries are fictional.

## Quick start

Clone this repository, then run:

```sh
make help
make check-tools
make -j4
```

Open `original/paper.pdf`, `revised1/paper.pdf`, `revised1/paper-diff.pdf`, and `reply1/responses.pdf`. The comparison uses blue underlining for additions and red strikeout for deletions. It demonstrates text changes plus an unchanged reference, a corrected reference, a removed reference, and a new reference.

Replace the sample manuscript, authors, bibliography, and response content with your own. Keep each manuscript's inputs and figures inside its stage folder. Finished PDFs appear beside the manuscript or response `.tex` files. Auxiliaries and generated comparison sources stay in `build/`; SyncTeX files accompany PDFs for editor navigation. Generated outputs are ignored, while PDF figure assets remain trackable. The stage-root filenames `paper.pdf`, `paper-diff.pdf`, `responses.pdf`, `editor.pdf`, `reviewerN.pdf`, and their response bundles are reserved for build outputs; put figures with these names in `figures/`.

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
revised1/                First revision; baseline is ../original
reply1/                  Responses associated with ../revised1
tests/                   Workflow checks using disposable repository copies
```

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
| `make new-round` | Next numbered revision and rebuttal pair |
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

## Starting another round

After submitting `revised1`, run:

```sh
make new-round
```

This creates `revised2` from the latest manuscript sources, links it to `revised1`, and creates `reply2` with fresh comment/answer placeholders. It preserves the preceding rebuttal's metadata, formatting, reviewer/editor structure, and letter wrappers. Update `reply2/metadata.tex` for the new submission identifier. Old comments and answers in `*-comments.tex` files are cleared. Keep round-specific comments in those files, rather than custom shared inputs, so clearing remains reliable.

The helper skips generated `build/` contents, rejects symlinked sources, and refuses to overwrite existing stages or continue past an unpaired rebuttal folder. The same command later creates `revised3`/`reply3`, and so on. Only the first example round is included in the template; extra stages are created when needed. Root commands discover the new folders automatically.

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

After submission, freeze that stage's source files and record it in Git:

```sh
git add .
git commit -m "Record first submission"
git tag submitted-original
```

Use a matching tag such as `submitted-revised1` for later submissions. Build targets never commit, push, or create tags. This repository has fresh history and no dependency on the paper from which the workflow was extracted.

## Validation and license

`make test` checks fresh parallel builds, unresolved references, dependency updates, no-op comparisons, stage creation, overwrite protection, source archive extraction/compilation, help without TeX, missing-tool diagnostics, build failures, PDF placement, and cleanup that preserves PDF figures. CI retains generated PDFs and ZIPs as artifacts.

The build scripts and example documents are MIT licensed. TeX Live, IEEEtran, and other tools retain their own licenses; their files are not redistributed in the source template.
