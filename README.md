# IEEE manuscript and rebuttal template

A reusable paper project with explicit submitted manuscripts and review rounds. The example IEEE paper is a short manual; its first revision demonstrates text changes and reference corrections, additions, and deletions. All names, results, and references in the examples are fictional.

## Start a real publication

Clone this repository, then create an author project outside the clone:

```bash
make init-project DEST=../my-paper
cd ../my-paper
make help
```

The new project contains the build system, documentation, examples, and a minimal `original/paper.tex` and `original/paper.bib`. It has no review rounds and no Git history. **Replace both files with your real manuscript and bibliography**, keeping these filenames. The starter itself gives these instructions. Put included TeX files, figures, and other dependencies inside `original/`; avoid dependencies outside the project. Update the title and authors in the manuscript. Use your publication's required IEEE options and packages.

```bash
make check-tools
make original
make -C original zip
# Optionally start independent version control:
git init
git add .
git commit -m 'Initial submitted manuscript'
```

Submit `original/paper.pdf`, then treat the sources in `original/` as the submitted snapshot. To explore the template's already populated example instead, run `make`, `make bundle`, or `make zip` directly in the clone. Use `init-project` for your own publication rather than overwriting that demonstration.

## Template protection

The template clone's root Makefile declares `PROJECT_ROLE := template`. It refuses `new-round`, `add-reviewer`, and `remove-reviewer` so an accidental workflow command cannot change the demonstration's stages or reviewer membership. `init-project` automatically writes `PROJECT_ROLE := publication` into the new project's root Makefile, enabling those commands there. No separate marker file or manual activation step is needed.

The shared Bash helpers read the declaration directly from the root Makefile before creating locks, temporary directories, or changing sources. The check applies at the root, inside `replyN/`, and to direct helper calls. Command-line or environment assignments such as `make new-round PROJECT_ROLE=publication` do not bypass it. A missing or invalid declaration also refuses source-changing commands.

Initialization, builds, comparisons, bundles, archives, tests, help, and reviewer information remain available in the template clone. `clean` and `distclean` remain available too: they remove generated outputs while preserving source files and reviewer safety records. This protects the supplied workflow against mistakes; it does not prevent deliberate manual edits or filesystem deletion. Keep the role declaration literal and retain the template role in the clone.

## Requirements and reproducible builds

Use GNU Make, Bash 3.2 or newer, and ordinary Unix utilities on Linux/macOS. Install TeX Live with pdfLaTeX, BibTeX, IEEEtran, latexmk, latexpand, and latexdiff. Source archives require `zip` and `unzip`; bundles require either Poppler's `pdfunite` or Ghostscript (`gs`). The integration tests also use `pdfinfo`/`pdftotext` when available, with Ghostscript fallbacks. Native Windows users can use WSL. No Python interpreter, pip packages, or Python helper scripts are required.

`make check-tools` checks the tools; `make help` works without TeX or Bash. Every stage has its own help target. Builds use latexmk's dependency tracking and project-owned configuration, ignoring personal latexmk configuration. PDFs sit beside their TeX sources; auxiliaries, expanded sources, and generated bibliography/configuration files stay in each stage's `build/`. An unchanged comparison does not rebuild its PDF. Sources, citations, and bibliography dependencies are followed automatically. Undefined citations/references and missing bibliography entries fail the build.

GitHub Actions installs the build tools directly on its Ubuntu runner and executes the same Make targets used locally. Tool versions can differ between installations, and PDF timestamps can vary across clean builds. Byte-for-byte reproducible PDFs across machines are not promised.

## Layout and everyday commands

```text
original/                    Submitted manuscript: paper.tex, paper.bib
revised1/, revised2/, ...     Complete manuscript sources for each round
reply1/, reply2/, ...         Response letters for the matching round
support/                     Shared Make rules, Bash helpers, letter scaffolds
  walkthrough/               Fictional, ready-to-copy guided example assets
tests/                       Bash integration tests and independent fixtures
```

Each `revisedN/Makefile` declares its `BASELINE` and `replyN/Makefile` its `REVISION`. The defaults compare `revised1` with `original`, then `revisedN` with `revised(N-1)`. Keep `paper.tex`/`paper.bib` in every manuscript stage; this avoids selecting comparison files by ad hoc names. The comparison is always `revisedN/paper-diff.pdf`. Generated names are reserved for build outputs; place PDF figures in a subdirectory such as `figures/`.

