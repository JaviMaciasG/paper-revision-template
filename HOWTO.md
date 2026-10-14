# Guided Example: Changing Reviewers across Two Rounds

## Introduction

This HOWTO describes a fully guided example to mimic a realistic paper revision process. You can start from the template repository clone. The `support/walkthrough/` assets contain **exactly the LaTeX and BiBTeX code shown below**, so copying them reproduces the completed example without manually transcribing TeX. For your own publication, replace the example text with your manuscript and actual decision letters.

[Return to the README](README.md) for setup, the general workflow, and the command reference.


## Initializing and Submitting the Original

To initialize the example project, copy its original sources, and compile the manuscript, run the following Bash commands:

<!-- RUN -->
```bash
make init-project DEST=../guided-paper
cd ../guided-paper
cp support/walkthrough/original/paper.tex original/paper.tex
cp support/walkthrough/original/paper.bib original/paper.bib
make original
```

The original deliberately has incomplete details and an outdated reference so the revisions have visible changes.

The LaTeX source file `support/walkthrough/original/paper.tex` contains:

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

The BibTeX bibliography file `support/walkthrough/original/paper.bib` contains:

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

## Round 1: Receiving the First Decision (Reviewers 1, 2, and 3)

A plain-text email can mix paragraphs, numbering, and bullets.

The fictional decision email in the plain-text file `support/walkthrough/emails/round1.txt` reads:

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

REVIEWER 3 (numbered comments)
1. State how many readings are used in the worked example.
2. Explain whether readings of different physical quantities can be averaged together.
3. Make clear that the example does not establish general performance or robustness.

Please use manuscript ID GUIDE-2026-001 for this revision.
The Fictional Editor
```

Create the round with the three reviewer IDs assigned in the decision. Choose membership before filling comments and responses.

To create round 1 with reviewers 1, 2, and 3, run the following Bash commands:

<!-- RUN -->
```bash
make new-round REVIEWERS="1 2 3"
make status
make info-reviewer ROUND=1
```

## Revising the Manuscript and Answering the Comments

The revised paper defines N, specifies units, calculates the mean, and acknowledges outlier limitations. Its bibliography corrects Beta's title/year, removes Gamma, adds Delta, and includes Epsilon for citations used only in rebuttals.

To fill round 1 with the completed manuscript, bibliography, and responses shown below, run the following Bash commands:

<!-- RUN -->
```bash
cp support/walkthrough/revised1/paper.tex revised1/paper.tex
cp support/walkthrough/revised1/paper.bib revised1/paper.bib
cp support/walkthrough/reply1/metadata.tex reply1/metadata.tex
cp support/walkthrough/reply1/editor-comments.tex reply1/editor-comments.tex
cp support/walkthrough/reply1/reviewer1-comments.tex reply1/reviewer1-comments.tex
cp support/walkthrough/reply1/reviewer2-comments.tex reply1/reviewer2-comments.tex
cp support/walkthrough/reply1/reviewer3-comments.tex reply1/reviewer3-comments.tex
```

The LaTeX source file `support/walkthrough/revised1/paper.tex` contains:

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

The BibTeX bibliography file `support/walkthrough/revised1/paper.bib` contains:

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

The LaTeX source file `support/walkthrough/reply1/metadata.tex` contains:

<!-- FILE support/walkthrough/reply1/metadata.tex -->
```tex
\newcommand{\PaperTitle}{A Simple Sensor Averaging Method}
\newcommand{\PaperAuthors}{Ada Author}
\newcommand{\SubmissionID}{GUIDE-2026-001}
```

Convert the editor's paragraphs into separate pairs, reviewer 1's numbered comments into `enumerate`, and reviewer 2's bullets into `itemize`. Each comment below reproduces its email wording, and each answer describes an actual change above.

The LaTeX source file `support/walkthrough/reply1/editor-comments.tex` contains:

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

The LaTeX source file `support/walkthrough/reply1/reviewer1-comments.tex` contains:

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

The LaTeX source file `support/walkthrough/reply1/reviewer2-comments.tex` contains:

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

The LaTeX source file `support/walkthrough/reply1/reviewer3-comments.tex` contains:

<!-- FILE support/walkthrough/reply1/reviewer3-comments.tex -->
```tex
\Needspace{14\baselineskip}
\section{Responses to the comments of reviewer 3}
\label{sec:responses-reviewer3}
\begin{enumerate}
  \Needspace{5\baselineskip}
  \item \reviewercomment{State how many readings are used in the worked example.}
    \response{The Results section now lists all three readings, 10, 12, and 14 degrees Celsius, and shows their mean.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Explain whether readings of different physical quantities can be averaged together.}
    \response{The Method section now requires every reading in a batch to measure the same quantity in the same units.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Make clear that the example does not establish general performance or robustness.}
    \response{The abstract identifies the content as a fictional demonstration rather than a scientific finding. The new Limitations section explicitly disclaims robustness to outliers.}
