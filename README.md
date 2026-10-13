# Generic manuscript and rebuttal template

A reusable paper project with explicit submitted manuscripts and review rounds. The example IEEE paper is a short manual; its first revision demonstrates text changes and reference corrections, additions, and deletions. All names, results, and references in the examples are fictional.

- [Why did I generated this repo](#why-did-i-generated-this-repo)
- [Getting started](#getting-started)
- [The publication workflow](#the-publication-workflow)
- [Guided example: changing reviewers across two rounds](#guided-example-changing-reviewers-across-two-rounds)
- [Optional operations](#optional-operations)
- [Command and file reference](#command-and-file-reference)
- [Why I keep complete stage folders](#why-i-keep-complete-stage-folders)
- [Validation and license](#validation-and-license)

## Why did I generated this repo

I created this repository because I was tired of the manual work involved in handling paper revisions. The process often repeats: 

1. Submit a manuscript and wait...
2. Receive comments from the editor and reviewers, hopefully with a major/minor revision decision
3. Prepare rebuttal letter(s) and a revised manuscript
4. Submit again and wait...
5. Possibly receive another set of minor/major revision comments and start again.

Each round involves more than editing the paper. You need to keep the previously submitted version, prepare the next version, answer every comment, and generate a document showing the differences between the two manuscripts. Depending on the journal, you may also need a single response letter covering all reviewers, separate letters for individual reviewers, or a letter for the editor.

The reviewers can change between rounds, and so can their number. I wanted a system that could handle these changes while keeping each round's manuscript, response letters, bibliography, and comparison together.

This template tries to automate the repetitive preparation and build tasks. It creates new review rounds, provides structured response files, builds combined and individual rebuttal letters, and generates the revised manuscript and its marked comparison with the preceding submission. The objective is letting me spend more time addressing the comments and improving the paper.

## Getting started

### Requirements

Use GNU Make, Bash 3.2 or newer, and ordinary Unix utilities on Linux/macOS. Install TeX Live with pdfLaTeX, BibTeX, IEEEtran, latexmk, latexpand, and latexdiff. Source archives require `zip` and `unzip`; bundles require either Poppler's `pdfunite` or Ghostscript (`gs`). The integration tests also use `pdfinfo`/`pdftotext` when available, with Ghostscript fallbacks. Native Windows users can use WSL. No Python interpreter, pip packages, or Python helper scripts are required.

Run `make check-tools` from the clone to check your installation. `make help` works without TeX; each stage also has a help target.

### Build PDF copies of the guides

To read or share this README and the guided example as PDFs, install Pandoc in addition to the existing latexmk/pdfLaTeX tools and TeX Live packages (`fvextra`, `xurl`, `xcolor`, `lmodern`, `booktabs`, `longtable`, `hyperref`, `etoolbox`, `needspace`, and `tcolorbox`). These are normally supplied by the LaTeX-extra and fonts-recommended packages. No separate syntax-highlighting executable or Python interpreter is needed.

To generate the PDF guides, run the following Bash commands from the project root:

```bash
make docs
# Or build only one guide:
make README.pdf
make HOWTO.pdf
```

The outputs are `README.pdf` and `HOWTO.pdf` at the root. They have numbered sections, clickable contents and bookmarks, colored Bash/LaTeX/BibTeX code on very light blue-gray backgrounds, and wrapped code lines. Both PDFs show Javier Macias-Guarasa as their author, including in PDF metadata. The Markdown titles remain unnumbered in the PDFs. Generated LaTeX and auxiliaries stay in `build/docs/`. `make clean` retains the PDFs; `make distclean` removes them. These commands also work in initialized publication projects. Normal manuscript builds do not require Pandoc.

### Template clone versus publication project

The clone contains a populated demonstration, described below. Source-changing management targets are disabled there to protect the example. Use `init-project` to create an independent, editable publication project. Details are in [protection and cleanup](#protection-cleanup-and-interrupted-operations).

### Explore the supplied example

The main repository already contains sample sources for a submitted paper, its first revision, and completed rebuttal letters for two reviewers and the editor. You can build these files immediately after installing the required tools:

| Folder | Sample source files | Purpose |
|---|---|---|
| `original/` | `paper.tex`, `paper.bib`, `sections/comparisons.tex`, `figures/workflow.tex` | The original submitted manuscript, with an included section and figure |
| `revised1/` | `paper.tex`, `paper.bib`, and corresponding included files | The revised manuscript, demonstrating text changes and bibliography corrections, additions, and deletions |
| `reply1/` | `metadata.tex`, `responses.tex`, `editor.tex`, `reviewer1.tex`, `reviewer2.tex`, and the matching `*-comments.tex` files | Combined, editor, and individual reviewer responses |

Each stage has a `Makefile` that uses the shared build rules in `support/`. Keep these files along with the document sources.

In `reply1/`, each `reviewerX.tex` is a wrapper that includes `reviewerX-comments.tex`. The combined `responses.tex` includes those same comment/answer files, together with the editor's responses. Edit the comments files to keep the combined and individual letters consistent. The shared `preamble.tex`, `commands.tex`, and `introduction.tex` provide the layout, formatting, and opening section; `metadata.tex` supplies the paper title, authors, and manuscript ID. The letters use `revised1/paper.bib` for any cited references.

Run the root commands from the repository root. To use the folder-local commands, first enter the indicated folder—for example, run `cd original`—then run the command shown. Run `cd ..` to return to the root before entering another stage. Output paths below are relative to the repository root.

| From the repository root | Folder | Command inside that folder | Output |
|---|---|---|---|
| `make -C original paper` | `original/` | `make paper` | `original/paper.pdf` |
| `make -C revised1 paper` | `revised1/` | `make paper` | `revised1/paper.pdf` |
| `make -C revised1 diff` | `revised1/` | `make diff` | `revised1/paper-diff.pdf` |
| `make -C reply1 responses` | `reply1/` | `make responses` | `reply1/responses.pdf`, the joint editor/reviewer letter |
| `make -C reply1 editor` | `reply1/` | `make editor` | `reply1/editor.pdf` |
| `make -C reply1 reviewer1` | `reply1/` | `make reviewer1` | `reply1/reviewer1.pdf` |
| `make -C reply1 reviewer2` | `reply1/` | `make reviewer2` | `reply1/reviewer2.pdf` |
| `make -C reply1 bundle` | `reply1/` | `make bundle` | The four letters with the comparison appended, listed below |
| `make -C original zip` | `original/` | `make zip` | `original/paper-original.zip` |
| `make -C revised1 zip` | `revised1/` | `make zip` | `revised1/paper-revised1.zip` |

The standalone marked comparison, `revised1/paper-diff.pdf`, shows changes against `original/paper.tex`, including changes in included sections and rendered bibliography entries. `make bundle` integrates that same comparison with each response document and produces:

- `reply1/responses-with-diff.pdf`: joint responses followed by the comparison.
- `reply1/editor-with-diff.pdf`: editor responses followed by the comparison.
- `reply1/reviewer1-with-diff.pdf`: reviewer 1 responses followed by the comparison.
- `reply1/reviewer2-with-diff.pdf`: reviewer 2 responses followed by the comparison.

Use `make -C reply1 bundle COVER=1`, or `make bundle COVER=1` inside `reply1/`, to prepend an explanatory cover. The order is then cover, response letter, comparison. The plain response PDFs remain separate.

For shortcuts, run `make` at the root to build both manuscripts, the comparison, and all plain response letters; `make bundle` builds all response bundles, and `make zip` builds both manuscript source archives. PDFs and ZIPs appear in the stage folders; auxiliary files stay under `build/`.

For a complete publication exercise, follow [HOWTO.md](HOWTO.md). That separate example starts with reviewers 1, 2, and 3, then changes to reviewers 1, 3, and 4 in the second round. To start your own manuscript, create a publication project as described next.

### Create your publication project

Clone this repository, then create an author project outside the clone.

To initialize your publication project, run the following Bash commands:

```bash
make init-project DEST=../my-paper
cd ../my-paper
make help
```

The new project contains the build system, documentation, examples, and a minimal `original/paper.tex` and `original/paper.bib`. It has no review rounds and no Git history. **Replace both files with your real manuscript and bibliography**, keeping these filenames. The starter itself gives these instructions. See [preparing the original manuscript](#prepare-and-submit-the-original-manuscript) for where to put your sources.

## The publication workflow

### Prepare and submit the original manuscript

Replace `original/paper.tex` and `original/paper.bib` with your real manuscript and bibliography. Put included TeX files, figures, and other dependencies inside `original/`; avoid dependencies outside the project. Update the title and authors, and use your publication's required IEEE options and packages.

To compile and package the original manuscript, and optionally initialize Git, run the following Bash commands:

```bash
make check-tools
make original
make -C original zip
# Optionally start independent version control:
git init
git add .
git commit -m 'Initial submitted manuscript'
```

Submit `original/paper.pdf`, then treat the sources in `original/` as the submitted snapshot.

### Start the first revision

From an initialized publication project's root, after receiving the first decision.

To create the first review round, run the following Bash command from the publication root:

```bash
make new-round
```

This builds `original/paper.tex`, copies its manuscript dependencies into `revised1/`, and creates `reply1/` from the response scaffold, initially with two reviewers plus the editor. The required build tools must be installed before creating a round. See the following steps to configure reviewers, edit sources, and build the submission.

### Set the reviewers for this round

There is no fixed reviewer limit. New author projects start round 1 with reviewers 1 and 2; add or remove them to match the decision. The editor is always separate and does not count as a reviewer. The `REVIEWERS` list in the round's Makefile is authoritative. Numbers remain stable when another reviewer is removed; gaps are allowed. Prefer the targets to manual changes so membership, generated inputs, sources, and safety records remain consistent.

To add, remove, or inspect reviewers, use the following Bash commands from the indicated folders:

```bash
# From the project root:
make add-reviewer ROUND=1                 # next unused number after the highest ID
make remove-reviewer ROUND=1 REVIEWER=3  # remove it while untouched
make add-reviewer ROUND=1 REVIEWER=4      # explicit journal reviewer number
make remove-reviewer ROUND=1 REVIEWER=4
make info-reviewer                       # every review round, counts and IDs
make info-reviewer ROUND=1

# From reply1/: these affect round 1 automatically:
cd reply1
make add-reviewer
make remove-reviewer REVIEWER=3
make info-reviewer
cd ..
```

`REVIEWER` is optional for adding and required for removing. At the root, add/remove require `ROUND`; in `replyN`, an explicitly conflicting `ROUND` is rejected. `info-reviewer` reports the current round inside a reply folder, and all rounds at the root. With no rounds it reports the original-only status; missing configured sources are errors.

The file roles are explained under [response files and formatting](#response-files-and-formatting).

Removal succeeds only while both the wrapper and comments file match their generated scaffolds. Configure membership before filling answers; populated files are protected. See [protection and cleanup](#protection-cleanup-and-interrupted-operations) for details.

### Revise the manuscript and write responses

Edit the current `revisedN/paper.tex`, included sources, and `revisedN/paper.bib`. Fill `replyN/metadata.tex`, `editor-comments.tex`, and each configured `reviewerX-comments.tex`. Keep the previously submitted stages unchanged.

#### Response files and formatting

`reviewerX.tex` is a small standalone letter wrapper: audience, common preamble, introduction, and inclusion of `reviewerX-comments.tex`. **Put received comments and your answers in `reviewerX-comments.tex`**, which is also included in the combined letter. Newly added reviewers receive a ready-to-compile wrapper and a section with an optional overall comment plus three TODO comment/answer pairs. Add/remove items and use numbered or bulleted lists to match the actual decision. The editor gets analogous scaffolding.

`metadata.tex` defines `\PaperTitle`, `\PaperAuthors`, and `\SubmissionID`. Use the real paper title and all paper authors; separate authors with `\and`. These values are shared by combined, editor, individual, and optional cover documents.

The document title follows the original repository's wording:

> Responses to the comments of all the reviewers to the previously submitted manuscript "<manuscript title>" (manuscript id <manuscript-id>)

Individual letters use “reviewer X”; the editor letter and editor-only combined letter address “the editor”. Section 1 retains the original introduction content. Subsequent sections are “Responses to the Editor comments” and “Responses to the comments of reviewer X”. The original 12-point A4 layout, 25 mm margins, italic reviewer comments, and fully bold replies with their spacing are kept in `preamble.tex` and `commands.tex`.

The following LaTeX example shows numbered reviewer comments and bulleted reply details:

```tex
\section{Responses to the comments of reviewer 1}
\begin{enumerate}
  \item \reviewercomment{Paste the received comment here.}
    \response{Explain the change and identify its location.}
    \begin{itemize}
      \item \response{First specific action.}
      \item \response{Second specific action.}
    \end{itemize}
\end{enumerate}
```

Use `itemize` for bullets, `enumerate` for numbered comments, or separate comment/answer paragraphs for unformatted messages. Escape TeX special characters in pasted emails (for example `%`, `&`, `_`, and `#`). Keep the received wording intact; list numbering is formatting, not part of the comment text. The shared introductory section and all wrappers can be customized for your publication.

#### References in response letters

Each round's response letters use **the same `revisedN/paper.bib` as its revised manuscript**. Do not create a separate reply bibliography. Add a reply-only entry to that file if needed; the manuscript will not list it unless cited there. Use normal `\cite{key}` or `\nocite{key}` in replies, including included TeX files. `\nocite{*}` deliberately selects every database entry.

Bibliography declarations are inserted automatically at the end of a letter only when a citation or `\nocite` actually executes. Comments containing `\cite` do not trigger bibliography processing. A citation-free letter compiles without a bibliography, even with an empty or absent database; a citing letter requires a valid database and keys. Each individual letter gets its own cited subset; the combined letter gets the union of its executed citations. Adding/removing the last citation and changing `paper.bib` are handled by latexmk. The hook supports the template's standard LaTeX citation setup; if you replace it with a different bibliography engine, adapt the hook and build rules together.

Manuscripts retain their own normal `\bibliographystyle{IEEEtran}` and `\bibliography{paper}` declarations. With those declarations, keep `paper.bib` present even if empty; omit the declarations if the manuscript has no bibliography at all. The automatic citation-aware behavior above applies to response letters.

### Build, inspect, and submit the revision

From the publication root, build the manuscripts, comparisons, and all response letters.

To build the revised manuscript, response letters, comparison, and source archive, run the following Bash commands:

```bash
make
make -C reply1 bundle
make -C revised1 zip
```

Inspect `revised1/paper.pdf` (clean manuscript), `revised1/paper-diff.pdf` (marked comparison), and the combined, editor, and individual letters in `reply1/`. Bundles append the comparison to each letter. Submit the files required by the journal; the source archive is `revised1/paper-revised1.zip`. Keep submitted stages unchanged and make further edits in the next round.

For individual build targets, see the [command reference](#make-targets). For optional explanatory covers, see [submission covers](#optional-covers-for-submission-bundles).

### Start subsequent revisions

After submitting round 1 and receiving the next decision, run the **same** root command.

To start the next review round, run the following Bash command from the publication root:

```bash
make new-round
```

It creates `revised2/` from `revised1/` and `reply2/` from `reply1/`. Further invocations create round 3 and onwards; there are no unused rounds at initialization. Metadata, reviewer membership, formatting, and cover preference are inherited. Comment/answer bodies are replaced with useful TODO scaffolds, retaining the prior outer `enumerate`/`itemize` choice. Update the new manuscript ID if the journal changes it. No old submitted folder is modified. An orphaned round or existing destination is an error, rather than permission to overwrite it.

Check the new decision's reviewer IDs before filling responses. Remove reviewers with no report from this round while their new scaffolds are untouched, and add newly assigned reviewers. See [setting reviewers](#set-the-reviewers-for-this-round) and the [worked second round](HOWTO.md#receive-the-second-decision-reviewers-1-3-and-4).

## Guided example: changing reviewers across two rounds

Follow [the complete guided example in HOWTO.md](HOWTO.md) to initialize a fictional publication, answer reviewers 1, 2, and 3 in round 1, then handle reviewers 1, 3, and 4 in round 2. It includes the received emails, completed manuscript and response sources, build and submission commands, and optional round removal/restoration practice.

## Optional operations

### Remove and restore a round

From a publication project's **root**, remove the latest round from the active workflow without discarding its contents.

To archive the latest active round, run the following Bash command:

```bash
make remove-round ROUND=2
```

The complete `revised2/` and `reply2/` folders move into a unique directory such as `.removed-rounds/round2-ABC123/`. The command prints the actual archive name and a ready-to-use restore command. Edited manuscripts, bibliography entries, reviewer answers, removal guards, figures, generated PDFs, and build files are preserved. Archives do not participate in normal builds or reviewer information, and `clean`/`distclean` leave them untouched. Archived sources remain eligible for Git tracking; generated outputs retain their ignore rules. Archiving does not free disk space.

Both targets require an explicit positive `ROUND`; they are unavailable in the protected template clone and are root-only, including direct helper calls. Removal requires the latest complete, consistently configured pair and refuses other active stages that refer to it through `BASELINE` or `REVISION`. Earlier rounds and `original/` remain intact. Source-changing commands must run separately from builds; the helpers wait for existing stage locks before transferring files.

Restore the next round after the highest active round.

To restore the next round, run the following Bash command:

```bash
make restore-round ROUND=2
```

When exactly one archive matches, it is selected automatically. Several archived attempts require an explicit choice; the error lists their names.

To list archived attempts and select one to restore, use the following Bash commands:

```bash
ls -d .removed-rounds/round2-*
make restore-round ROUND=2 ARCHIVE=round2-ABC123
```

`ARCHIVE` is the printed directory basename, not a path. Restoration refuses occupied destination names, missing baseline manuscripts, inconsistent pairs, and symlinked archive/stage directories. Restore archived rounds in order: if rounds 2 and 3 were removed, restore 2 before 3. Build archived documents only after restoring them to their active locations.

After removal, `make new-round` can recreate that round number from the remaining latest manuscript. Its sources are newly initialized; the archived attempt is retained. To return to the previous attempt, first archive the replacement and then restore the desired archive by name. Restoration removes the empty archive container; unrelated files added to that container are retained and reported.

The transfer holds project and stage locks and rolls back a completed first move if the second move fails. If rollback itself fails, the command reports the recovery location and preserves the remaining data. A forced process kill or machine shutdown can leave a partial pair and stale locks. Confirm no operation is running, inspect the active folders and archive, and move only a missing counterpart back to its original location without overwriting any existing folder. Remove stale `.template-lock` directories only after checking their owner PIDs, including locks inside the archive. Retain partial recovery data until both active folders are verified; the normal targets refuse incomplete pairs.

### Worked removal and restoration example

After completing the guided publication, follow [the optional removal and restoration exercise](HOWTO.md#optional-remove-and-restore-the-completed-round). It preserves the completed second round's responses and generated outputs.

### Editor-only revisions

This is a separate branch of the workflow, not a step to run in the completed guided project. In a fresh author project, before filling any reviewer files.

To create an editor-only round, remove the untouched reviewer scaffolds with the following Bash commands:

```bash
make new-round
make remove-reviewer ROUND=1 REVIEWER=1
make remove-reviewer ROUND=1 REVIEWER=2
make info-reviewer
# Fill editor-comments.tex and metadata.tex, then:
make
make -C reply1 bundle
```

The combined document addresses the editor, and subsequent rounds retain zero reviewers unless you add one.

### Optional covers for submission bundles

A bundle normally contains the letter followed by the matching manuscript comparison. To add an explanatory cover before each letter.

To prepend covers to the response bundles, run the following Bash command:

```bash
make -C reply1 bundle COVER=1
```

Set `COVER := 1` in the reply Makefile for a persistent default; a command-line `COVER=0` overrides it. The cover uses the same title, authors, and manuscript ID as the letters. Plain letters remain available separately.

## Command and file reference

### Folder layout and file roles

The following plain-text overview shows the project folder layout:

```text
original/                    Submitted manuscript: paper.tex, paper.bib
revised1/, revised2/, ...     Complete manuscript sources for each round
reply1/, reply2/, ...         Response letters for the matching round
support/                     Shared Make rules, Bash helpers, letter scaffolds
  walkthrough/               Fictional, ready-to-copy guided example assets
tests/                       Bash integration tests and independent fixtures
```

Each `revisedN/Makefile` declares its `BASELINE` and `replyN/Makefile` its `REVISION`. The defaults compare `revised1` with `original`, then `revisedN` with `revised(N-1)`. Keep `paper.tex`/`paper.bib` in every manuscript stage; this avoids selecting comparison files by ad hoc names. The comparison is always `revisedN/paper-diff.pdf`. Generated names, including stage-root `paper-<folder>.zip`, are reserved for build outputs; place PDF figures in a subdirectory such as `figures/`.

### Make targets

| Command | Result |
| --- | --- |
| `make help` | Available targets and options |
| `make docs` | Numbered, syntax-highlighted README.pdf and HOWTO.pdf |
| `make README.pdf` or `make HOWTO.pdf` | Build one guide PDF |
| `make check-tools` | Check required build tools |
| `make init-project DEST=../my-paper` | Create an independent publication project |
| `make new-round` | Create the next manuscript and response stage |
| `make add-reviewer ROUND=1` | Add the next reviewer; use `REVIEWER=4` for an explicit ID |
| `make remove-reviewer ROUND=1 REVIEWER=4` | Remove an untouched reviewer scaffold |
| `make info-reviewer` | Show all rounds; use `ROUND=1` to select one |
| `make` or `make all` | All manuscripts, comparisons, combined/editor/individual letters |
| `make -C original` | Original manuscript only |
| `make -C revised1 paper` | Revised manuscript only |
| `make -C revised1 diff` | Comparison against the configured baseline |
| `make -C reply1 responses` | Combined letter |
| `make -C reply1 editor` | Editor letter |
| `make -C reply1 reviewer2` | Reviewer 2 letter |
| `make remove-round ROUND=2` | Archive the latest active round (publication root only) |
| `make restore-round ROUND=2` | Restore the next round; select `ARCHIVE=name` if ambiguous |
| `make bundle` | All round-specific letters with the matching comparison appended |
| `make -C reply1 bundle COVER=1` | This round's bundles, with an explanatory cover before each letter |
| `make zip` | Standalone source archives beside each manuscript's paper.tex |
| `make clean` | Remove auxiliaries; retain generated PDFs and ZIP archives |
| `make distclean` | Remove generated outputs; preserve source figures and reviewer guards |
| `make test` | Bash integration suite, including the executable HOWTO example |

### Comparison baselines and included files

Use a literal integer reviewer list and literal relative baseline/revision paths in the thin stage Makefiles. Management helpers read these declarations directly; do not replace them with computed Make expressions. To compare against a different submitted stage temporarily, use `make -C revised2 diff BASELINE=../original`; restore the usual comparison for bundles, or change the stage's `BASELINE` declaration deliberately. All manuscript dependencies must remain inside their stage for standalone source archives.

Comparisons start from `paper.tex` in each selected stage. The helper builds both manuscripts, expands their literal `\input{...}` sources with `latexpand`, inserts each compiled bibliography, and runs `latexdiff` on the expanded documents. Changes in included sections and rendered bibliography entries therefore appear in `paper-diff.pdf`. An omitted inactive conditional input can produce a flattening warning; its input command is retained and skipped by TeX. Missing active inputs fail the required manuscript build before comparison.

### Manuscript dependency copying and source archives

To select manuscript files, `new-round` runs latexmk on the preceding manuscript and exports its source dependencies into `build/paper.deps`. The manuscript lock covers both the build and copying. The helper reads latexmk's documented dependency export, including dependencies of BibTeX, and preserves the relative paths of required stage-local files: nested TeX inputs, figures (including PDF figures), local classes/packages, bibliography databases, and bibliography styles. Installed TeX files are identified through Kpathsea's TeX installation roots and supplied by the author's TeX installation.

Latexmk removes known generated files from its source dependency export. The existing `paper.bib` is always copied in full, even if only the rebuttal will cite its entries. The manuscript Makefile is regenerated with the new baseline. Required source dependencies inside `build/` or other generated/transient directories, source symlinks, missing dependencies, and required files outside the manuscript stage and TeX installation cause a clear error. Build or validation failure publishes neither new round folder; it can update generated outputs of the preceding manuscript.

Only dependencies used by the active build are selected. Unused assets, unreferenced notes, empty directories, and inactive conditional inputs are omitted; copy such files manually if you need them for later edits. Selection does not depend on Git tracking or `.gitignore`. Required dependencies can be copied even when their names match an ignore rule. Keep manuscript dependencies stage-local and avoid reserved output names for source assets.

Manuscript source ZIPs use the same dependency collector. Archives are named `paper-<folder>.zip`, for example `original/paper-original.zip` and `revised2/paper-revised2.zip`. The ignore rules include applicable LaTeX intermediates, package caches, editor backups, and operating-system metadata adapted from the thesis template. Figure/source formats such as `.pdf`, `.eps`, `.svg`, `.tikz`, `.ist`, `.xdy`, `.mp`, and `.mf` remain trackable. Ignore rules do not grant permission to delete files; `clean` and `distclean` retain their existing source-preserving behavior.

### Build behavior and reproducibility

`make check-tools` checks the tools; `make help` works without TeX or Bash. Every stage has its own help target. Builds use latexmk's dependency tracking and project-owned configuration, ignoring personal latexmk configuration. PDFs and manuscript source ZIPs (`paper-<folder>.zip`) sit beside their TeX sources; auxiliaries, expanded sources, and generated bibliography/configuration files stay in each stage's `build/`. An unchanged comparison does not rebuild its PDF. Sources, citations, and bibliography dependencies are followed automatically. Undefined citations/references and missing bibliography entries fail the build.

Tool versions can differ between installations, and PDF timestamps can vary across clean builds. Byte-for-byte reproducible PDFs across machines are not promised.

### Protection, cleanup, and interrupted operations

The template clone's root Makefile declares `PROJECT_ROLE := template`. It refuses `new-round`, `remove-round`, `restore-round`, `add-reviewer`, and `remove-reviewer` so an accidental workflow command cannot change the demonstration's stages or reviewer membership. `init-project` automatically writes `PROJECT_ROLE := publication` into the new project's root Makefile, enabling those commands there. No separate marker file or manual activation step is needed.

The shared Bash helpers read the declaration directly from the root Makefile before creating locks, temporary directories, or changing sources. The check applies at the root, inside `replyN/`, and to direct helper calls. Command-line or environment assignments such as `make new-round PROJECT_ROLE=publication` do not bypass it. A missing or invalid declaration also refuses source-changing commands.

Initialization, builds, comparisons, bundles, archives, tests, help, and reviewer information remain available in the template clone. `clean` and `distclean` remain available too: they remove generated outputs while preserving source files and reviewer safety records. This protects the supplied workflow against mistakes; it does not prevent deliberate manual edits or filesystem deletion. Keep the role declaration literal and retain the template role in the clone.

Reviewer removal succeeds only while **both** the wrapper and comments files are byte-identical to their recorded generated scaffolds. Edited answers, edited wrappers, populated demonstrations, or missing provenance cause a refusal without changing membership. There is no force-removal option. Persistent `.reviewer-scaffolds/` directories contain source baseline copies used by `cmp`, must be tracked in Git, and survive `clean`/`distclean`. A customized wrapper remains protected in subsequent rounds; new comment scaffolds in those rounds get their own baseline. Review an accidental edit and restore the untouched source only if you truly intend to discard it; do not delete safety records to bypass protection.

`make -j4` is supported. Helpers serialize operations on the same stage; independent stages can build concurrently. Do not edit sources while a build or stage-management operation is running. A `.template-lock` directory normally disappears automatically. If a process is killed forcibly, check its `owner` PID and confirm no operation is running before removing that stale lock directory and retrying.

## Why I keep complete stage folders

I deliberately duplicate manuscript sources when creating a revision instead of relying only on Git tags and history. A review round is a concrete submission package: the manuscript, bibliography, response letters, and comparison baseline must be visible together. Separate folders let me build old and new submissions side by side, inspect exactly what was sent, and share a round with a collaborator who does not need to understand Git checkout mechanics. The revision's bibliography also remains the exact database used by both its manuscript and its replies.

Git history is still valuable for the work inside each stage; I use commits or tags to mark submissions as well. Tags alone require checking out several revisions or using worktrees to compare or build them simultaneously, and can make it easier to compare against an unintended state. Explicit folders make the baseline a reviewable declaration in each Makefile.

The tradeoffs are extra storage, duplicated files, and the risk of editing an older submitted stage by mistake. I accept that cost for a small paper project. I freeze submitted folders, edit only the active round, keep stage-local assets, and use the generated comparison to review changes. Large binary data should be managed separately with an explicit reproducible source rather than copied into every round. Shared build helpers remain centralized; submitted manuscript sources stay complete within each stage.

## Validation and license

`make test` checks optional documentation rendering when Pandoc is installed (numbering, highlighting, incremental builds, missing-tool errors, and cleanup), then exercises manuscript builds with Python invocation blocked, paths containing spaces, dependency-based copying of nested inputs and local styles, refreshed dependency graphs, preservation of the shared bibliography, omission of unused assets, source-safe ignore rules, incremental text/bibliography changes, citation-free and citing letters, project-role and reviewer protections, round archiving/restoration and failed-transfer recovery, editor-only rounds, covers and metadata, independent ZIP extraction, cleanup, and both complete HOWTO review rounds. HOWTO code/assets and received-comment wording are checked against the supplied walkthrough files. The tests also run from an initialized author project. The template and fictional examples are distributed under the MIT license; IEEEtran remains subject to its own license.
