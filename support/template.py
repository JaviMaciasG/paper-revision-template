#!/usr/bin/env python3
"""Document builds and stage management; Python standard library only."""
import argparse
from contextlib import contextmanager
import fcntl
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

HELPERS = Path(__file__).resolve().parent
ROOT = HELPERS.parent


def run(args, cwd, capture=False):
    print('+ ' + ' '.join(map(str, args)), flush=True)
    return subprocess.run(list(map(str, args)), cwd=cwd, check=True,
                          stdout=subprocess.PIPE if capture else None).stdout


def require(names):
    missing = [name for name in names if not shutil.which(name)]
    if missing:
        raise ValueError('Missing tools: ' + ', '.join(missing) +
                         '. Install the dependencies in README.md or use make container.')


def check_tools(diff=False, merge=False):
    require(['latexmk', 'pdflatex', 'bibtex', 'kpsewhich'])
    if diff or merge:
        require(['latexpand', 'latexdiff'])
    for filename in ('IEEEtran.cls', 'IEEEtran.bst'):
        if not subprocess.run(['kpsewhich', filename], capture_output=True, check=True).stdout.strip():
            raise ValueError('Missing TeX package file: ' + filename)
    if merge and not (shutil.which('pdfunite') or shutil.which('gs')):
        raise ValueError('PDF bundles require pdfunite (Poppler) or gs (Ghostscript).')
    print('Required tools are available.')