\end{enumerate}
```

Reviewers 1 and 3 have no citations and no references section. The editor cites Alpha; reviewer 2 cites Beta, Delta, and Epsilon. The combined letter lists those four references. The manuscript lists Alpha, Beta, and Delta, excluding the reply-only Epsilon entry.

## Building, Inspecting, and Submitting Round 1

Removing the now-populated reviewer 1 must fail. This conditional verifies that refusal while allowing the example to continue.

To check reviewer-removal protection, build round 1, and compile its extracted submission archive, run the following Bash commands:

<!-- RUN -->
```bash
if make remove-reviewer ROUND=1 REVIEWER=1; then
  echo 'Unexpected removal of populated reviewer files' >&2
  exit 1
fi
make current
make -C reply1 responses
make -C reply1 editor
make -C reply1 reviewer1
make -C reply1 reviewer2
make -C reply1 reviewer3
make -C reply1 bundle COVER=1
make submission COVER=0
mkdir submission-check
(cd submission-check && unzip -q ../revised1/paper-revised1.zip && make)
```

Inspect `revised1/paper.pdf`, `revised1/paper-diff.pdf`, and the five plain letters in `reply1/`. Bundles have names such as `responses-with-diff.pdf` and put the optional cover first, then the letter, then the comparison. `COVER=1` is opt-in; the final command above restores uncovered bundles. Set `COVER := 1` in a reply Makefile to make covers its persistent default; a command-line `COVER=0` overrides it.

`make current` builds only round 1 and its required baseline; `make submission` prepares every round-1 output and prints their paths. Folder-level commands above demonstrate individual letters and optional covers. The independent archive build in `submission-check/` verifies the submitted sources. Submit the required PDFs and `revised1/paper-revised1.zip`, then freeze round 1. The source ZIP contains the manuscript's required compilation sources and one standalone Makefile, not rebuttal letters or the repository's entire history.

## Round 2: Receiving the Second Decision (Reviewers 1, 3, and 4)

The fictional decision email in the plain-text file `support/walkthrough/emails/round2.txt` reads:

<!-- FILE support/walkthrough/emails/round2.txt -->
```text
FICTIONAL EMAIL - demonstration only
Subject: Minor revision for GUIDE-2026-001-R2
Dear Ada Author,

Please address the following final clarifications for the same fictional paper.

No follow-up report was received from reviewer 2 concerning your first-round responses.
Reviewer 4 has joined this round; reports from reviewers 1, 3, and 4 follow.
The absence of reviewer 2's report does not imply approval.

EDITOR (unformatted paragraphs)
Keep the earlier submitted files intact and compare this revision against the first revised manuscript.

Update the manuscript identifier to GUIDE-2026-001-R2 in the new response letters.

Provide the final clean manuscript, comparison, and point-by-point responses.

REVIEWER 1 (numbered comments)
1. Clarify whether N may differ between measurement batches.
2. State whether a separate mean is computed for each batch.
3. Confirm that temperature units remain consistent within a batch.

REVIEWER 3 (numbered comments)
1. Confirm that the worked example still contains exactly three readings.
2. State whether the same quantity and unit requirements apply to every batch.
3. State explicitly that no robust estimator is evaluated in this example.

REVIEWER 4 (bulleted comments)
- Explain why Beta's publication year is now 2025.
- Explain whether the example demonstrates performance on real sensor data.
- Retain the response-reporting reference and identify which files record this round.

