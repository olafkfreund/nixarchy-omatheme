#!/usr/bin/env bash
# The Nix-store adaptations of the Icons helper (#66), against a throwaway home:
# each case fails without its patch in pkgs/hyprchroma.nix or the revert command
# in modules/nixos.nix. HYPRCHROMA_ICONS_PACKAGE is the withIcons build,
# HYPRCHROMA_PACKAGE the default one, PYTHON_ENV the former's Python (Pillow).
set -euo pipefail

: "${HYPRCHROMA_ICONS_PACKAGE:?must point to the withIcons hyprchroma package}"
: "${HYPRCHROMA_PACKAGE:?must point to the default hyprchroma package}"
: "${PYTHON_ENV:?must point to the withIcons Python environment}"

exec "$PYTHON_ENV/bin/python3" -I - "$HYPRCHROMA_ICONS_PACKAGE" "$HYPRCHROMA_PACKAGE" <<'PY'
import json, os, re, shutil, stat, subprocess, sys, tempfile, types
from pathlib import Path
from PIL import Image

ICONS_PKG, DEFAULT_PKG = sys.argv[1], sys.argv[2]
HELPER = ICONS_PKG + "/lib/hyprchroma/hyprchroma-icons"
failures = []
# Loading the helper narrows PATH, so find bash first.
BASH = shutil.which("bash")


def chk(name, got, want):
    ok = got == want
    print(f"  {'PASS' if ok else 'FAIL'} {name}" + ("" if ok else f": got [{got}] want [{want}]"))
    if not ok:
        failures.append(name)


def load(path):
    module = types.ModuleType("ic")
    module.__dict__["__file__"] = str(path)
    exec(compile(Path(path).read_text(), "ic", "exec"), module.__dict__)
    return module


def cli(*args, helper=HELPER):
    return subprocess.run([helper, *args], capture_output=True, text=True, timeout=120)


def rmtree(path):
    for directory, dirs, files in os.walk(path):
        for name in dirs:
            if not os.path.islink(os.path.join(directory, name)):
                os.chmod(os.path.join(directory, name), 0o755)
    shutil.rmtree(path, ignore_errors=True)


class Fixture:
    """A home, a fake Reversal with its green variant, and an Omarchy theme."""

    def __init__(self, green=True):
        self.root = Path(os.path.realpath(tempfile.mkdtemp()))
        self.home = self.root / "home"
        self.home.mkdir()
        self.share = self.root / "usr/share"
        os.environ.update({"HOME": str(self.home), "XDG_RUNTIME_DIR": str(self.root / "run"),
                           "XDG_DATA_DIRS": str(self.share), "OMARCHY_PATH": str(self.root / "omarchy"),
                           "HYPRCHROMA_ICONS_ISOLATED": "1"})
        for name in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME",
                     "DBUS_SESSION_BUS_ADDRESS"):
            os.environ.pop(name, None)
        (self.root / "run").mkdir(mode=0o700)
        for name, face in (("Reversal", "#f5aa1e"), ("Reversal-dark", "#f5aa1e")):
            self.theme(name, face)
        (self.share / "icons/Reversal/apps/scalable").mkdir(parents=True)
        (self.share / "icons/Reversal/apps/scalable/firefox.svg").write_text("<svg/>")
        if green:
            self.green()
        stock = self.root / "omarchy/themes/tokyo-night"
        stock.mkdir(parents=True)
        colors = 'accent = "#7aa2f7"\nbackground = "#1a1b26"\nforeground = "#c0caf5"\nmode = "dark"\n'
        (stock / "colors.toml").write_text(colors)
        current = self.home / ".local/state/omarchy/current"
        (current / "theme").mkdir(parents=True)
        (current / "theme.name").write_text("tokyo-night\n")
        (current / "theme/colors.toml").write_text(colors)
        self.apps = self.home / ".local/share/applications"
        self.apps.mkdir(parents=True)
        self.state = self.home / ".local/state/hyprchroma/icons"
        self.public = self.home / ".local/share/icons"

    def theme(self, name, face, shade="#f08705"):
        theme = self.share / "icons" / name
        (theme / "places/scalable").mkdir(parents=True)
        (theme / "index.theme").write_text(f"[Icon Theme]\nName={name}\n")
        (theme / "places/scalable/folder.svg").write_text(f'<svg><path fill="{face}"/><path fill="{shade}"/></svg>')

    def green(self):
        """Reversal-green as the store has it: read-only, its other artwork a
        relative link into the sibling Reversal theme."""
        for name in ("Reversal-green", "Reversal-green-dark"):
            self.theme(name, "#14b478", "#148c64")
            theme = self.share / "icons" / name
            (theme / "apps").symlink_to("../Reversal/apps")
            (theme / "places/scalable/folder-link.svg").symlink_to("../../../Reversal/places/scalable/folder.svg")
            # The store's Reversal ships links that point nowhere (150 in green).
            (theme / "places/scalable/folder-gone.svg").symlink_to("../../../Reversal/places/scalable/missing.svg")
            for directory, dirs, files in os.walk(theme):
                for entry in files:
                    path = os.path.join(directory, entry)
                    if not os.path.islink(path):
                        os.chmod(path, 0o444)
                for entry in dirs:
                    path = os.path.join(directory, entry)
                    if not os.path.islink(path):
                        os.chmod(path, 0o555)
            os.chmod(theme, 0o555)

    def entry(self, name, icon):
        path = self.apps / f"{name}.desktop"
        path.write_text(f"[Desktop Entry]\nName={name}\nIcon={icon}\nExec=true\n")
        return path

    def picture(self, path, color=(200, 40, 40, 255)):
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGBA", (64, 64), color).save(path)
        return path

    def done(self):
        rmtree(self.root)