| Command | Result |
| --- | --- |
| `make` or `make all` | All manuscripts, comparisons, combined/editor/individual letters |
| `make -C original` | Original manuscript only |
| `make -C revised1 paper` | Revised manuscript only |
| `make -C revised1 diff` | Comparison against the configured baseline |
| `make -C reply1 responses` | Combined letter |
| `make -C reply1 editor` | Editor letter |
| `make -C reply1 reviewer2` | Reviewer 2 letter |
| `make bundle` | All round-specific letters with the matching comparison appended |
| `make -C reply1 bundle COVER=1` | This round's bundles, with an explanatory cover before each letter |
| `make zip` | Standalone source archives for all manuscripts |
| `make clean` | Remove auxiliaries; retain generated PDFs and ZIP archives |
| `make distclean` | Remove generated outputs; preserve source figures and reviewer guards |
| `make test` | Bash integration suite, including the executable README example |

`make -j4` is supported. Helpers serialize operations on the same stage; independent stages can build concurrently. Do not edit sources while a build or stage-management operation is running. A `.template-lock` directory normally disappears automatically. If a process is killed forcibly, check its `owner` PID and confirm no operation is running before removing that stale lock directory and retrying.

## Starting the first and later revisions

From an initialized publication project's root, after receiving the first decision:

```bash
make new-round
```

This creates `revised1/` from `original/` and `reply1/` from the response scaffold, initially with two reviewers plus the editor. Edit `revised1/paper.tex`, its included sources, and `revised1/paper.bib`. Fill `reply1/metadata.tex`, `editor-comments.tex`, and the configured `reviewerX-comments.tex` files. Build with `make`, then `make bundle` if the submission needs marked comparisons. Leave the submitted original unchanged.

After submitting round 1 and receiving the next decision, run the **same** root command:

```bash
make new-round
```

It creates `revised2/` from `revised1/` and `reply2/` from `reply1/`. Further invocations create round 3 and onwards; there are no unused rounds at initialization. Metadata, reviewer membership, formatting, and cover preference are inherited. Comment/answer bodies are replaced with useful TODO scaffolds, retaining the prior outer `enumerate`/`itemize` choice. Update the new manuscript ID if the journal changes it. No old submitted folder is modified. An orphaned round or existing destination is an error, rather than permission to overwrite it.

Use a literal integer reviewer list and literal relative baseline/revision paths in the thin stage Makefiles. Management helpers read these declarations directly; do not replace them with computed Make expressions. To compare against a different submitted stage temporarily, use `make -C revised2 diff BASELINE=../original`; restore the usual comparison for bundles, or change the stage's `BASELINE` declaration deliberately. All manuscript dependencies must remain inside their stage for standalone source archives.

## Reviewer membership and safe removal

There is no fixed reviewer limit. New author projects start round 1 with reviewers 1 and 2; add or remove them to match the decision. The editor is always separate and does not count as a reviewer. The `REVIEWERS` list in the round's Makefile is authoritative. Numbers remain stable when another reviewer is removed; gaps are allowed. Prefer the targets to manual changes so membership, generated inputs, sources, and safety records remain consistent.

