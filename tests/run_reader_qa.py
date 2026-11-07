"""Run the editor integration fixture in a fresh, isolated Godot project."""
import argparse
import pathlib
import shutil
import subprocess
import tempfile
import os

parser = argparse.ArgumentParser()
parser.add_argument("--godot", required=True, help="Path to the Godot console executable")
parser.add_argument("--image", help="Optional local image to reproduce a reported image issue")

args = parser.parse_args()
if args.image:
    os.environ["MD_QA_IMAGE"] = str(pathlib.Path(args.image).resolve())
repo = pathlib.Path(__file__).resolve().parent.parent
project = pathlib.Path(tempfile.mkdtemp(prefix="markdown-reader-qa-"))
shutil.copytree(repo / "addons/markdown_docs_viewer", project / "addons/markdown_docs_viewer")
shutil.copytree(repo / "docs", project / "docs")
fixture = project / "addons/qa"
fixture.mkdir()
shutil.copyfile(repo / "tests/reader_qa.gd", fixture / "qa.gd")
(fixture / "plugin.cfg").write_text(
    '[plugin]\nname="Reader QA"\ndescription="Isolated integration fixture"\n'
    'author="local"\nversion="1"\nscript="qa.gd"\n', encoding="utf-8"
)
(project / "project.godot").write_text(
    'config_version=5\n[application]\nconfig/name="Reader QA"\n'
    '[editor_plugins]\nenabled=PackedStringArray("res://addons/qa/plugin.cfg")\n'
    '[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8"
)
(project / "README.md").write_text("# Integration test\n\nOriginal text.\n", encoding="utf-8")
(project / "other.md").write_text("# Other document\n", encoding="utf-8")
log = project / "qa.log"
options = {}
if hasattr(subprocess, "STARTUPINFO"):
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = 0  # SW_HIDE: this automated fixture is not the user's editor.
    options["startupinfo"] = startup
print(f"QA project: {project}", flush=True)
try:
    result = subprocess.run(
        [args.godot, "--editor", "--path", str(project), "--log-file", str(log)],
        timeout=90, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT, **options
    )
except subprocess.TimeoutExpired:
    print(f"QA timed out. Inspect {log}")
    raise SystemExit(1)
output = log.read_text(encoding="utf-8", errors="replace") if log.exists() else ""
print(output)
print(f"Screenshot: {project / 'reader-preview.png'}")
passed = "Reader checks:" in output and "; failures: 0" in output and "ERROR:" not in output
raise SystemExit(0 if result.returncode == 0 and passed else 1)