def icon_line(path):
    match = re.search(r"^Icon=(.*)$", path.read_text(), re.M)
    return match.group(1) if match else None


# 1. The sage theme from a read-only store theme whose files are links ------------
print("# sage from a read-only theme")
f = Fixture()
run = cli("apply")
chk("(apply succeeds)", run.returncode, 0)
sage = f.public / "Reversal-sage"
chk("sage and sage-dark are created", (sage.is_dir(), (f.public / "Reversal-sage-dark").is_dir()), (True, True))
walked = [(os.path.join(d, n), n) for d, dirs, files in os.walk(sage) for n in dirs + files]
chk("the copy has no links, so none dangles",
    [p for p, _ in walked if os.path.islink(p) or not os.path.exists(p)], [])
chk("...and is writable throughout",
    sorted({os.access(p, os.W_OK) for p, _ in walked} | {os.access(sage, os.W_OK)}), [True])
chk("the artwork reached through the link is a real file there",
    (sage / "places/scalable/folder-link.svg").is_file() and not (sage / "places/scalable/folder-link.svg").is_symlink(), True)
chk("a link that points nowhere is left out, not a failure",
    os.path.lexists(sage / "places/scalable/folder-gone.svg"), False)
folder = (sage / "places/scalable/folder.svg").read_text().lower()
chk("the folder is recoloured to sage", ("#627867" in folder, "#14b478" in folder), (True, False))
chk("the marker is present", (sage / ".omarchroma-generated").is_file(), True)
chk("the store's green theme is untouched",
    "#14b478" in (f.share / "icons/Reversal-green/places/scalable/folder.svg").read_text(), True)
f.done()

# 2. /nix/store is a trusted icon place ------------------------------------------
print("# the store place")
f = Fixture(green=False)
copy = f.root / "helper-copy"
text = Path(HELPER).read_text()
store = f.root / "fake-store"
patched = text.replace('"/nix/store"', f'"{store}"')
chk("the helper names /nix/store once as an icon place", (text.count('"/nix/store"'), patched != text), (1, True))
copy.write_text(patched)
ic = load(copy)
inside = f.picture(store / "abc-tool/share/icons/tool.png")
outside = f.picture(f.home / ".." / "elsewhere/x.png")
chk("an Icon= under the store place is accepted", ic.icon_source(str(inside)) is not None, True)
chk("one under $HOME/../elsewhere is refused", ic.icon_source(str(outside)), None)
chk("without the place, the same file is refused", load(HELPER).icon_source(str(inside)), None)
f.done()

# 3. A re-pointed profile directory changes the apps stamp -----------------------
print("# the apps stamp")
f = Fixture(green=False)
tree_a, tree_b = f.root / "a/applications", f.root / "b/applications"
for tree in (tree_a, tree_b):
    tree.mkdir(parents=True)
    os.utime(tree, ns=(10**18, 10**18))
profile = f.root / "profile"
profile.mkdir()
link = profile / "applications"
os.environ["XDG_DATA_DIRS"] = str(profile)
ic = load(HELPER)
link.symlink_to(tree_a)
before = ic.apps_stamp("reversal", True, f.root / "store")
link.unlink()
link.symlink_to(tree_b)
after = ic.apps_stamp("reversal", True, f.root / "store")
chk("the Python stamp changes with the tree behind the link", before != after, True)
match = re.search(r"^icon_apps_signature\(\) \{\n.*?^\}\n", Path(DEFAULT_PKG + "/bin/hyprchroma").read_text(), re.M | re.S)
function = match.group(0) if match else ""
chk("bin/hyprchroma has the signature function", "icon_apps_signature()" in function, True)
def signature():
    return subprocess.run([BASH, "-c", function + "\nicon_apps_signature"], capture_output=True, text=True).stdout
link.unlink()
link.symlink_to(tree_a)
before = signature()
link.unlink()
link.symlink_to(tree_b)
chk("the shell signature changes with the tree behind the link", (before != "", before != signature()), (True, True))
f.done()

# 4. Artwork reached only through a symlinked directory ---------------------------
print("# artwork through a symlinked directory")
f = Fixture(green=False)
real = f.root / "profile-icons"
f.picture(real / "hicolor/48x48/apps/foo.png")
(f.share / "icons/hicolor").symlink_to(real / "hicolor")
f.entry("foo", "foo")
ic = load(HELPER)
index = ic.artwork_index()
chk("the artwork is found", "foo" in index, True)
run = cli("apply")
chk("(apply succeeds)", run.returncode, 0)
chk("the app is covered from it", (f.home / ".local/share/hyprchroma/icons/apps/foo.svg").is_file(), True)
f.done()