@contextmanager
def locked(stage):
    out = stage / 'build'
    out.mkdir(exist_ok=True)
    with (out / '.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield out


def compile_tex(stage, basename, bibliography=True):
    source = stage / (basename + '.tex')
    if not source.is_file():
        source = stage / 'build' / (basename + '.tex')
    if not source.is_file():
        raise ValueError('Missing document source: ' + str(source))
    require(['latexmk', 'pdflatex'] + (['bibtex'] if bibliography else []))
    run(['latexmk', '-norc', '-r', HELPERS / 'latexmkrc', '-pdf',
         '-interaction=nonstopmode', '-halt-on-error', '-file-line-error',
         '-recorder', '-auxdir=build', '-outdir=.', '-emulate-aux-dir', *([] if bibliography else ['-bibtex-']),
         source.relative_to(stage)], stage)
    return stage / (basename + '.pdf')


def paper(stage):
    with locked(stage):
        return compile_tex(stage, 'paper')


def update(path, data):
    """Do not trigger latexmk when generated input content is unchanged."""
    if not path.exists() or path.read_bytes() != data:
        temporary = path.with_suffix(path.suffix + '.tmp')
        temporary.write_bytes(data)
        temporary.replace(path)


def expanded(stage):
    bbl = stage / 'build' / 'paper.bbl'
    if not bbl.is_file():
        raise ValueError('Missing compiled bibliography: ' + str(bbl))
    data = run(['latexpand', '--fatal', '--expand-bbl', bbl, 'paper.tex'], stage, capture=True)
    path = stage / 'build' / 'paper-expanded.tex'
    update(path, data)
    return path


def baseline_for(stage, value=None):
    if value is None:
        match = re.search(r'^BASELINE\s*:?=\s*(.+?)\s*$', (stage / 'Makefile').read_text(), re.M)
        value = match.group(1) if match else ''
    if not value:
        raise ValueError('Set BASELINE to the preceding manuscript directory in ' + str(stage / 'Makefile'))
    baseline = (stage / value).resolve()
    if baseline == stage:
        raise ValueError('A revision cannot be its own baseline.')
    if not (baseline / 'paper.tex').is_file():
        raise ValueError('Baseline manuscript not found: ' + str(baseline))
    return baseline


def diff(stage, baseline):
    require(['latexpand', 'latexdiff'])
    previous = baseline_for(stage, baseline)
    # Never hold two stage locks at once: parallel root builds are safe.
    with locked(previous):
        compile_tex(previous, 'paper')
        old_data = expanded(previous).read_bytes()
    with locked(stage) as out:
        compile_tex(stage, 'paper')
        new = expanded(stage)
        old = out / 'baseline-expanded.tex'
        update(old, old_data)
        signature = hashlib.sha256(old_data + b'\0' + new.read_bytes() +
                                   Path(__file__).read_bytes()).hexdigest()
        signature_file = out / '.diff-signature'
        generated = out / 'paper-diff.tex'
        if not generated.exists() or not signature_file.exists() or signature_file.read_text() != signature:
            data = run(['latexdiff', '--encoding=utf8', '--type=UNDERLINE',
                        '--exclude-textcmd=hskip,vskip,smallskip,medskip,bigskip', old, new], stage, capture=True)
            update(generated, data)
            update(signature_file, signature.encode())
        return compile_tex(stage, 'paper-diff', bibliography=False)


def replies(stage, letters):
    with locked(stage):
        return [compile_tex(stage, letter) for letter in letters]


def bundle(stage, revision_value, letters):
    if not revision_value:
        raise ValueError('Set REVISION in the rebuttal Makefile.')
    revision = (stage / revision_value).resolve()
    comparison = diff(revision, None)
    if not (shutil.which('pdfunite') or shutil.which('gs')):
        raise ValueError('PDF bundles require pdfunite or gs.')
    with locked(stage) as out:
        for letter in letters:
            pdf = compile_tex(stage, letter)
            target = stage / (letter + '-with-diff.pdf')
            temporary = out / (letter + '-with-diff.tmp.pdf')
            try:
                if shutil.which('pdfunite'):
                    run(['pdfunite', pdf, comparison, temporary], stage)
                else:
                    run(['gs', '-dBATCH', '-dNOPAUSE', '-dSAFER', '-sDEVICE=pdfwrite',
                         '-sOutputFile=' + str(temporary), pdf, comparison], stage)
                temporary.replace(target)
            finally:
                temporary.unlink(missing_ok=True)


def generated_pdf_names(stage):
    """Reserved stage-root outputs; PDFs in figures/ remain source assets."""
    if (stage / 'paper.tex').is_file():
        return {'paper.pdf', 'paper-diff.pdf'}
    if (stage / 'responses.tex').is_file():
        letters = {'responses', 'editor'}
        letters.update(p.stem for p in stage.glob('reviewer*.tex')
                       if re.fullmatch(r'reviewer[1-9][0-9]*', p.stem))
        return {name + suffix + '.pdf' for name in letters
                for suffix in ('', '-with-diff')}
    return set()


def source_files(stage):
    """Round copies preserve stage-local sources, including PDF figure assets."""
    ignored = {'build', '.git', '__pycache__'}
    generated_pdfs = generated_pdf_names(stage)
    auxiliary = {'.aux', '.log', '.bbl', '.blg', '.fls', '.fdb_latexmk', '.synctex', '.pyc'}
    for p in sorted(stage.rglob('*')):
        relative = p.relative_to(stage)
        if p.parent == stage and p.name in generated_pdfs:
            continue
        if any(part in ignored for part in relative.parts) or p.suffix in auxiliary:
            continue
        if p.name.endswith(('.synctex.gz', '~')):
            continue
        if p.is_symlink():
            raise ValueError('Stage sources must be regular files, not symlinks: ' + str(p))
        if p.is_file():
            yield p


def ignore_project_outputs(directory, names):
    stage = Path(directory)
    ignored = {'build', '.git', '__pycache__'} | generated_pdf_names(stage)
    ignored.update(name for name in names if name.endswith(('.pyc', '.synctex', '.synctex.gz')))
    return ignored.intersection(names)


def init_project(destination_value):
    if not destination_value:
        raise ValueError('Set DEST to a new project folder, for example make init-project DEST=../my-paper.')
    requested = Path(destination_value).expanduser()
    if requested.exists() or requested.is_symlink():
        raise ValueError('Refusing to overwrite existing destination: ' + str(requested))
    destination = requested.resolve()
    if destination.is_relative_to(ROOT):
        raise ValueError('Choose a destination outside the template repository.')
    if not (HELPERS / 'starter' / 'paper.tex').is_file():
        raise ValueError('The minimal manuscript starter is missing.')
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Assemble a complete project before exposing the destination.
    with tempfile.TemporaryDirectory(prefix='.init-project-', dir=destination.parent) as temp:
        project = Path(temp) / 'project'
        project.mkdir()
        for name in ('Makefile', 'README.md', 'LICENSE', '.gitignore'):
            shutil.copy2(ROOT / name, project / name)
        for name in ('support', 'tests', '.github'):
            shutil.copytree(ROOT / name, project / name,
                            ignore=ignore_project_outputs)
        shutil.copytree(HELPERS / 'starter', project / 'original', ignore=ignore_project_outputs)
        readme = project / 'README.md'
        text = readme.read_text()
        text = text.replace('# IEEE manuscript and rebuttal template', '# Manuscript project', 1)
        readme.write_text(text.replace(
            'A standalone publication workflow with a first submission (`original`), an example revision (`revised1`), and matching responses (`reply1`). The IEEE paper is also a short manual. All example bibliography entries are fictional.',
            'This initialized author project starts with a minimal IEEE manuscript in `original/`. '
            'Replace `original/paper.tex` and `original/paper.bib` with your real manuscript and bibliography. '
            'There are no active revision folders yet; `make new-round` creates round one. '
            'The worked example is included only as isolated test fixtures.', 1))
        if destination.exists() or destination.is_symlink():
            raise ValueError('Refusing to overwrite existing destination: ' + str(destination))
        project.rename(destination)
    print('Created project: ' + str(destination))
    print('Replace original/paper.tex and original/paper.bib with your real manuscript and bibliography.')
    print('After submitting the original manuscript, run make new-round in the new project.')


def next_round():
    # Lock outside the source tree, so help/clone do not depend on generated state.
    lockname = 'paper-template-' + hashlib.sha256(str(ROOT).encode()).hexdigest()[:16] + '.lock'
    with (Path(tempfile.gettempdir()) / lockname).open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        revisions = sorted((int(p.name[7:]), p) for p in ROOT.iterdir()
                           if p.is_dir() and re.fullmatch(r'revised[1-9][0-9]*', p.name))
        number, previous = revisions[-1] if revisions else (0, ROOT / 'original')
        if not (previous / 'paper.tex').is_file():
            raise ValueError('Latest manuscript is missing paper.tex: ' + str(previous))
        n = number + 1
        revision, reply = ROOT / f'revised{n}', ROOT / f'reply{n}'
        if revision.exists() or reply.exists():
            raise ValueError(f'Refusing to overwrite {revision.name} or {reply.name}.')
        orphan_replies = [p.name for p in ROOT.iterdir()
                          if re.fullmatch(r'reply[1-9][0-9]*', p.name)
                          and not (ROOT / ('revised' + p.name[5:])).is_dir()]
        if orphan_replies:
            raise ValueError('Unpaired reply stages: ' + ', '.join(orphan_replies))
        previous_reply = ROOT / f'reply{number}' if number else HELPERS / 'reply-skeleton'
        if not previous_reply.is_dir():
            raise ValueError('No preceding rebuttal structure found: ' + str(previous_reply))
        manuscript_sources = list(source_files(previous))
        reply_sources = list(source_files(previous_reply))
        reviewer_match = re.search(r'^REVIEWERS\s*:?=\s*(.*?)\s*$',
                                   (previous_reply / 'Makefile').read_text(), re.M)
        reviewers = reviewer_match.group(1).split() if reviewer_match else ['1', '2']
        if not reviewers or any(not re.fullmatch(r'[1-9][0-9]*', r) for r in reviewers):
            raise ValueError('REVIEWERS must contain positive reviewer numbers.')
        required = ['editor-comments.tex'] + [f'reviewer{r}-comments.tex' for r in reviewers]
        if any(not (previous_reply / file).is_file() for file in required):
            raise ValueError('The previous reply is missing a configured comment file.')
        # Stage both directories before exposing either. Roll back on failure.
        with tempfile.TemporaryDirectory(prefix='.new-round-', dir=ROOT) as temp:
            temporary = Path(temp)
            for destination, source_stage, sources in [(temporary / revision.name, previous, manuscript_sources),
                                                        (temporary / reply.name, previous_reply, reply_sources)]:
                destination.mkdir()
                for p in sources:
                    target = destination / p.relative_to(source_stage)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(p, target)
            (temporary / revision.name / 'Makefile').write_text(
                f'TYPE := revision\nBASELINE := ../{previous.name}\ninclude ../support/manuscript.mk\n')
            (temporary / reply.name / 'Makefile').write_text(
                f'REVISION := ../{revision.name}\nREVIEWERS := {" ".join(reviewers)}\ninclude ../support/reply.mk\n')
            # Clear every comment file, including any no-longer-configured reviewers.
            for p in (temporary / reply.name).glob('*-comments.tex'):
                title = 'Editor' if p.name == 'editor-comments.tex' else p.stem.replace('-comments', '').replace('reviewer', 'Reviewer ')
                p.write_text('\\section*{' + title + '}\n\\reviewcomment{TODO: Insert the new comment.}\n'
                             '\\response{TODO: Write the response and identify manuscript changes.}\n')
            (temporary / revision.name).rename(revision)
            try:
                (temporary / reply.name).rename(reply)
            except Exception:
                shutil.rmtree(revision)
                raise
        print(f'Created {revision.name} and {reply.name}; baseline is {previous.name}.')
        print(f'Update {reply.name}/metadata.tex and the new reviewer/editor comments, then run make.')


def archive(stage):
    with locked(stage) as out:
        compile_tex(stage, 'paper')
        files = set()
        for line in (out / 'paper.fls').read_text().splitlines():
            if not line.startswith('INPUT '):
                continue
            candidate = (stage / line[6:]).resolve()
            if candidate.is_relative_to(out) or not candidate.is_file():
                continue
            if candidate.is_relative_to(stage):
                files.add(candidate)
            elif candidate.is_relative_to(ROOT):
                raise ValueError('Submission inputs must be stage-local: ' + str(candidate))
        aux = (out / 'paper.aux').read_text()
        for match in re.findall(r'\\bibdata\{([^}]+)\}', aux):
            for name in match.split(','):
                candidate = (stage / (name + '.bib')).resolve()
                if not candidate.is_relative_to(stage) or not candidate.is_file():
                    raise ValueError('Missing or non-local bibliography: ' + str(candidate))
                files.add(candidate)
        for name in re.findall(r'\\bibstyle\{([^}]+)\}', aux):
            candidate = stage / (name + '.bst')
            if candidate.is_file():
                files.add(candidate.resolve())
        if stage / 'paper.tex' not in files:
            raise ValueError('Recorder did not report paper.tex.')
        target = out / 'paper.zip'
        temporary = out / 'paper.zip.tmp'
        try:
            with zipfile.ZipFile(temporary, 'w', zipfile.ZIP_DEFLATED) as z:
                for p in sorted(files):
                    z.write(p, p.relative_to(stage))
                for name in ('template.py', 'latexmkrc', 'manuscript.mk'):
                    z.write(HELPERS / name, 'support/' + name)
                z.writestr('Makefile', 'TYPE := manuscript\ninclude support/manuscript.mk\n')
                z.write(ROOT / 'LICENSE', 'LICENSE')
                z.writestr('README.md', 'Standalone manuscript submission sources.\n\n'
                           'Install GNU Make, Python 3, and TeX Live (IEEEtran and latexmk).\n'
                           'Run `make` to compile, or `make help` for commands.\n'
                           'The PDF is written to paper.pdf alongside paper.tex. No other stages are required.\n')
            temporary.replace(target)
        finally:
            temporary.unlink(missing_ok=True)
        print('Created ' + str(target))


def clean(stage, everything=False):
    out = stage / 'build'
    if out.is_symlink():
        raise ValueError('Refusing to clean a symlinked build directory.')
    outputs = generated_pdf_names(stage)
    # Handle root outputs even if a user already removed the build directory.
    with locked(stage):
        for p in out.iterdir():
            if p.name == '.lock':
                continue
            if not everything and p.suffix == '.zip':
                continue
            if p.is_dir() and not p.is_symlink():
                shutil.rmtree(p)
            else:
                p.unlink()
        for name in outputs:
            pdf = stage / name
            if everything:
                pdf.unlink(missing_ok=True)
            for extension in ('.synctex', '.synctex.gz'):
                pdf.with_suffix(extension).unlink(missing_ok=True)
    if everything:
        (out / '.lock').unlink(missing_ok=True)
        out.rmdir()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['paper', 'diff', 'reply', 'bundle', 'check-tools',
                                            'init-project', 'new-round', 'zip', 'clean', 'distclean'])
    parser.add_argument('--dest')
    parser.add_argument('--baseline')
    parser.add_argument('--revision')
    parser.add_argument('--letters', nargs='+', default=['responses', 'editor', 'reviewer1', 'reviewer2'])
    parser.add_argument('--diff', action='store_true')
    parser.add_argument('--merge', action='store_true')
    args = parser.parse_args()
    stage = Path.cwd().resolve()
    try:
        if args.command == 'paper': paper(stage)
        elif args.command == 'diff': diff(stage, args.baseline)
        elif args.command == 'reply': replies(stage, args.letters)
        elif args.command == 'bundle': bundle(stage, args.revision, args.letters)
        elif args.command == 'check-tools': check_tools(args.diff, args.merge)
        elif args.command == 'init-project': init_project(args.dest)
        elif args.command == 'new-round': next_round()
        elif args.command == 'zip': archive(stage)
        elif args.command in ('clean', 'distclean'): clean(stage, args.command == 'distclean')
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print('Error: ' + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
