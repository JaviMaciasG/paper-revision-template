# Generic Manuscript and Rebuttal Template

## Introduction

The repo contains a reusable template to handle the paper publication and, mainly, paper revision processes across review rounds.


## Motivation

I created this repository because I was tired of the manual work involved in handling paper revisions. The process often repeats: 

1. Submit a manuscript and wait...
2. Receive comments from the editor and reviewers, hopefully with a major/minor revision decision
3. Prepare rebuttal letter(s) and a revised manuscript
4. Submit again and wait...
5. Possibly receive another set of minor/major revision comments and start again.

Each round involves more than editing the paper. You need to keep the previously submitted version, prepare the next version, answer every comment, and generate a document showing the differences between the two manuscripts. Depending on the journal, you may also need a single response letter covering all reviewers, separate letters for individual reviewers, or a letter for the editor.

The reviewers can change between rounds, and so can their number. I wanted a system that could handle these changes while keeping each round's manuscript, response letters, bibliography, and comparison together.

This template tries to automate the repetitive preparation and build tasks. It creates new review rounds, provides structured response files, builds combined and individual rebuttal letters, and generates the revised manuscript and its marked comparison with the preceding submission. The objective is letting me spend more time addressing the comments and improving the paper.

## Getting Started

### Requirements

Use GNU Make, Bash 3.2 or newer, and ordinary Unix utilities on Linux/macOS. Install TeX Live with pdfLaTeX, BibTeX, IEEEtran, latexmk, latexpand, and latexdiff. Source archives require `zip` and `unzip`; bundles require either Poppler's `pdfunite` or Ghostscript (`gs`). The integration tests also use `pdfinfo`/`pdftotext` when available, with Ghostscript fallbacks. Native Windows users can use WSL. No Python interpreter, pip packages, or Python helper scripts are required.

Run `make check-tools` from the clone to check your installation. `make help` works without TeX; each stage also has a help target.

### Daily Commands

Run these commands from the indicated project root. PDFs and manuscript ZIPs appear beside their stage's TeX sources.

| Task | Command |
| --- | --- |
| Create a publication project from the template clone | `make init-project DEST=../my-paper` |
| Check rounds, reviewer IDs, outputs, and TODOs | `make status` |
| Build the original or latest revision and plain letters | `make current` |
| Start a round with the decision's reviewer IDs | `make new-round REVIEWERS="1 2 3"` |
| Prepare the latest submission's PDFs, bundles, and source ZIP | `make submission` |
| Prepare a particular submitted round | `make submission ROUND=1` |
| Preview an infrastructure update from the template clone | `make update-project DEST=../my-paper` |
| Apply that update after reviewing its preview | `make update-project DEST=../my-paper APPLY=1` |

`current`, `status`, and `submission` are root commands. Before any review rounds, `current` builds the original and `submission` also creates its source ZIP. With review rounds, they select the highest numeric active round. `make` still builds **all** stages; it remains useful when you deliberately want to rebuild earlier submissions. For a complete exercise, use [HOWTO.md](HOWTO.md).

### Build PDF Copies of the Guides

To read or share this README and the guided example as PDFs, install Pandoc in addition to the existing latexmk/pdfLaTeX tools and TeX Live packages (`fvextra`, `xurl`, `xcolor`, `lmodern`, `booktabs`, `longtable`, `hyperref`, `etoolbox`, `needspace`, `tcolorbox`, and `tocloft`). These are normally supplied by the LaTeX-extra and fonts-recommended packages. No separate syntax-highlighting executable or Python interpreter is needed.

To generate the PDF guides, run the following Bash commands from the project root:

```bash
make docs
# Or build only one guide:
make README.pdf
make HOWTO.pdf
```

### Template Clone versus Publication Project