# 5. Symlinked theme directories and icons.theme files are skipped ---------------
print("# symlinks in the user's themes")
f = Fixture(green=False)
themes = f.home / ".config/omarchy/themes"
themes.mkdir(parents=True)
elsewhere = f.root / "dotfiles"
(elsewhere / "linked-dir").mkdir(parents=True)
(elsewhere / "linked-dir/icons.theme").write_text("Reversal\n")
(elsewhere / "icons.theme").write_text("Yaru\n")
(themes / "linked-dir").symlink_to(elsewhere / "linked-dir")
(themes / "real").mkdir()
(themes / "real/icons.theme").symlink_to(elsewhere / "icons.theme")
(themes / "plain").mkdir()
run = cli("apply")
chk("(apply succeeds)", run.returncode, 0)
chk("each skip leaves a log line",
    (run.stderr.count("skipping symlinked"), f"{themes}/linked-dir" in run.stderr, f"{themes}/real" in run.stderr), (2, True, True))
def intact():
    return ((themes / "linked-dir").is_symlink() and os.readlink(themes / "linked-dir") == str(elsewhere / "linked-dir"),
            (themes / "real/icons.theme").is_symlink() and os.readlink(themes / "real/icons.theme") == str(elsewhere / "icons.theme"),
            (elsewhere / "linked-dir/icons.theme").read_text(), (elsewhere / "icons.theme").read_text())
chk("both links and their targets are intact", intact(), (True, True, "Reversal\n", "Yaru\n"))
chk("an ordinary theme next to them is pointed at Icons", (themes / "plain/icons.theme").read_text().strip(), "Omarchroma-Icons")
run = cli("revert")
chk("(revert succeeds)", run.returncode, 0)
chk("they are still intact after revert", intact(), (True, True, "Reversal\n", "Yaru\n"))
f.done()

# 6. The service's revert command, on the default build -------------------------
print("# hyprchroma --target=icons --set-enabled=false --quiet --force")
f = Fixture()
tool = f.picture(f.home / ".local/opt/tool/tool.png")
f.entry("tool", tool)
themes = f.home / ".config/omarchy/themes"
(themes / "mine").mkdir(parents=True)
(themes / "mine/icons.theme").write_text("Yaru\n")
run = cli("apply")
chk("(the withIcons build applies)", run.returncode, 0)
state = f.home / ".local/state/hyprchroma"
(state / "settings.json").write_text(json.dumps({"frameworks": {"icons": False}}))
def revert_command(*extra):
    return subprocess.run([DEFAULT_PKG + "/bin/hyprchroma", "--target=icons", "--set-enabled=false", "--quiet", *extra],
                          capture_output=True, text=True, timeout=120)
applied = (icon_line(f.apps / "tool.desktop"), (f.public / "Reversal-sage").is_dir(), (f.home / ".icons/Omarchroma-Icons").is_dir())
chk("the apply rewrote the entry and made the sage and generated themes", applied, ("tool", True, True))
run = revert_command()
chk("without --force, settings already recording false leave it all",
    (run.returncode, icon_line(f.apps / "tool.desktop"), (f.public / "Reversal-sage").is_dir(), (f.home / ".icons/Omarchroma-Icons").is_dir()),
    (0, "tool", True, True))
run = revert_command("--force")
chk("with --force it reverts", (run.returncode, run.stderr), (0, ""))
chk("...the desktop line is the original", icon_line(f.apps / "tool.desktop"), str(tool))
chk("...the theme file is the user's own again", (themes / "mine/icons.theme").read_text(), "Yaru\n")
chk("...and the generated themes, sage included, are gone",
    ((f.public / "Reversal-sage").exists(), (f.public / "Reversal-sage-dark").exists(), (f.home / ".icons/Omarchroma-Icons").exists()),
    (False, False, False))
f.done()

# 7. A sage theme the user made is not Icons' to remove -------------------------
print("# a user-made Reversal-sage")
f = Fixture()
f.public.mkdir(parents=True)
for name in ("Reversal-sage", "Reversal-sage-dark"):
    (f.public / name / "places/scalable").mkdir(parents=True)
    (f.public / name / "index.theme").write_text(f"[Icon Theme]\nName={name}\n")
    (f.public / name / "places/scalable/folder.svg").write_text('<svg><path fill="#627867"/></svg>')
run = cli("apply")
chk("(apply succeeds)", run.returncode, 0)
chk("it carries no marker", (f.public / "Reversal-sage/.omarchroma-generated").exists(), False)
run = cli("revert")
chk("(revert succeeds)", run.returncode, 0)
chk("it survives revert, content and all",
    ((f.public / "Reversal-sage/places/scalable/folder.svg").read_text(), (f.public / "Reversal-sage-dark/index.theme").is_file()),
    ('<svg><path fill="#627867"/></svg>', True))
f.done()

sys.exit(1 if failures else 0)
PY
