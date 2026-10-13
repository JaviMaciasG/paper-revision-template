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
| `make bundle` | Bundles for every rebuttal stage, without covers by default |
| `make bundle COVER=1` | Bundles with an initial note page |
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
COVER := 0
include ../support/reply.mk
```

## First and subsequent revisions

After submitting the original manuscript in your initialized project, run:

```sh
make new-round
```

With no existing revisions, this creates `revised1` from your `original` sources and `reply1` from a blank rebuttal skeleton. `revised1/Makefile` sets `original` as the comparison baseline. The rebuttal has an editor and two reviewers, with an opening comment/acknowledgment and three structured placeholder pairs rather than the demonstration's comments or answers. Each response prompts you to explain the action taken and identify the revised section, page, figure, or table.

Edit `revised1/paper.tex`, its bibliography and figures as needed. Fill in `reply1/metadata.tex` with the actual manuscript title, authors, and submission ID, and enter comments and responses in the reviewer/editor files. Then build:

```sh
make -C revised1
make -C reply1 bundle
```

After submitting `revised1`, another `make new-round` creates `revised2` and `reply2`, with `revised1` as the baseline. It preserves the preceding rebuttal's metadata, formatting, reviewer/editor structure, and letter wrappers, while replacing old comments and answers in `*-comments.tex` with fresh structured placeholders. Each file retains its outer `enumerate` or `itemize` style, and the configured cover default is carried forward. Update the new metadata for the submission identifier. Keep round-specific comments in those files, rather than custom shared inputs, so clearing remains reliable.

The same command creates `revised3`/`reply3` and later rounds. It skips generated PDFs, SyncTeX files, and `build/` contents while preserving PDF figures. It rejects symlinked sources, refuses overwrites, and rejects unpaired rebuttal stages. Root commands discover each new pair automatically. In the template clone itself, the first invocation creates round two because its worked-example round one already exists.

To add a reviewer, create `reviewer3-comments.tex` and a `reviewer3.tex` wrapper following the existing examples, include that comment file in `responses.tex`, and add `3` to `REVIEWERS` in the Makefile. When copying a wrapper, update its `\ReplyAudience` and comment-file input for the new reviewer number. Subsequent stages preserve this structure.

## How comparisons work

1. Compile both baseline and revised `paper.tex` with latexmk, including BibTeX and needed reruns.
2. Expand their section inputs and insert each generated `.bbl` using `latexpand --expand-bbl`.
3. Compare the expanded documents with latexdiff.
4. Compile the result with latexmk without running BibTeX again.

Generated names are stable: `build/paper-expanded.tex` and `paper-diff.pdf`. The enclosing directory identifies the manuscript version. Never maintain numbered flattened snapshots by hand. Bibliography corrections should retain citation keys; deleted references should also have their manuscript citations removed.

Each invocation consults latexmk's actual dependencies. Comparison source files are replaced only when their content changes. Builds lock each stage so concurrent root jobs cannot write to the same document at once. Do not run cleanup concurrently with a build.

Review the comparison before submission: complex mathematics, tables, and figure replacements can require latexdiff configuration. The supplied text, local section, figure, and bibliography example is tested. A comparison uses the revised stage as its working directory, so retain any assets needed by deleted content when preparing a diff. Manuscript sources and bibliography remain local to each stage; only build machinery is shared.

## Response letters

Each letter uses the original rebuttal format: 12-point A4 pages with 2.5 cm margins, a full title and manuscript authors, numbered **1 Introduction**, and numbered response sections. The combined letter includes editor and reviewer sections. Individual letters reuse the corresponding content.

### Manuscript title, authors, and ID

Edit the metadata in each `replyN/metadata.tex`:

```tex
\newcommand{\PaperTitle}{Your real manuscript title}
\newcommand{\PaperAuthors}{Ada Author \and Ben Author}
\newcommand{\SubmissionID}{JOURNAL-2026-001}
```

Use the same author names as the paper. `SubmissionID` is the manuscript identifier assigned by the journal; update it for the current round if the journal issues a new one. The same values appear in every individual and combined letter, and the optional cover uses the same title and ID. Metadata is explicit rather than extracted from arbitrary manuscript source code.

The combined title is **Responses to the comments of all the reviewers to the previously submitted manuscript "manuscript title" (manuscript ID manuscript-id)**. Individual titles substitute **reviewer X** or **the editor**. Section headings are **Responses to the comments of reviewer X** and **Responses to the Editor comments**.

### Comments and answers

Edit `editor-comments.tex` and `reviewerN-comments.tex`. `reviewerN.tex` is a standalone wrapper with editing guidance; `responses.tex` includes the same shared comment files. Keep each answer in its shared file so it appears identically in both forms.

```tex
\begin{enumerate}
  \item \reviewercomment{The reviewer's comment, copied verbatim.}
    \response{Our answer, including the change and its location in the manuscript.}
  \item \reviewercomment{The next comment.}
    \response{A first response paragraph.}
    \response{An additional explanation.}
\end{enumerate}
```

Use `itemize` for bulleted comments. For a response with several actions, add a nested list and wrap each item's answer text in `\response{...}`. The demonstration shows both list styles and a nested response list. New rounds supply editable list scaffolds rather than empty files or copied old answers; add or remove items to match the received comments.

`\reviewercomment{...}` renders comments in italics. `\response{...}` makes the **entire answer bold**, with the original `1ex` spacing before and after it. `\responseWResponse{...}` does the same while adding **Response:**. `\reviewcomment` remains an alias for compatibility and adds no label. `commands.tex` holds these formatting definitions; `preamble.tex` holds the document layout. The introduction retains the original explanation, including red deletion and blue addition examples.

### Plain letters and optional covers

```sh
make -C reply1                  # Combined, editor, and individual letters
make -C reply1 reviewer1        # One individual letter
make -C reply1 bundle           # Responses followed by the manuscript diff
make -C reply1 bundle COVER=1   # Initial note page, responses, then the diff
make bundle COVER=1            # Covered bundles for all reply stages
```

The cover reproduces the original **Note to the reviewers** presentation, is unnumbered, and explains the bundle's contents. Plain letters always begin with their title and authors. `COVER=0` disables the cover and is the initial default; set `COVER := 1` in a reply Makefile to make covers that round's default. A command-line setting overrides that default. For container builds, use `sh support/container.sh bundle COVER=1`.

Bundles use `responses-with-diff.pdf`, `editor-with-diff.pdf`, and `reviewerN-with-diff.pdf` directly in the reply folder. Switching the cover option regenerates those same filenames. Plain response PDFs are unchanged by the cover option. Cover intermediates remain inside `build/`, and cleanup removes them. Plain response letters can be built independently of the manuscript comparison.

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

## Why I keep separate revision folders

I chose this structure because the practical unit of this work is a submission round: a manuscript, its bibliography and figures, and the corresponding responses. Separate folders keep every round immediately accessible and buildable without checking out a different commit. I can compare submissions side by side and work on a new revision while consulting earlier reviewer comments and answers.

Copying the sources into each new `revisedN` folder is deliberate. Each manuscript has its own inputs, and each `replyN` folder keeps its responses alongside that round. The baseline link makes the intended comparison explicit, and submission archives can be prepared directly from the appropriate manuscript folder. This also makes the workflow usable by collaborators who are comfortable with folders and LaTeX but do not routinely navigate Git history.

Tags and repository history could identify the same milestones, but accessing a previous manuscript would then require a checkout, an exported snapshot, or a separate worktree. I prefer keeping the submission stages visible in one working directory. Git history still records edits within each stage, and tags can identify the exact commits submitted to the journal. The folders complement that history; they do not replace it or automatically make old submissions immutable. Submitted sources must remain frozen.

The tradeoff is duplicated source content, more directories, and potentially greater repository size, especially with large figures. Build rules are shared to avoid repeated maintenance. Manuscript text, bibliography, and figures stay local to each round: sharing those mutable inputs could silently change the output of an earlier submission. This accepts some duplication in exchange for explicit, readily accessible submission records.

## Validation and license

`make test` uses fixed demonstration fixtures in temporary projects, so authors can replace the live manuscript without breaking the checks. It verifies project initialization, the minimal starter, first and subsequent revisions, fresh parallel builds, unresolved references, dependency updates, no-op comparisons, stage creation, overwrite protection, source archive extraction/compilation, help without TeX, missing-tool diagnostics, build failures, PDF placement, original rebuttal titles and sections, guided response scaffolds, optional bundle covers, and cleanup that preserves PDF figures. CI retains generated PDFs and ZIPs as artifacts.

The build scripts and example documents are MIT licensed. TeX Live, IEEEtran, and other tools retain their own licenses; their files are not redistributed in the source template.