```bash
# From the project root:
make add-reviewer ROUND=1                 # next unused number after the highest ID
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

`reviewerX.tex` is a small standalone letter wrapper: audience, common preamble, introduction, and inclusion of `reviewerX-comments.tex`. **Put received comments and your answers in `reviewerX-comments.tex`**, which is also included in the combined letter. Newly added reviewers receive a ready-to-compile wrapper and a section with an optional overall comment plus three TODO comment/answer pairs. Add/remove items and use numbered or bulleted lists to match the actual decision. The editor gets analogous scaffolding.

Removal succeeds only while **both** files are byte-identical to their recorded generated scaffolds. Edited answers, edited wrappers, populated demonstrations, or missing provenance cause a refusal without changing membership. There is no force-removal option. Persistent `.reviewer-scaffolds/` directories contain source baseline copies used by `cmp`, must be tracked in Git, and survive `clean`/`distclean`. A customized wrapper remains protected in subsequent rounds; new comment scaffolds in those rounds get their own baseline. Review an accidental edit and restore the untouched source only if you truly intend to discard it; do not delete safety records to bypass protection.

An editor-only round is supported: remove both untouched initial reviewers before adding content. Its combined title addresses the editor, individual reviewer letters are omitted, and later rounds inherit zero reviewers until you add one.

## Response letter structure and formatting

`metadata.tex` defines `\PaperTitle`, `\PaperAuthors`, and `\SubmissionID`. Use the real paper title and all paper authors; separate authors with `\and`. These values are shared by combined, editor, individual, and optional cover documents.

The document title follows the original repository's wording:

> Responses to the comments of all the reviewers to the previously submitted manuscript "<manuscript title>" (manuscript id <manuscript-id>)

Individual letters use “reviewer X”; the editor letter and editor-only combined letter address “the editor”. Section 1 retains the original introduction content. Subsequent sections are “Responses to the Editor comments” and “Responses to the comments of reviewer X”. The original 12-point A4 layout, 25 mm margins, italic reviewer comments, and fully bold replies with their spacing are kept in `preamble.tex` and `commands.tex`.

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

## Bibliographies in rebuttals

Each round's response letters use **the same `revisedN/paper.bib` as its revised manuscript**. Do not create a separate reply bibliography. Add a reply-only entry to that file if needed; the manuscript will not list it unless cited there. Use normal `\cite{key}` or `\nocite{key}` in replies, including included TeX files. `\nocite{*}` deliberately selects every database entry.

Bibliography declarations are inserted automatically at the end of a letter only when a citation or `\nocite` actually executes. Comments containing `\cite` do not trigger bibliography processing. A citation-free letter compiles without a bibliography, even with an empty or absent database; a citing letter requires a valid database and keys. Each individual letter gets its own cited subset; the combined letter gets the union of its executed citations. Adding/removing the last citation and changing `paper.bib` are handled by latexmk. The hook supports the template's standard LaTeX citation setup; if you replace it with a different bibliography engine, adapt the hook and build rules together.

Manuscripts retain their own normal `\bibliographystyle{IEEEtran}` and `\bibliography{paper}` declarations. With those declarations, keep `paper.bib` present even if empty; omit the declarations if the manuscript has no bibliography at all. The automatic citation-aware behavior above applies to response letters.

## Guided full example: two reviewers, two rounds

Everything below is fictional. Start in the template clone. The `support/walkthrough/` assets contain **exactly the text shown below**, so copying them reproduces the completed example without manually transcribing TeX. For your own publication, replace the example text with your manuscript and actual decision letters.

### 1. Initialize and submit the original

<!-- RUN -->
```bash
make init-project DEST=../guided-paper
cd ../guided-paper
cp support/walkthrough/original/paper.tex original/paper.tex
cp support/walkthrough/original/paper.bib original/paper.bib
make original
```

The original deliberately has incomplete details and an outdated reference so the revisions have visible changes.

<!-- FILE support/walkthrough/original/paper.tex -->
```tex
\documentclass[journal]{IEEEtran}
\usepackage[T1]{fontenc}
\usepackage{amsmath}
\title{A Simple Sensor Averaging Method}
\author{Ada Author}
\begin{document}
\maketitle
\begin{abstract}
This fictional example illustrates an arithmetic mean of sensor readings.
It is demonstration content, not a scientific finding.
\end{abstract}
\section{Introduction}
We summarize readings using a simple mean, following fictional guides
by Alpha~\cite{guide} and Beta~\cite{method}.
\section{Method}\label{sec:method}
We compute $\bar{x}=N^{-1}\sum_{i=1}^{N}x_i$.
\section{Results}\label{sec:results}
The example readings are 10, 12, and 14. Their mean is 12.
We use Gamma's fictional checklist~\cite{legacy} for practical guidance.
\section{Conclusion}
The mean provides a compact summary of these example readings.
\bibliographystyle{IEEEtran}
\bibliography{paper}
\end{document}
```

<!-- FILE support/walkthrough/original/paper.bib -->
```bibtex
% All entries in this walkthrough are fictional.
@article{guide,
 author = {Ada Alpha}, title = {An Illustrative Guide to Reporting Sensor Measurements},
 journal = {Journal of Fictional Measurements}, year = {2024}, volume = {1}, pages = {1--4}
}
@article{method,
 author = {Ben Beta}, title = {An Example Guide to Senor Averaging},
 journal = {Imaginary Methods}, year = {2023}, volume = {2}, pages = {10--12}
}
@article{legacy,
 author = {Gia Gamma}, title = {An Old Practical Checklist},
 journal = {Fictional Practice}, year = {2020}, volume = {3}, pages = {20--22}
}
```

### 2. Receive the first decision and create round 1

A plain-text email can mix paragraphs, numbering, and bullets:

<!-- FILE support/walkthrough/emails/round1.txt -->
```text
FICTIONAL EMAIL - demonstration only
Subject: Revision requested for GUIDE-2026-001
Dear Ada Author,