Please use manuscript ID GUIDE-2026-001-R2 for the final revision.
The Fictional Editor
```

Use `new-round` again with `REVIEWERS="1 3 4"`. It replaces old answers with new TODO scaffolds, excludes reviewer 2 from round 2, and initializes reviewer 4 using the number assigned in the decision. Reviewer 2's completed round-1 letter stays intact; reviewers 1 and 3 retain their numbers and formatting. Without an explicit list, membership would be inherited.

## Updating Reviewers, Revising, and Answering the New Comments

Selecting membership at creation avoids separate add/remove commands. If membership changes after creation, use `make add-reviewer` or `make remove-reviewer` inside `reply2/`; removal only succeeds while that reviewer's wrapper and comments still match their generated scaffolds.

To create round 2, change its reviewers to 1, 3, and 4, and fill its revised sources and responses, run the following Bash commands:

<!-- RUN -->
```bash
make new-round REVIEWERS="1 3 4"
make status
make -C reply2 info-reviewer
cp support/walkthrough/revised2/paper.tex revised2/paper.tex
cp support/walkthrough/reply2/metadata.tex reply2/metadata.tex
cp support/walkthrough/reply2/editor-comments.tex reply2/editor-comments.tex
cp support/walkthrough/reply2/reviewer1-comments.tex reply2/reviewer1-comments.tex
cp support/walkthrough/reply2/reviewer3-comments.tex reply2/reviewer3-comments.tex
cp support/walkthrough/reply2/reviewer4-comments.tex reply2/reviewer4-comments.tex
```

These edits address the second email; the manuscript ID changes to `GUIDE-2026-001-R2`.

The round 2 bibliography is unchanged and inherited; no separate database is needed.

The LaTeX source file `support/walkthrough/revised2/paper.tex` contains:

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

The LaTeX source file `support/walkthrough/reply2/metadata.tex` contains:

<!-- FILE support/walkthrough/reply2/metadata.tex -->
```tex
\newcommand{\PaperTitle}{A Simple Sensor Averaging Method}
\newcommand{\PaperAuthors}{Ada Author}
\newcommand{\SubmissionID}{GUIDE-2026-001-R2}
```

The LaTeX source file `support/walkthrough/reply2/editor-comments.tex` contains:

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

The LaTeX source file `support/walkthrough/reply2/reviewer1-comments.tex` contains:

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

The LaTeX source file `support/walkthrough/reply2/reviewer3-comments.tex` contains:

<!-- FILE support/walkthrough/reply2/reviewer3-comments.tex -->
```tex
\Needspace{14\baselineskip}
\section{Responses to the comments of reviewer 3}
\label{sec:responses-reviewer3}
\begin{enumerate}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Confirm that the worked example still contains exactly three readings.}
    \response{The Results section retains the same three example readings and the mean of 12 degrees Celsius.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{State whether the same quantity and unit requirements apply to every batch.}
    \response{The Method section states that all readings in a batch measure the same quantity in the same units. The new sentence about separate batch means retains this requirement for each batch.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{State explicitly that no robust estimator is evaluated in this example.}
    \response{We added this statement to the Limitations section; the example remains an illustration of the arithmetic mean.}
\end{enumerate}
```

The LaTeX source file `support/walkthrough/reply2/reviewer4-comments.tex` contains:

<!-- FILE support/walkthrough/reply2/reviewer4-comments.tex -->
```tex
\Needspace{14\baselineskip}
\section{Responses to the comments of reviewer 4}
\label{sec:responses-reviewer4}
\begin{itemize}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Explain why Beta's publication year is now 2025.}
    \response{The first revision corrected the deliberately inaccurate fictional metadata while retaining the method key~\cite{method}. We retain that correction in revised2.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Explain whether the example demonstrates performance on real sensor data.}
    \response{The abstract states that the example is fictional demonstration content, not a scientific finding. We make no claim about performance on real sensor data.}
  \Needspace{5\baselineskip}
  \item \reviewercomment{Retain the response-reporting reference and identify which files record this round.}
    \response{We retain Epsilon's fictional convention~\cite{reporting}. The revised2 manuscript and reply2 response files record this round; earlier stages remain separate and unchanged.}
\end{itemize}
```

Reviewers 1 and 3 remain citation-free. Reviewer 4 cites Beta and Epsilon from the inherited revised2/paper.bib; its references are included automatically in both the individual and combined letters.

## Building, Inspecting, and Submitting Round 2

To build and package round 2, inspect reviewer membership, and remove auxiliaries, run the following Bash commands:

<!-- RUN -->
```bash
make current
make -C reply2 reviewer1
make -C reply2 reviewer3
make -C reply2 reviewer4
make submission ROUND=2
make info-reviewer
(cd reply2 && make info-reviewer)
make clean
```

Root membership information shows three reviewers in each round: `1 2 3` in round 1 and `1 3 4` in round 2, plus the editor. Each round has five plain letters: combined, editor, and three individual reviewer letters. Reviewer 2's letter remains in reply1; reply2 has no reviewer 2 letter. Folder-local information shows round 2 alone. `revised2/paper-diff.pdf` compares with `revised1`, while the first comparison still compares with `original`. `clean` leaves PDFs, source archives, and removal guards available. Freeze round 2 after submission; use `make new-round` for a later decision.

## Optional: Removing and Restoring the Completed Round

Run these commands from the publication root after completing the guided example.

Archive and restore the completed second round. Its answers and PDFs remain intact; with one matching archive, no `ARCHIVE` selection is needed.

To archive and restore the completed second round, run the following Bash commands:

<!-- RUN -->
```bash
make remove-round ROUND=2
make info-reviewer
make restore-round ROUND=2
make info-reviewer
```


## Keeping the Project Build System Updated

Update the build system separately from the manuscript and response sources. From the original template clone, preview and apply an update using the following Bash commands (these maintenance commands are not part of the executable walkthrough):

```bash
make update-project DEST=../guided-paper
make update-project DEST=../guided-paper APPLY=1
```

Alternatively, from the guided project, use the following Bash commands with your actual template path:

```bash
make update-template FROM=/path/to/paper-revision-template
make update-template FROM=/path/to/paper-revision-template APPLY=1
make status
make current
```

Review the preview first. Conflicting customizations stop the update; modified guides are preserved with incoming copies for comparison. Replacements are backed up under `.template-update/backups/`. Submitted manuscript stages and response sources remain untouched. See the README's [update instructions](README.md#update-an-existing-publication-project) for legacy migration and recovery.