The clone contains a populated demonstration, described below. Source-changing management targets are disabled there to protect the example. Use `init-project` to create an independent, editable publication project. Details are in [protection and cleanup](#protection-cleanup-and-interrupted-operations).

### Explore the Supplied Example

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

### Create Your Publication Project

Clone this repository, then create an author project outside the clone.

To initialize your publication project, run the following Bash commands:

```bash
make init-project DEST=../my-paper
cd ../my-paper
make help
```

The new project contains the build system, documentation, examples, and a minimal `original/paper.tex` and `original/paper.bib`. It has no review rounds and no Git history. **Replace both files with your real manuscript and bibliography**, keeping these filenames. The starter itself gives these instructions. See [preparing the original manuscript](#prepare-and-submit-the-original-manuscript) for where to put your sources.

## The Publication Workflow

### Prepare and Submit the Original Manuscript

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

### Start the First Revision

From an initialized publication project's root, after receiving the first decision.

To create the first review round, run the following Bash command from the publication root:

```bash
make new-round REVIEWERS="1 2 3"
```

This builds `original/paper.tex`, copies its manuscript dependencies into `revised1/`, and creates `reply1/` from the response scaffold, with the specified reviewers plus the editor. Omitting `REVIEWERS` starts the first round with reviewers 1 and 2. The required build tools must be installed before creating a round. See the following steps to configure reviewers, edit sources, and build the submission.

### Set the Reviewers for This Round

There is no fixed reviewer limit. Specify membership during creation with `make new-round REVIEWERS="1 2 3"`, or omit it to use the first-round defaults of 1 and 2 and later inherit the preceding round's IDs. `make new-round REVIEWERS=""` creates an editor-only round. IDs must be distinct positive integers; spaces separate them, and their order determines letter order. Add/remove targets remain available to adjust membership after creation. The editor is always separate and does not count as a reviewer. The `REVIEWERS` list in the round's Makefile is authoritative. Numbers remain stable when another reviewer is removed; gaps are allowed. Prefer the targets to manual changes so membership, generated inputs, sources, and safety records remain consistent.

The following example assumes round 1 was created with reviewers 1, 2, and 3. To add, remove, or inspect reviewers, use these Bash commands from the indicated folders:

```bash
# From the project root:
make add-reviewer ROUND=1                 # next unused number after the highest ID
make remove-reviewer ROUND=1 REVIEWER=4  # remove it while untouched
make add-reviewer ROUND=1 REVIEWER=5      # explicit journal reviewer number
make remove-reviewer ROUND=1 REVIEWER=5
make info-reviewer                       # every review round, counts and IDs
make info-reviewer ROUND=1

# From reply1/: these affect round 1 automatically:
cd reply1
make add-reviewer
make remove-reviewer REVIEWER=4
make info-reviewer
cd ..
```

`REVIEWER` is optional for adding and required for removing. At the root, add/remove require `ROUND`; in `replyN`, an explicitly conflicting `ROUND` is rejected. `info-reviewer` reports the current round inside a reply folder, and all rounds at the root. With no rounds it reports the original-only status; missing configured sources are errors.

The file roles are explained under [response files and formatting](#response-files-and-formatting).

Removal succeeds only while both the wrapper and comments file match their generated scaffolds. Configure membership before filling answers; populated files are protected. See [protection and cleanup](#protection-cleanup-and-interrupted-operations) for details.

### Revise the Manuscript and Write Responses

Edit the current `revisedN/paper.tex`, included sources, and `revisedN/paper.bib`. Fill `replyN/metadata.tex`, `editor-comments.tex`, and each configured `reviewerX-comments.tex`. Keep the previously submitted stages unchanged.

#### Response Files and Formatting

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

#### References in Response Letters

Each round's response letters use **the same `revisedN/paper.bib` as its revised manuscript**. Do not create a separate reply bibliography. Add a reply-only entry to that file if needed; the manuscript will not list it unless cited there. Use normal `\cite{key}` or `\nocite{key}` in replies, including included TeX files. `\nocite{*}` deliberately selects every database entry.

Bibliography declarations are inserted automatically at the end of a letter only when a citation or `\nocite` actually executes. Comments containing `\cite` do not trigger bibliography processing. A citation-free letter compiles without a bibliography, even with an empty or absent database; a citing letter requires a valid database and keys. Each individual letter gets its own cited subset; the combined letter gets the union of its executed citations. Adding/removing the last citation and changing `paper.bib` are handled by latexmk. The hook supports the template's standard LaTeX citation setup; if you replace it with a different bibliography engine, adapt the hook and build rules together.

Manuscripts retain their own normal `\bibliographystyle{IEEEtran}` and `\bibliography{paper}` declarations. With those declarations, keep `paper.bib` present even if empty; omit the declarations if the manuscript has no bibliography at all. The automatic citation-aware behavior above applies to response letters.

### Check Progress

To inspect the project without compiling documents, run the following Bash command:

```bash
make status
```

The report shows project role, active rounds, the latest round, baselines, reviewer IDs, and whether each expected PDF and ZIP exists. It also lists literal `TODO` occurrences in manuscript and response TeX/BibTeX sources, excluding `build/` and pristine scaffold copies. Check each occurrence: a macro definition or reminder can also match. The report does not determine whether outputs are current, validate scientific content, or certify submission readiness. No TeX installation or Git repository is needed for this report. Missing stage pairs, manuscript sources, configured reviewer files, or comparison baselines are errors.

### Build, Inspect, and Submit the Revision

To build the latest manuscript, comparison, and all its plain response letters, then prepare its submission files, run the following Bash commands from the publication root:

```bash
make current
make submission
# Select an earlier round explicitly, or override its cover setting:
make submission ROUND=1 COVER=1
```

`submission` builds the clean manuscript, comparison, combined/editor/individual letters, bundles with the comparison appended, and the manuscript source ZIP. It respects the round's `COVER` setting unless overridden. Files stay in `revisedN/` and `replyN/`; the command prints their paths after success. It does not upload files or create a separate delivery folder. With no rounds, it builds `original/paper.pdf` and `original/paper-original.zip` instead. `ROUND` must identify an existing positive-numbered round when supplied.

Inspect the generated files and submit those required by the journal. Keep submitted stages unchanged and make further edits in the next round. `make current` does not rebuild unrelated earlier stages, but building a comparison may rebuild its baseline manuscript if necessary.

For example, the folder-level alternatives for round 1 are the following Bash commands:

```bash
make -C revised1
make -C reply1
make -C reply1 bundle
make -C revised1 zip
```

For individual targets, see the [command reference](#make-targets). For optional explanatory covers, see [submission covers](#optional-covers-for-submission-bundles).

### Start Subsequent Revisions

After submitting round 1 and receiving the next decision, run the **same** root command.

To start the next review round, run the following Bash command from the publication root:

```bash
make new-round
```

It creates `revised2/` from `revised1/` and `reply2/` from `reply1/`. Further invocations create round 3 and onwards; there are no unused rounds at initialization. Metadata, reviewer membership, formatting, and cover preference are inherited unless `REVIEWERS` is explicitly supplied. Newly selected reviewer IDs receive standard wrappers and fresh comment scaffolds; retained reviewers preserve their wrappers and outer list style. Comment/answer bodies are replaced with useful TODO scaffolds, retaining the prior outer `enumerate`/`itemize` choice. Update the new manuscript ID if the journal changes it. No old submitted folder is modified. An orphaned round or existing destination is an error, rather than permission to overwrite it.

Check the new decision's reviewer IDs before creation: for example, `make new-round REVIEWERS="1 3 4"` excludes reviewer 2 from the new round and adds reviewer 4 while retaining reviewers 1 and 3. Omitted IDs are excluded only from the newly created stage. If you inherit membership instead, remove reviewers with no report while their new scaffolds are untouched and add newly assigned reviewers. See [setting reviewers](#set-the-reviewers-for-this-round) and the [worked second round](HOWTO.md#round-2-receiving-the-second-decision-reviewers-1-3-and-4).

## Guided Example (HOWTO)

Follow [the complete guided example in HOWTO.md](HOWTO.md) to initialize a fictional publication, answer reviewers 1, 2, and 3 in round 1, then handle reviewers 1, 3, and 4 in round 2. It includes the received emails, completed manuscript and response sources, build and submission commands, and optional round removal/restoration practice.

## Optional Operations

### Remove and Restore a Round

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

### Worked Removal and Restoration Example

After completing the guided publication, follow [the optional removal and restoration exercise](HOWTO.md#optional-removing-and-restoring-the-completed-round). It preserves the completed second round's responses and generated outputs.

### Editor-Only Revisions

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

### Update an Existing Publication Project

Use a local template checkout containing the desired update. Updates require neither Git nor network access, and source files do not need to be committed first. The source checkout must have the template role and the destination must have the publication role. The two directories must be outside each other.

To preview and apply an update from the template clone, run the following Bash commands:

```bash
make update-project DEST=../my-paper
# Review the proposed replacements and any conflicts, then apply:
make update-project DEST=../my-paper APPLY=1
```

Newly initialized or successfully upgraded publication projects also provide the following Bash commands:

```bash
make update-template FROM=/path/to/paper-revision-template
make update-template FROM=/path/to/paper-revision-template APPLY=1
make status
make current
```

The preview changes no project files. Application backs up affected files under `.template-update/backups/update-<timestamp>-XXXXXXXX/`, replaces recognized infrastructure, and records a managed-file checksum manifest in `.template-update/manifest`. Commit that manifest with your project sources if using Git; backups are ignored. The manifest is only update bookkeeping: the literal role in the root Makefile remains the authority for protected operations.

Manuscript stages, response sources, metadata, reviewer membership, archived rounds, and LICENSE are preserved. Unmodified guides can be updated. Customized README/HOWTO files are retained, with incoming versions in the backup's `incoming/` directory for comparison. Existing ignore rules are retained; the updater adds its backup exclusion. Compare the template `.gitignore` manually for any other new rules.

The updater supports pristine projects initialized from template commit `6f956cd`, using a bundled baseline to migrate their root Makefile and helpers. Use the **template-side** command for this first upgrade: their old Makefile has no `update-template` target. New projects record their baseline automatically. Modified or unrecognized infrastructure, including a customized root Makefile or deleted managed file, stops the update before replacement. Reconcile conflicts manually against the incoming template, then preview again. Keep the publication role when reconciling Makefiles. No force option overwrites customizations.

Application waits for project/stage locks and rolls back replaced files on failure. For manual recovery after a completed update, stop all builds, read the backup's `actions.tsv`, restore paths marked `restore` from its `old/` directory, and remove only paths marked `delete`. Restore the saved manifest as well. Preserve the backup until satisfied with the update, and review infrastructure changes before committing them.

### Optional Covers for Submission Bundles

A bundle normally contains the letter followed by the matching manuscript comparison. To add an explanatory cover before each letter.

To prepend covers to the response bundles, run the following Bash command:

```bash
make -C reply1 bundle COVER=1
```

Set `COVER := 1` in the reply Makefile for a persistent default; a command-line `COVER=0` overrides it. The cover uses the same title, authors, and manuscript ID as the letters. Plain letters remain available separately.

## Command and File Reference

### Folder Layout and File Roles

The following plain-text overview shows the project folder layout:

```text
original/                    Submitted manuscript: paper.tex, paper.bib
revised1/, revised2/, ...     Complete manuscript sources for each round
reply1/, reply2/, ...         Response letters for the matching round
support/                     Shared root/stage Make rules, Bash helpers, letter scaffolds
  walkthrough/               Fictional, ready-to-copy guided example assets
tests/                       Bash integration tests and independent fixtures
```

Each `revisedN/Makefile` declares its `BASELINE` and `replyN/Makefile` its `REVISION`. The defaults compare `revised1` with `original`, then `revisedN` with `revised(N-1)`. Keep `paper.tex`/`paper.bib` in every manuscript stage; this avoids selecting comparison files by ad hoc names. The comparison is always `revisedN/paper-diff.pdf`. Generated names, including stage-root `paper-<folder>.zip`, are reserved for build outputs; place PDF figures in a subdirectory such as `figures/`.

### Make Targets

| Command | Result |
| --- | --- |
| `make help` | Available targets and options |
| `make docs` | Numbered, syntax-highlighted README.pdf and HOWTO.pdf |
| `make README.pdf` or `make HOWTO.pdf` | Build one guide PDF |
| `make check-tools` | Check required build tools |
| `make init-project DEST=../my-paper` | Create an independent publication project |
| `make new-round [REVIEWERS="1 3 4"]` | Create the next round; omit membership to inherit it, or use `REVIEWERS=""` for editor-only |
| `make status` | Show rounds, baselines, reviewer IDs, output presence, and source TODO locations |
| `make current` | Build the original or latest revised manuscript, comparison, and plain letters |
| `make submission [ROUND=2] [COVER=1]` | Prepare one submission in its existing stage folders |
| `make update-project DEST=../my-paper [APPLY=1]` | Preview/apply an update from the template checkout |
| `make update-template FROM=/path/to/template [APPLY=1]` | Preview/apply an update from an upgraded publication project |
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
| `make clean` | Remove auxiliaries in build/ and beside known document sources; retain PDFs and ZIP archives |
| `make distclean` | Remove generated outputs; preserve source figures and reviewer guards |
| `make test` | Bash integration suite, including the executable HOWTO example |

### Comparison Baselines and Included Files

Use a literal integer reviewer list and literal relative baseline/revision paths in the thin stage Makefiles. Management helpers read these declarations directly; do not replace them with computed Make expressions. To compare against a different submitted stage temporarily, use `make -C revised2 diff BASELINE=../original`; restore the usual comparison for bundles, or change the stage's `BASELINE` declaration deliberately. All manuscript dependencies must remain inside their stage for standalone source archives.

Comparisons start from `paper.tex` in each selected stage. The helper builds both manuscripts, expands their literal `\input{...}` sources with `latexpand`, inserts each compiled bibliography, and runs `latexdiff` on the expanded documents. Changes in included sections and rendered bibliography entries therefore appear in `paper-diff.pdf`. An omitted inactive conditional input can produce a flattening warning; its input command is retained and skipped by TeX. Missing active inputs fail the required manuscript build before comparison.

### Manuscript Dependency Copying and Source Archives

To select manuscript files, `new-round` runs latexmk on the preceding manuscript and exports its source dependencies into `build/paper.deps`. The manuscript lock covers both the build and copying. The helper reads latexmk's documented dependency export, including dependencies of BibTeX, and preserves the relative paths of required stage-local files: nested TeX inputs, figures (including PDF figures), local classes/packages, bibliography databases, and bibliography styles. Installed TeX files are identified through Kpathsea's TeX installation roots and supplied by the author's TeX installation.

Latexmk removes known generated files from its source dependency export. New revision rounds always copy the existing `paper.bib` in full, even if only the rebuttal will cite its entries. The manuscript Makefile is regenerated with the new baseline. Required source dependencies inside `build/` or other generated/transient directories, source symlinks, missing dependencies, and required files outside the manuscript stage and TeX installation cause a clear error. Build or validation failure publishes neither new round folder; it can update generated outputs of the preceding manuscript.

Only dependencies used by the active build are selected. Unused assets, unreferenced notes, empty directories, and inactive conditional inputs are omitted; copy such files manually if you need them for later edits. Selection does not depend on Git tracking or `.gitignore`. Required dependencies can be copied even when their names match an ignore rule. Keep manuscript dependencies stage-local and avoid reserved output names for source assets.

Manuscript source ZIPs include only the stage-local files required by the successful compilation, selected through the same dependency collector, plus one self-contained `Makefile`. No README, separate LICENSE, shared scripts, or configuration files are added; a file with one of these names is retained only if the manuscript actually reads it. Unlike revision snapshots, ZIPs include `paper.bib` only when it is a compilation dependency; its complete contents are preserved when included. The Makefile embeds the template's MIT notice and the latexmk/pdfLaTeX settings, so extracted sources compile with `make` without the template repository. It provides `all`, `paper`, `help`, `clean`, and `distclean`; `paper.pdf` appears beside `paper.tex` and auxiliaries stay under `build/`. Archives are named `paper-<folder>.zip`, for example `original/paper-original.zip` and `revised2/paper-revised2.zip`. The ignore rules include applicable LaTeX intermediates, package caches, editor backups, and operating-system metadata adapted from the thesis template. Figure/source formats such as `.pdf`, `.eps`, `.svg`, `.tikz`, `.ist`, `.xdy`, `.mp`, and `.mf` remain trackable. Ignore rules do not grant permission to delete files; `clean` and `distclean` remove generated auxiliaries both under `build/` and beside known document sources (including `.aux`, `.bbl`, `.blg`, `.log`, and `.out` from manual or older builds). Cleanup uses reserved document names, rather than deleting every file with an auxiliary-looking extension; unrelated source assets are preserved.

### Build Behavior and Reproducibility

`make check-tools` checks the tools; `make help` works without TeX or Bash. Every stage has its own help target. Builds use latexmk's dependency tracking and project-owned configuration, ignoring personal latexmk configuration. PDFs and manuscript source ZIPs (`paper-<folder>.zip`) sit beside their TeX sources; auxiliaries, expanded sources, and generated bibliography/configuration files stay in each stage's `build/`. An unchanged comparison does not rebuild its PDF. Sources, citations, and bibliography dependencies are followed automatically. Undefined citations/references and missing bibliography entries fail the build.

Tool versions can differ between installations, and PDF timestamps can vary across clean builds. Byte-for-byte reproducible PDFs across machines are not promised.

### Protection, Cleanup, and Interrupted Operations

Root targets are defined in `support/root.mk`; the thin root Makefile retains project configuration and role. The template clone's root Makefile declares `PROJECT_ROLE := template`. It refuses `new-round`, `remove-round`, `restore-round`, `add-reviewer`, and `remove-reviewer` so an accidental workflow command cannot change the demonstration's stages or reviewer membership. `init-project` automatically writes `PROJECT_ROLE := publication` into the new project's root Makefile, enabling those commands there. No separate marker file or manual activation step is needed.

The shared Bash helpers read the declaration directly from the root Makefile before creating locks, temporary directories, or changing sources. The check applies at the root, inside `replyN/`, and to direct helper calls. Command-line or environment assignments such as `make new-round PROJECT_ROLE=publication` do not bypass it. A missing or invalid declaration also refuses source-changing commands. The updater likewise refuses template-role destinations; its checksum manifest cannot grant publication permissions.

Initialization, builds, comparisons, bundles, archives, tests, help, and reviewer information remain available in the template clone. `clean` and `distclean` remain available too: they remove generated outputs while preserving source files and reviewer safety records. This protects the supplied workflow against mistakes; it does not prevent deliberate manual edits or filesystem deletion. Keep the role declaration literal and retain the template role in the clone.

Reviewer removal succeeds only while **both** the wrapper and comments files are byte-identical to their recorded generated scaffolds. Edited answers, edited wrappers, populated demonstrations, or missing provenance cause a refusal without changing membership. There is no force-removal option. Persistent `.reviewer-scaffolds/` directories contain source baseline copies used by `cmp`, must be tracked in Git, and survive `clean`/`distclean`. A customized wrapper remains protected in subsequent rounds; new comment scaffolds in those rounds get their own baseline. Review an accidental edit and restore the untouched source only if you truly intend to discard it; do not delete safety records to bypass protection.

`make -j4` is supported. Helpers serialize operations on the same stage; independent stages can build concurrently. Do not edit sources while a build or stage-management operation is running. A `.template-lock` directory normally disappears automatically. If a process is killed forcibly, check its `owner` PID and confirm no operation is running before removing that stale lock directory and retrying.

## Rationale for Folder Duplication

I deliberately duplicate manuscript sources when creating a revision instead of relying only on Git tags and history. A review round is a concrete submission package: the manuscript, bibliography, response letters, and comparison baseline must be visible together. Separate folders let me build old and new submissions side by side, inspect exactly what was sent, and share a round with a collaborator who does not need to understand Git checkout mechanics. The revision's bibliography also remains the exact database used by both its manuscript and its replies.

Git history is still valuable for the work inside each stage; I use commits or tags to mark submissions as well. Tags alone require checking out several revisions or using worktrees to compare or build them simultaneously, and can make it easier to compare against an unintended state. Explicit folders make the baseline a reviewable declaration in each Makefile.

The tradeoffs are extra storage, duplicated files, and the risk of editing an older submitted stage by mistake. I accept that cost for a small paper project. I freeze submitted folders, edit only the active round, keep stage-local assets, and use the generated comparison to review changes. Large binary data should be managed separately with an explicit reproducible source rather than copied into every round. Shared build helpers remain centralized; submitted manuscript sources stay complete within each stage.