Please revise "A Simple Sensor Averaging Method". The following comments
are fictional and illustrate common plain-text email formats.

EDITOR (unformatted paragraphs)
Please submit a clean revised manuscript and a marked comparison against the previous submission.

Keep the manuscript title, author names, and manuscript identifier consistent across the response letters.

Provide a point-by-point response and explain where each requested change appears.

REVIEWER 1 (numbered comments)
1. Define N in the averaging equation and state which readings are included.
2. Give the measurement units and show the calculation for readings 10, 12, and 14.
3. Discuss the effect of an outlier and state the limits of the method.

REVIEWER 2 (bulleted comments)
- Correct the spelling of Beta's reference title and verify its publication year.
- Replace Gamma's outdated checklist with a more recent limitations reference.
- Explain how the revision history can be checked and provide a reference for the response-reporting convention.

Please use manuscript ID GUIDE-2026-001 for this revision.
The Fictional Editor
```

Create the round, inspect membership, and practice removing/re-adding an **untouched** reviewer before entering comments. Both folder-local and root commands operate on the same round. No extra reviewer is introduced.

<!-- RUN -->
```bash
make new-round
make info-reviewer
cd reply1
make remove-reviewer REVIEWER=2
make add-reviewer
make info-reviewer
cd ..
make remove-reviewer ROUND=1 REVIEWER=2
make add-reviewer ROUND=1 REVIEWER=2
```

### 3. Revise the paper and answer all comments

The revised paper defines N, specifies units, calculates the mean, and acknowledges outlier limitations. Its bibliography corrects Beta's title/year, removes Gamma, adds Delta, and includes Epsilon for citations used only in rebuttals.

<!-- RUN -->
```bash
cp support/walkthrough/revised1/paper.tex revised1/paper.tex
cp support/walkthrough/revised1/paper.bib revised1/paper.bib
cp support/walkthrough/reply1/metadata.tex reply1/metadata.tex
cp support/walkthrough/reply1/editor-comments.tex reply1/editor-comments.tex
cp support/walkthrough/reply1/reviewer1-comments.tex reply1/reviewer1-comments.tex
cp support/walkthrough/reply1/reviewer2-comments.tex reply1/reviewer2-comments.tex
```

<!-- FILE support/walkthrough/revised1/paper.tex -->
```tex
\documentclass[journal]{IEEEtran}
\usepackage[T1]{fontenc}
\usepackage{amsmath}
\title{A Simple Sensor Averaging Method}
\author{Ada Author}
\begin{document}
\maketitle
\begin{abstract}
This fictional example illustrates an arithmetic mean of sensor readings.
It is demonstration content, not a scientific finding.
\end{abstract}
\section{Introduction}
We summarize readings using a simple mean, following fictional guides
by Alpha~\cite{guide} and Beta~\cite{method}.
\section{Method}\label{sec:method}
We compute $\bar{x}=N^{-1}\sum_{i=1}^{N}x_i$.
Here N is the positive number of readings included in one batch.
All readings in a batch measure the same quantity in the same units.
\section{Results}\label{sec:results}
The example temperature readings are 10, 12, and 14 degrees Celsius.
Their mean is $(10+12+14)/3=12$ degrees Celsius.
\section{Limitations}\label{sec:limitations}
An outlier can shift the arithmetic mean. This example does not claim
robustness to outliers. We follow Delta's fictional limitations checklist~\cite{limits}.
\section{Conclusion}
The mean provides a compact summary of these example readings.
\bibliographystyle{IEEEtran}
\bibliography{paper}
\end{document}
```

<!-- FILE support/walkthrough/revised1/paper.bib -->
```bibtex
% All entries in this walkthrough are fictional.
@article{guide,
 author = {Ada Alpha}, title = {An Illustrative Guide to Reporting Sensor Measurements},
 journal = {Journal of Fictional Measurements}, year = {2024}, volume = {1}, pages = {1--4}
}
@article{method,
 author = {Ben Beta}, title = {An Example Guide to Sensor Averaging},
 journal = {Imaginary Methods}, year = {2025}, volume = {2}, pages = {10--12}
}
@article{limits,
 author = {Dan Delta}, title = {A Recent Limitations Checklist},
 journal = {Fictional Practice}, year = {2026}, volume = {4}, pages = {30--33}
}
% Cited only in the rebuttal; it does not appear in the manuscript's reference list.
@article{reporting,
 author = {Eva Epsilon}, title = {A Fictional Response Reporting Convention},
 journal = {Imaginary Editorial Notes}, year = {2026}, volume = {1}, pages = {40--42}
}
```

<!-- FILE support/walkthrough/reply1/metadata.tex -->
```tex
\newcommand{\PaperTitle}{A Simple Sensor Averaging Method}
\newcommand{\PaperAuthors}{Ada Author}
\newcommand{\SubmissionID}{GUIDE-2026-001}
```

Convert the editor's paragraphs into separate pairs, reviewer 1's numbered comments into `enumerate`, and reviewer 2's bullets into `itemize`. Each comment below reproduces its email wording, and each answer describes an actual change above.

<!-- FILE support/walkthrough/reply1/editor-comments.tex -->
```tex
\Needspace{14\baselineskip}
\section{Responses to the Editor comments}
\label{sec:responses-editor}
\begin{itemize}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Please submit a clean revised manuscript and a marked comparison against the previous submission.}
    \response{We provide the clean revised manuscript and the comparison PDF. The reporting example follows the fictional guide~\cite{guide}.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Keep the manuscript title, author names, and manuscript identifier consistent across the response letters.}
    \response{The manuscript title and Ada Author are unchanged. All letter metadata uses manuscript ID GUIDE-2026-001.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Provide a point-by-point response and explain where each requested change appears.}
    \response{The reviewer sections below identify the Method, Results, and new Limitations sections for the corresponding changes.}
