"""替身命令验证新机启动流程，不联网、不安装软件。"""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
FAKE_TOOL = r'''
import json
import os
from pathlib import Path
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
root = Path(os.environ["BOOTSTRAP_TEST_ROOT"])
with (root / "calls.jsonl").open("a") as log:
    log.write(json.dumps([name, *args]) + "\n")
if os.environ.get("BOOTSTRAP_TEST_FAIL") == name + ":" + (args[0] if args else ""):
    sys.exit(7)
ready = root / "tools-ready"
if name == "uname":
    print(os.environ.get("BOOTSTRAP_TEST_OS", "Darwin"))
elif name == "xcode-select":
    if args == ["--install"]:
        (root / "tools-requested").touch()
    elif ready.exists():
        print("/Library/Developer/CommandLineTools")
    else:
        sys.exit(1)
elif name == "xcrun":
    if not ready.exists():
        sys.exit(1)
    print("/usr/bin/git")
elif name == "sleep":
    if (root / "tools-requested").exists():
        ready.touch()
elif name == "git":
    workdir = None
    if args[:1] == ["-C"]:
        workdir, args = Path(args[1]), args[2:]
    if os.environ.get("BOOTSTRAP_TEST_GIT_FAIL") == args[0]:
        sys.exit(7)
    if args == ["--version"]:
        print("git version test")
    elif args[0] == "clone":
        target = Path(args[-1])
        target.mkdir()
        (target / ".git").mkdir()
        (target / "setup.sh").write_text("# setup fixture\n")
    elif args[0] == "rev-parse":
        print(workdir.resolve())
    elif args[0] == "remote":
        print(os.environ.get("BOOTSTRAP_TEST_ORIGIN", "git@github.com:ovislab/dotfiles.git"))
    elif args[0] == "status":
        print(os.environ.get("BOOTSTRAP_TEST_CHANGES", ""), end="")
    elif args[0] == "symbolic-ref":
        print(os.environ.get("BOOTSTRAP_TEST_BRANCH", "main"))
    elif args[0] != "pull":
        raise RuntimeError(args)
elif name == "gh":
    if args[:2] == ["auth", "status"]:
        sys.exit(0 if (root / "logged-in").exists() else 1)
    if os.environ.get("BOOTSTRAP_TEST_GH_FAIL") == args[1]:
        sys.exit(7)
    if args[:2] == ["auth", "login"]:
        (root / "logged-in").touch()
elif name == "brew":
    sys.exit(7)
elif name != "zsh":
    raise RuntimeError(name)
'''


class ScriptFixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles bootstrap ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        tool = self.bin / "fake-tool"
        tool.write_text("#!" + sys.executable + "\n" + FAKE_TOOL)
        tool.chmod(0o755)
        for name in ["uname", "xcode-select", "xcrun", "sleep", "git", "zsh", "gh", "brew"]:
            (self.bin / name).symlink_to(tool)
        self.env = dict(os.environ)
        self.env.update(
            PATH=str(self.bin) + ":/usr/bin:/bin",
            BOOTSTRAP_TEST_ROOT=str(self.root),
            DOTFILES_BOOTSTRAP_DIR=str(self.root / "dotfiles"),
        )

    def run_script(self, script, expected=0):
        # 模拟 /bin/bash -c "$(curl ...)"，入口不能依赖本地 $0 所在目录。
        result = subprocess.run(
            ["/bin/bash", "-c", script.read_text()], env=self.env,
            capture_output=True, text=True, timeout=15,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def calls(self, name):
        path = self.root / "calls.jsonl"
        entries = [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []
        return [entry[1:] for entry in entries if entry[0] == name]


@unittest.skipIf(os.geteuid() == 0, "启动入口要求普通用户")
class BootstrapTests(ScriptFixture):
    def run_bootstrap(self, expected=0):
        return self.run_script(REPO / "bootstrap.sh", expected)

    def existing_repo(self):
        target = Path(self.env["DOTFILES_BOOTSTRAP_DIR"])
        target.mkdir()
        (target / "setup.sh").write_text("# setup fixture\n")
        (self.root / "tools-ready").touch()
        return target

    def test_new_mac_waits_for_tools_then_clones_and_runs_setup(self):
        self.run_bootstrap()
        self.assertIn(["--install"], self.calls("xcode-select"))
        self.assertTrue(self.calls("sleep"))
        clones = [args for args in self.calls("git") if args[0] == "clone"]
        self.assertEqual(len(clones), 1)
        self.assertIn("https://github.com/ovislab/dotfiles.git", clones[0])
        self.assertEqual(self.calls("zsh"), [[str(self.root / "dotfiles/setup.sh")]])
        self.assertEqual(self.calls("gh"), [])

    def test_existing_ssh_repo_updates_over_https_without_changing_origin(self):
        target = self.existing_repo()
        self.run_bootstrap()
        self.assertIn(
            ["-C", str(target), "pull", "--ff-only", "https://github.com/ovislab/dotfiles.git", "main"],
            self.calls("git"),
        )
        self.assertFalse(any("set-url" in args for args in self.calls("git")))
        self.assertNotIn(["--install"], self.calls("xcode-select"))

    def test_dirty_wrong_branch_and_unrelated_repo_stop(self):
        self.existing_repo()
        for key, value in [
            ("BOOTSTRAP_TEST_CHANGES", " M setup.sh\n"),
            ("BOOTSTRAP_TEST_BRANCH", "feature"),
            ("BOOTSTRAP_TEST_ORIGIN", "https://github.com/other/repo.git"),
        ]:
            with self.subTest(key=key):
                self.env[key] = value
                self.run_bootstrap(expected=1)
                del self.env[key]
        self.assertEqual(self.calls("zsh"), [])

    def test_install_clone_pull_and_setup_failures_stop(self):
        self.env["BOOTSTRAP_TEST_FAIL"] = "xcode-select:--install"
        self.run_bootstrap(expected=7)
        self.assertEqual(self.calls("git"), [])
        del self.env["BOOTSTRAP_TEST_FAIL"]
        (self.root / "tools-ready").touch()
        self.env["BOOTSTRAP_TEST_GIT_FAIL"] = "clone"
        self.run_bootstrap(expected=7)
        self.assertEqual(self.calls("zsh"), [])
        target = self.existing_repo()
        self.env["BOOTSTRAP_TEST_GIT_FAIL"] = "pull"
        self.run_bootstrap(expected=7)
        self.assertEqual(self.calls("zsh"), [])
        del self.env["BOOTSTRAP_TEST_GIT_FAIL"]
        self.env["BOOTSTRAP_TEST_FAIL"] = "zsh:" + str(target / "setup.sh")
        self.run_bootstrap(expected=7)

    def test_status_failure_cannot_be_treated_as_clean(self):
        self.existing_repo()
        self.env["BOOTSTRAP_TEST_GIT_FAIL"] = "status"
        self.run_bootstrap(expected=7)
        self.assertEqual(self.calls("zsh"), [])

    def test_rejects_unsupported_system_and_target_file(self):
        self.env["BOOTSTRAP_TEST_OS"] = "Linux"
        self.run_bootstrap(expected=1)
        self.assertEqual(self.calls("git"), [])
        del self.env["BOOTSTRAP_TEST_OS"]
        (self.root / "tools-ready").touch()
        target = Path(self.env["DOTFILES_BOOTSTRAP_DIR"])
        target.write_text("保留")
        self.run_bootstrap(expected=1)
        self.assertEqual(target.read_text(), "保留")


class GitHubSetupTests(ScriptFixture):
    def test_new_login_uses_browser_and_https_then_configures_git(self):
        self.run_script(REPO / "scripts/setup-github.sh")
        self.assertEqual(self.calls("gh"), [
            ["auth", "status", "--hostname", "github.com"],
            ["auth", "login", "--hostname", "github.com", "--git-protocol", "https", "--web"],
            ["auth", "setup-git", "--hostname", "github.com"],
        ])

    def test_existing_login_is_reused_but_credential_helper_is_reapplied(self):
        (self.root / "logged-in").touch()
        self.run_script(REPO / "scripts/setup-github.sh")
        self.assertFalse(any(args[1] == "login" for args in self.calls("gh")))
        self.assertIn(["auth", "setup-git", "--hostname", "github.com"], self.calls("gh"))

    def test_authentication_failure_does_not_claim_success(self):
        self.env["BOOTSTRAP_TEST_GH_FAIL"] = "login"
        result = self.run_script(REPO / "scripts/setup-github.sh", expected=7)
        self.assertNotIn("GitHub CLI 已登录", result.stdout)
        self.assertFalse(any(args[1] == "setup-git" for args in self.calls("gh")))

    def test_setup_stops_on_brew_failure_before_deploying_configuration(self):
        result = subprocess.run(
            ["/bin/zsh", str(REPO / "setup.sh")], env=self.env,
            capture_output=True, text=True, timeout=15,
        )
        self.assertEqual(result.returncode, 7, result.stdout + result.stderr)
        self.assertNotIn("环境配置完成", result.stdout)
        self.assertEqual(self.calls("gh"), [])


if __name__ == "__main__":
    unittest.main()
