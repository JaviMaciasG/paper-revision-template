"""End-to-end checks run in disposable copies, never in submitted stages."""
import os
import importlib.util
from unittest.mock import patch
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest
import zipfile
ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / 'tests/fixtures'
spec = importlib.util.spec_from_file_location('source_driver', ROOT / 'support/template.py')
SOURCE_DRIVER = importlib.util.module_from_spec(spec)
spec.loader.exec_module(SOURCE_DRIVER)


def ignore_generated(directory, names):
    directory = Path(directory)
    ignored = {'build', '.git', '__pycache__'}
    if directory.parent in (ROOT, FIXTURES):
        ignored.update(SOURCE_DRIVER.generated_pdf_names(directory))
        ignored.update(name for name in names if name.endswith(('.synctex', '.synctex.gz')))
    return ignored.intersection(names)

class Workflow(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='paper-template-test-')
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name) / 'template with spaces'
        self.root.mkdir()
        for name in ('Makefile', 'README.md', 'LICENSE', '.gitignore'):
            shutil.copy2(ROOT / name, self.root / name)
        for name in ('support', 'tests', '.github'):
            shutil.copytree(ROOT / name, self.root / name, ignore=ignore_generated)
        for stage in ('original', 'revised1', 'reply1'):
            shutil.copytree(FIXTURES / stage, self.root / stage, ignore=ignore_generated)

    def make(self, *args, cwd=None, success=True, env=None):
        r = subprocess.run(['make', *args], cwd=cwd or self.root, env=env,
                           text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if success: self.assertEqual(r.returncode, 0, r.stdout[-8000:])
        else: self.assertNotEqual(r.returncode, 0, r.stdout)
        return r

    def test_help_and_missing_tools(self):
        with tempfile.TemporaryDirectory() as path:
            for tool in ('make',):
                os.symlink(shutil.which(tool), Path(path) / tool)
            env = dict(os.environ, PATH=path)
            for stage in ('.', 'original', 'revised1', 'reply1'):
                self.assertIn('help', self.make('-C', stage, 'help', env=env).stdout)
            result = self.make('check-tools', 'PYTHON=' + shutil.which('python3'), success=False, env=env)
            self.assertIn('Missing tools:', result.stdout)

    def test_new_round(self):
        before = (self.root / 'reply1/reviewer1-comments.tex').read_bytes()
        (self.root / 'revised1/build').mkdir()
        (self.root / 'revised1/build/paper.pdf').write_bytes(b'generated')
        # Generated root PDFs must not become sources of the next round.
        for relative in ('revised1/paper.pdf', 'revised1/paper-diff.pdf',
                         'reply1/responses.pdf', 'reply1/responses-with-diff.pdf'):
            (self.root / relative).write_bytes(b'generated output')
        assets = {'illustration.pdf': b'root PDF figure', 'figures/paper.pdf': b'nested PDF figure'}
        for relative, data in assets.items():
            (self.root / 'revised1' / relative).write_bytes(data)
        self.make('new-round')
        for relative in ('revised2/paper.pdf', 'revised2/paper-diff.pdf',
                         'reply2/responses.pdf', 'reply2/responses-with-diff.pdf'):
            self.assertFalse((self.root / relative).exists())
        for relative, data in assets.items():
            self.assertEqual((self.root / 'revised2' / relative).read_bytes(), data)
        self.assertEqual((self.root / 'revised1/paper.tex').read_bytes(), (self.root / 'revised2/paper.tex').read_bytes())
        self.assertFalse((self.root / 'revised2/build').exists())
        self.assertIn('../revised1', (self.root / 'revised2/Makefile').read_text())
        self.assertIn('../revised2', (self.root / 'reply2/Makefile').read_text())
        self.assertIn('TODO', (self.root / 'reply2/reviewer1-comments.tex').read_text())
        self.assertEqual(before, (self.root / 'reply1/reviewer1-comments.tex').read_bytes())
        self.make('-j4')
        self.assertTrue((self.root / 'revised2/paper-diff.pdf').is_file())
        self.assertTrue((self.root / 'reply2/responses.pdf').is_file())
        (self.root / 'reply3').mkdir()
        (self.root / 'reply3/keep.txt').write_text('keep')
        self.make('new-round', success=False)
        self.assertEqual((self.root / 'reply3/keep.txt').read_text(), 'keep')
        self.assertFalse((self.root / 'revised3').exists())

    def test_build_dependencies_bundles_archives_cleanup(self):
        self.make('-j4')
        for stage in ('original', 'revised1', 'reply1'):
            self.assertFalse(list((self.root / stage / 'build').glob('*.pdf')))
        for relative in ('original/paper.pdf', 'revised1/paper.pdf',
                         'revised1/paper-diff.pdf', 'reply1/responses.pdf',
                         'reply1/editor.pdf', 'reply1/reviewer1.pdf', 'reply1/reviewer2.pdf'):
            self.assertTrue((self.root / relative).is_file())
        # Ordinary PDF assets survive both forms of cleanup.
        figure = self.root / 'revised1/illustration.pdf'
        nested_figure = self.root / 'revised1/figures/paper.pdf'
        figure.write_bytes(b'root figure asset')
        nested_figure.write_bytes(b'nested figure asset')
        diff = (self.root / 'revised1/build/paper-diff.tex').read_text()
        self.assertIn('\\bibitem{legacy}', diff)
        self.assertIn('manual snapshot', diff)
        self.assertIn('\\bibitem{automation}', diff)
        self.assertIn('automated build', diff)
        self.assertIn('DIFadd', diff)
        self.assertIn('DIFdel', diff)
        for log in self.root.glob('*/build/*.log'):
            self.assertNotIn('undefined', log.read_text().lower(), str(log))
            self.assertNotIn('Overfull', log.read_text(), str(log))
        output = self.root / 'revised1/paper-diff.pdf'
        before = output.stat().st_mtime_ns
        self.make('-C', 'revised1', 'diff')
        self.assertEqual(before, output.stat().st_mtime_ns)
        time.sleep(1.1)
        section = self.root / 'revised1/sections/comparisons.tex'
        section.write_text(section.read_text() + '\nDependency verification sentence.\n')
        bib = self.root / 'revised1/paper.bib'
        bib.write_text(bib.read_text().replace('An Automated Build Checklist', 'A Revised Automated Build Checklist'))
        self.make('-C', 'reply1', 'bundle')
        self.assertGreater(output.stat().st_mtime_ns, before)
        expanded = (self.root / 'revised1/build/paper-expanded.tex').read_text()
        self.assertIn('Dependency verification sentence.', expanded)
        self.assertIn('A revised automated build checklist', expanded)
        self.assertTrue((self.root / 'reply1/responses-with-diff.pdf').is_file())
        self.make('zip')
        for stage in ('original', 'revised1'):
            extracted = self.root / ('extracted-' + stage)
            with zipfile.ZipFile(self.root / stage / 'build/paper.zip') as archive:
                self.assertIn('paper.bib', archive.namelist())
                self.assertIn('figures/workflow.tex', archive.namelist())
                self.assertFalse(any(n.endswith('.bbl') for n in archive.namelist()))
                archive.extractall(extracted)
            self.make(cwd=extracted)
            self.assertTrue((extracted / 'paper.pdf').is_file())
            self.make('clean', cwd=extracted)
            self.assertTrue((extracted / 'support/template.py').is_file())
            self.assertTrue((extracted / 'paper.pdf').is_file())
        source = (self.root / 'revised1/paper.tex').read_bytes()
        self.make('clean')
        self.assertTrue(output.is_file())
        self.assertFalse((self.root / 'revised1/build/paper.aux').exists())
        self.make('distclean')
        self.assertFalse((self.root / 'revised1/build').exists())
        self.assertFalse(output.exists())
        self.assertFalse((self.root / 'reply1/responses-with-diff.pdf').exists())
        self.assertEqual(figure.read_bytes(), b'root figure asset')
        self.assertEqual(nested_figure.read_bytes(), b'nested figure asset')
        self.assertEqual(source, (self.root / 'revised1/paper.tex').read_bytes())
        self.assertTrue((self.root / 'support/template.py').is_file())

    @unittest.skipUnless(shutil.which('gs'), 'Ghostscript fallback is not installed')
    def test_ghostscript_bundle_fallback(self):
        spec = importlib.util.spec_from_file_location('template_driver', self.root / 'support/template.py')
        driver = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(driver)
        real_which = shutil.which
        with patch.object(driver.shutil, 'which', side_effect=lambda name: None if name == 'pdfunite' else real_which(name)):
            # Suppress TeX chatter while retaining failure diagnostics in the driver.
            def quiet_run(args, cwd, capture=False):
                return subprocess.run(list(map(str, args)), cwd=cwd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout
            with patch.object(driver, 'run', side_effect=quiet_run):
                driver.bundle(self.root / 'reply1', '../revised1', ['responses'])
        pdf = self.root / 'reply1/responses-with-diff.pdf'
        self.assertTrue(pdf.read_bytes().startswith(b'%PDF-'))
        self.assertGreater(pdf.stat().st_size, 10000)

    def test_distclean_after_build_directory_removed(self):
        self.make('-C', 'original')
        figure = self.root / 'original/figures/paper.pdf'
        figure.write_bytes(b'PDF source asset')
        shutil.rmtree(self.root / 'original/build')
        self.make('-C', 'original', 'distclean')
        self.assertFalse((self.root / 'original/paper.pdf').exists())
        self.assertFalse((self.root / 'original/paper.synctex.gz').exists())
        self.assertFalse((self.root / 'original/build').exists())
        self.assertEqual(figure.read_bytes(), b'PDF source asset')

    def test_init_project_and_first_two_rounds(self):
        project = self.root.parent / 'my paper'
        # Active manuscript content must not become the new project's starter.
        source = self.root / 'original/paper.tex'
        source.write_text('Author manuscript content that initialization must not copy.')
        before = source.read_bytes()
        for directory in ('support/starter', 'tests/fixtures/original'):
            (self.root / directory / 'paper.pdf').write_bytes(b'generated preview')
            (self.root / directory / 'paper.synctex.gz').write_bytes(b'generated sync')
        self.make('init-project', 'DEST=' + str(project))
        self.assertEqual(source.read_bytes(), before)
        self.assertTrue((self.root / 'revised1').is_dir())
        self.assertTrue((self.root / 'reply1').is_dir())
        for name in ('revised1', 'reply1', '.git', 'original/build', 'original/paper.pdf',
                     'support/starter/paper.pdf', 'support/starter/paper.synctex.gz',
                     'tests/fixtures/original/paper.pdf'):
            self.assertFalse((project / name).exists(), name)
        self.assertIn('This initialized author project', (project / 'README.md').read_text())
        paper = (project / 'original/paper.tex').read_text()
        self.assertIn(r'\documentclass[journal]{IEEEtran}', paper)
        self.assertIn(r'Replace \texttt{original/paper.tex} with your real manuscript', paper)
        self.assertIn(r'\texttt{original/paper.bib} with your real bibliography', paper)
        self.assertNotIn('Author manuscript content', paper)
        bib = (project / 'original/paper.bib').read_text()
        self.assertEqual(bib.count('@article'), 1)
        self.assertIn('Fictional', bib)
        self.assertTrue((project / '.github/workflows/build.yml').is_file())
        self.assertTrue((project / 'tests/fixtures/revised1/paper.tex').is_file())
        self.make('check-tools', 'all', cwd=project)
        self.assertTrue((project / 'original/paper.pdf').is_file())
        self.assertFalse((project / 'original/build/paper.pdf').exists())
        real_paper = project / 'original/paper.tex'
        real_paper.write_text(real_paper.read_text().replace('Your Manuscript Title', 'Author Manuscript'))
        asset = project / 'original/figure.pdf'
        asset.write_bytes(b'PDF figure source')
        self.make('new-round', cwd=project)
        self.assertEqual(real_paper.read_bytes(), (project / 'revised1/paper.tex').read_bytes())
        self.assertEqual(asset.read_bytes(), (project / 'revised1/figure.pdf').read_bytes())
        self.assertFalse((project / 'revised1/paper.pdf').exists())
        self.assertIn('../original', (project / 'revised1/Makefile').read_text())
        self.assertIn('../revised1', (project / 'reply1/Makefile').read_text())
        for filename in ('metadata.tex', 'editor-comments.tex', 'reviewer1-comments.tex', 'reviewer2-comments.tex'):
            self.assertIn('TODO', (project / 'reply1' / filename).read_text())
        revised = project / 'revised1/paper.tex'
        revised.write_text(revised.read_text().replace('Author Manuscript', 'Revised Author Manuscript'))
        self.make('-j4', cwd=project)
        comment = project / 'reply1/reviewer1-comments.tex'
        comment.write_text(comment.read_text().replace('TODO: Insert the new comment.', 'Previous round comment.'))
        metadata = project / 'reply1/metadata.tex'
        metadata.write_text(metadata.read_text().replace('TODO: Manuscript title', 'Author Manuscript'))
        self.make('new-round', cwd=project)
        self.assertEqual(revised.read_bytes(), (project / 'revised2/paper.tex').read_bytes())
        self.assertIn('../revised1', (project / 'revised2/Makefile').read_text())
        self.assertIn('../revised2', (project / 'reply2/Makefile').read_text())
        self.assertNotIn('Previous round comment.', (project / 'reply2/reviewer1-comments.tex').read_text())
        self.assertEqual(metadata.read_bytes(), (project / 'reply2/metadata.tex').read_bytes())
        self.make('-j4', cwd=project)
        self.make('bundle', 'zip', cwd=project)
        self.assertTrue((project / 'revised2/paper-diff.pdf').is_file())
        self.assertTrue((project / 'reply2/responses-with-diff.pdf').is_file())
        self.assertTrue((project / 'revised2/build/paper.zip').is_file())
        # The project's own suite uses fixtures, not its edited active paper.
        if not os.environ.get('PAPER_TEMPLATE_NESTED_TEST'):
            self.make('test', cwd=project, env=dict(os.environ, PAPER_TEMPLATE_NESTED_TEST='1'))

    def test_init_project_validation(self):
        self.assertIn('Set DEST', self.make('init-project', success=False).stdout)
        self.assertIn('Refusing to overwrite', self.make('init-project', 'DEST=' + str(self.root), success=False).stdout)
        existing = self.root.parent / 'existing project'
        existing.mkdir()
        marker = existing / 'keep.txt'
        marker.write_text('keep existing content')
        self.make('init-project', 'DEST=' + str(existing), success=False)
        self.assertEqual(marker.read_text(), 'keep existing content')
        internal = self.root / 'nested project'
        result = self.make('init-project', 'DEST=' + str(internal), success=False)
        self.assertIn('outside the template', result.stdout)
        self.assertFalse(internal.exists())

    def test_failures(self):
        r = self.make('-C', 'revised1', 'diff', 'BASELINE=../missing', success=False)
        self.assertIn('Baseline manuscript not found', r.stdout)
        self.assertFalse((self.root / 'revised1/paper-diff.pdf').exists())
        (self.root / 'original/paper.tex').write_text('\\documentclass{article}\n\\begin{document}\n\\undefinedcommand\n\\end{document}\n')
        self.make('-C', 'original', success=False)
        self.assertFalse((self.root / 'original/paper.pdf').exists())

if __name__ == '__main__': unittest.main()