\end{itemize}
```

<!-- FILE support/walkthrough/reply1/reviewer1-comments.tex -->
```tex
\Needspace{14\baselineskip}
\section{Responses to the comments of reviewer 1}
\label{sec:responses-reviewer1}
\begin{enumerate}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Define N in the averaging equation and state which readings are included.}
    \response{The Method section now defines N as the positive number of readings in one batch and states that these readings measure the same quantity in the same units.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Give the measurement units and show the calculation for readings 10, 12, and 14.}
    \response{The Results section now identifies temperature in degrees Celsius and shows the calculation (10+12+14)/3=12 degrees Celsius.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Discuss the effect of an outlier and state the limits of the method.}
    \response{The new Limitations section states that an outlier can shift the mean and explicitly avoids claiming robustness to outliers.}
\end{enumerate}
```

<!-- FILE support/walkthrough/reply1/reviewer2-comments.tex -->
```tex
\Needspace{14\baselineskip}
\section{Responses to the comments of reviewer 2}
\label{sec:responses-reviewer2}
\begin{itemize}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Correct the spelling of Beta's reference title and verify its publication year.}
    \response{We corrected Senor to Sensor and changed the fictional year from 2023 to 2025 while retaining the method citation key~\cite{method}.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Replace Gamma's outdated checklist with a more recent limitations reference.}
    \response{We removed the legacy entry and its citation, and added Delta's limitations checklist in the new Limitations section~\cite{limits}.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Explain how the revision history can be checked and provide a reference for the response-reporting convention.}
    \response{The comparison PDF shows the changes against the original submission. For this fictional response-reporting convention, we cite Epsilon~\cite{reporting}. This reference is used only in the rebuttal.}
\end{itemize}
```

Reviewer 1 has no citations and no references section. The editor cites Alpha; reviewer 2 cites Beta, Delta, and Epsilon. The combined letter lists those four references. The manuscript lists Alpha, Beta, and Delta, excluding the reply-only Epsilon entry.

### 4. Verify removal protection, build, and submit round 1

Removing the now-populated reviewer 1 must fail. This conditional verifies that refusal while allowing the example to continue:

<!-- RUN -->
```bash
if make remove-reviewer ROUND=1 REVIEWER=1; then
  echo 'Unexpected removal of populated reviewer files' >&2
  exit 1
fi
make -j4
make -C reply1 responses
make -C reply1 editor
make -C reply1 reviewer1
make -C reply1 reviewer2
make -C reply1 bundle COVER=1
make -C reply1 bundle COVER=0
make zip
mkdir submission-check
(cd submission-check && unzip -q ../revised1/build/paper.zip && make)
```

Inspect `revised1/paper.pdf`, `revised1/paper-diff.pdf`, and the four plain letters in `reply1/`. Bundles have names such as `responses-with-diff.pdf` and put the optional cover first, then the letter, then the comparison. `COVER=1` is opt-in; the final command above restores uncovered bundles. Set `COVER := 1` in a reply Makefile to make covers its persistent default; a command-line `COVER=0` overrides it.

The independent archive build in `submission-check/` verifies the submitted sources. Submit the required PDFs and `revised1/build/paper.zip`, then freeze round 1. The source ZIP contains the manuscript's locally recorded dependencies and a minimal standalone build system, not rebuttal letters or the repository's entire history.

### 5. Receive the second decision

<!-- FILE support/walkthrough/emails/round2.txt -->
```text
FICTIONAL EMAIL - demonstration only
Subject: Minor revision for GUIDE-2026-001-R2
Dear Ada Author,

Please address the following final clarifications for the same fictional paper.

EDITOR (unformatted paragraphs)
Keep the earlier submitted files intact and compare this revision against the first revised manuscript.

Update the manuscript identifier to GUIDE-2026-001-R2 in the new response letters.

Provide the final clean manuscript, comparison, and point-by-point responses.

REVIEWER 1 (numbered comments)
1. Clarify whether N may differ between measurement batches.
2. State whether a separate mean is computed for each batch.
3. Confirm that temperature units remain consistent within a batch.

REVIEWER 2 (bulleted comments)
- Explain why Beta's publication year is now 2025.
- State explicitly that no robust estimator is evaluated in this example.
- Retain the response-reporting reference and identify which files record this round.

Please use manuscript ID GUIDE-2026-001-R2 for the final revision.
The Fictional Editor
```

Use `new-round` again; it copies round 1's submitted manuscript and bibliography, inherits the same two reviewers, and replaces old answers with new TODO scaffolds. The following edits address this second email; the ID changes to `GUIDE-2026-001-R2`.

<!-- RUN -->
```bash
make new-round
cp support/walkthrough/revised2/paper.tex revised2/paper.tex
cp support/walkthrough/reply2/metadata.tex reply2/metadata.tex
cp support/walkthrough/reply2/editor-comments.tex reply2/editor-comments.tex
cp support/walkthrough/reply2/reviewer1-comments.tex reply2/reviewer1-comments.tex
cp support/walkthrough/reply2/reviewer2-comments.tex reply2/reviewer2-comments.tex
```

The round 2 bibliography is unchanged and inherited; no separate database is needed.

<!-- FILE support/walkthrough/revised2/paper.tex -->
```tex
\documentclass[journal]{IEEEtran}
\usepackage[T1]{fontenc}
\usepackage{amsmath}
\title{A Simple Sensor Averaging Method}
\author{Ada Author}
\begin{document}
\maketitle
\begin{abstract}
This fictional example illustrates an arithmetic mean of sensor readings.
It is demonstration content, not a scientific finding.
\end{abstract}
\section{Introduction}
We summarize readings using a simple mean, following fictional guides
by Alpha~\cite{guide} and Beta~\cite{method}.
\section{Method}\label{sec:method}
We compute $\bar{x}=N^{-1}\sum_{i=1}^{N}x_i$.
Here N is the positive number of readings included in one batch.
N may differ between batches; we compute a separate mean for each batch.
All readings in a batch measure the same quantity in the same units.
\section{Results}\label{sec:results}
The example temperature readings are 10, 12, and 14 degrees Celsius.
Their mean is $(10+12+14)/3=12$ degrees Celsius.
\section{Limitations}\label{sec:limitations}
An outlier can shift the arithmetic mean. This example does not claim
robustness to outliers, and no robust estimator is evaluated.
We follow Delta's fictional limitations checklist~\cite{limits}.
\section{Conclusion}
The mean provides a compact summary of these example readings.
\bibliographystyle{IEEEtran}
\bibliography{paper}
\end{document}
```

<!-- FILE support/walkthrough/reply2/metadata.tex -->
```tex
\newcommand{\PaperTitle}{A Simple Sensor Averaging Method}
\newcommand{\PaperAuthors}{Ada Author}
\newcommand{\SubmissionID}{GUIDE-2026-001-R2}
```

<!-- FILE support/walkthrough/reply2/editor-comments.tex -->
```tex
\Needspace{14\baselineskip}
\section{Responses to the Editor comments}
\label{sec:responses-editor}
\begin{itemize}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Keep the earlier submitted files intact and compare this revision against the first revised manuscript.}
    \response{We preserve original and revised1 unchanged. The new revised2 comparison uses revised1 as its baseline.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Update the manuscript identifier to GUIDE-2026-001-R2 in the new response letters.}
    \response{The new reply2 metadata sets this identifier for every letter and optional cover.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Provide the final clean manuscript, comparison, and point-by-point responses.}
    \response{We provide the revised2 clean manuscript and comparison, along with the combined and individual reply2 letters.}
\end{itemize}
```

<!-- FILE support/walkthrough/reply2/reviewer1-comments.tex -->
```tex
\Needspace{14\baselineskip}
\section{Responses to the comments of reviewer 1}
\label{sec:responses-reviewer1}
\begin{enumerate}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Clarify whether N may differ between measurement batches.}
    \response{The Method section now states explicitly that N may differ between batches.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{State whether a separate mean is computed for each batch.}
    \response{The same new Method sentence states that we compute a separate mean for each batch.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Confirm that temperature units remain consistent within a batch.}
    \response{We retain the Method requirement that readings in a batch use the same units and the Results label of degrees Celsius. No text change was needed for this point.}
\end{enumerate}
```

<!-- FILE support/walkthrough/reply2/reviewer2-comments.tex -->
```tex
\Needspace{14\baselineskip}
\section{Responses to the comments of reviewer 2}
\label{sec:responses-reviewer2}
\begin{itemize}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Explain why Beta's publication year is now 2025.}
    \response{The first revision corrected the deliberately inaccurate fictional metadata while retaining the method key~\cite{method}. We retain that correction in revised2.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{State explicitly that no robust estimator is evaluated in this example.}
    \response{We added this statement to the Limitations section.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Retain the response-reporting reference and identify which files record this round.}
    \response{We retain Epsilon's fictional convention~\cite{reporting}. The revised2 manuscript and reply2 response files record this round; earlier stages remain separate and unchanged.}
\end{itemize}
```

### 6. Build, inspect membership, and submit round 2

<!-- RUN -->
```bash
make -j4
make -C reply2 bundle
make -C revised2 zip
make info-reviewer
(cd reply2 && make info-reviewer)
make clean
```

Root membership information shows two reviewers (`1 2`) in each round, plus the editor. Folder-local information shows round 2 alone. `revised2/paper-diff.pdf` compares with `revised1`, while the first comparison still compares with `original`. `clean` leaves PDFs, source archives, and removal guards available. Freeze round 2 after submission; use `make new-round` for a later decision.

### Optional editor-only publication

This is a separate branch of the workflow, not a step to run in the completed guided project. In a fresh author project, before filling any reviewer files:

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

## Why I keep complete stage folders

I deliberately duplicate manuscript sources when creating a revision instead of relying only on Git tags and history. A review round is a concrete submission package: the manuscript, bibliography, response letters, and comparison baseline must be visible together. Separate folders let me build old and new submissions side by side, inspect exactly what was sent, and share a round with a collaborator who does not need to understand Git checkout mechanics. The revision's bibliography also remains the exact database used by both its manuscript and its replies.

Git history is still valuable for the work inside each stage; I use commits or tags to mark submissions as well. Tags alone require checking out several revisions or using worktrees to compare or build them simultaneously, and can make it easier to compare against an unintended state. Explicit folders make the baseline a reviewable declaration in each Makefile.

The tradeoffs are extra storage, duplicated files, and the risk of editing an older submitted stage by mistake. I accept that cost for a small paper project. I freeze submitted folders, edit only the active round, keep stage-local assets, and use the generated comparison to review changes. Large binary data should be managed separately with an explicit reproducible source rather than copied into every round. Shared build helpers remain centralized; submitted manuscript sources stay complete within each stage.

## Validation and license

`make test` exercises builds with Python invocation blocked, paths containing spaces, incremental text/bibliography changes, citation-free and citing letters, add/remove protections, editor-only rounds, covers and metadata, independent ZIP extraction, cleanup, and both complete README review rounds. README code/assets and received-comment wording are checked against the supplied walkthrough files. The tests also run from an initialized author project. The template and fictional examples are distributed under the MIT license; IEEEtran remains subject to its own license.
