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

class Workflow(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='paper-template-test-')
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name) / 'template with spaces'
        shutil.copytree(ROOT, self.root, ignore=shutil.ignore_patterns('build', '.git', '__pycache__'))

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
        self.make('new-round')
        self.assertEqual((self.root / 'revised1/paper.tex').read_bytes(), (self.root / 'revised2/paper.tex').read_bytes())
        self.assertFalse((self.root / 'revised2/build').exists())
        self.assertIn('../revised1', (self.root / 'revised2/Makefile').read_text())
        self.assertIn('../revised2', (self.root / 'reply2/Makefile').read_text())
        self.assertIn('TODO', (self.root / 'reply2/reviewer1-comments.tex').read_text())
        self.assertEqual(before, (self.root / 'reply1/reviewer1-comments.tex').read_bytes())
        self.make('-j4')
        self.assertTrue((self.root / 'revised2/build/paper-diff.pdf').is_file())
        self.assertTrue((self.root / 'reply2/build/responses.pdf').is_file())
        (self.root / 'reply3').mkdir()
        (self.root / 'reply3/keep.txt').write_text('keep')
        self.make('new-round', success=False)
        self.assertEqual((self.root / 'reply3/keep.txt').read_text(), 'keep')
        self.assertFalse((self.root / 'revised3').exists())

    def test_build_dependencies_bundles_archives_cleanup(self):
        self.make('-j4')
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
        output = self.root / 'revised1/build/paper-diff.pdf'
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
        self.assertTrue((self.root / 'reply1/build/responses-with-diff.pdf').is_file())
        self.make('zip')
        for stage in ('original', 'revised1'):
            extracted = self.root / ('extracted-' + stage)
            with zipfile.ZipFile(self.root / stage / 'build/paper.zip') as archive:
                self.assertIn('paper.bib', archive.namelist())
                self.assertIn('figures/workflow.tex', archive.namelist())
                self.assertFalse(any(n.endswith('.bbl') for n in archive.namelist()))
                archive.extractall(extracted)
            self.make(cwd=extracted)
            self.assertTrue((extracted / 'build/paper.pdf').is_file())
            self.make('clean', cwd=extracted)
            self.assertTrue((extracted / 'support/template.py').is_file())
        source = (self.root / 'revised1/paper.tex').read_bytes()
        self.make('clean')
        self.assertTrue(output.is_file())
        self.assertFalse((self.root / 'revised1/build/paper.aux').exists())
        self.make('distclean')
        self.assertFalse((self.root / 'revised1/build').exists())
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
        pdf = self.root / 'reply1/build/responses-with-diff.pdf'
        self.assertTrue(pdf.read_bytes().startswith(b'%PDF-'))
        self.assertGreater(pdf.stat().st_size, 10000)

    def test_failures(self):
        r = self.make('-C', 'revised1', 'diff', 'BASELINE=../missing', success=False)
        self.assertIn('Baseline manuscript not found', r.stdout)
        self.assertFalse((self.root / 'revised1/build/paper-diff.pdf').exists())
        (self.root / 'original/paper.tex').write_text('\\documentclass{article}\n\\begin{document}\n\\undefinedcommand\n\\end{document}\n')
        self.make('-C', 'original', success=False)
        self.assertFalse((self.root / 'original/build/paper.pdf').exists())

if __name__ == '__main__': unittest.main()
