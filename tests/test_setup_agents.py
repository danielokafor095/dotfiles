"""在独立目录验证指令迁移，不修改真实用户配置。"""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / "scripts/setup-agents.sh"
SOURCE = REPO / "agents/AGENTS.md"


class SetupAgentsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles agents ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = {
            key: value for key, value in os.environ.items()
            if key not in {"CODEX_HOME", "CLAUDE_CONFIG_DIR"}
        }
        self.env["DOTFILES_AGENT_HOME"] = str(self.root)
        self.targets = [
            self.root / "AGENTS.md",
            self.root / ".codex/AGENTS.md",
            self.root / ".claude/CLAUDE.md",
            self.root / ".gemini/GEMINI.md",
        ]

    def run_script(self, *args, expected=0):
        result = subprocess.run(
            ["zsh", str(SCRIPT), *args], env=self.env,
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        return result

    def backups(self):
        return list((self.root / ".local/state/dotfiles/agents-backups").glob("*/*"))

    def assert_targets(self):
        for target in self.targets:
            self.assertTrue(target.is_symlink(), str(target))
            self.assertEqual(os.readlink(target), str(SOURCE))
            self.assertEqual(target.read_bytes(), SOURCE.read_bytes())

    def test_fresh_install_and_repeat_without_new_backups(self):
        self.run_script()
        self.assert_targets()
        mtimes = [target.lstat().st_mtime_ns for target in self.targets]
        self.run_script()
        self.run_script("--check")
        self.assert_targets()
        self.assertEqual(mtimes, [target.lstat().st_mtime_ns for target in self.targets])
        self.assertFalse(self.backups())

    def test_migrates_files_links_and_legacy_claude_with_backups(self):
        self.targets[0].write_text("原用户指令", encoding="utf-8")
        self.targets[1].parent.mkdir()
        self.targets[1].write_text("旧 Codex 指令", encoding="utf-8")
        self.targets[2].parent.mkdir()
        external = self.root / "独立规则.md"
        external.write_text("独立规则", encoding="utf-8")
        self.targets[2].symlink_to(external)
        self.targets[3].parent.mkdir()
        self.targets[3].symlink_to(self.root / "不存在.md")
        legacy = self.root / "CLAUDE.md"
        legacy.symlink_to(self.targets[0])

        self.run_script()
        self.assert_targets()
        self.assertFalse(legacy.is_symlink())
        self.assertEqual(external.read_text(encoding="utf-8"), "独立规则")
        backups = self.backups()
        self.assertEqual(len(backups), 5)
        texts = {p.read_text(encoding="utf-8") for p in backups if not p.is_symlink()}
        self.assertEqual(texts, {"原用户指令", "旧 Codex 指令"})
        self.assertEqual(sum(p.is_symlink() for p in backups), 3)
        self.run_script()
        self.assertEqual(len(self.backups()), 5)

    def test_check_does_not_create_or_change_files(self):
        self.run_script("--check", expected=1)
        self.assertEqual(list(self.root.iterdir()), [])
        self.run_script()
        self.targets[1].unlink()
        self.targets[1].write_text("独立配置", encoding="utf-8")
        self.run_script("--check", expected=1)
        self.assertEqual(self.targets[1].read_text(encoding="utf-8"), "独立配置")
        self.assertFalse(self.backups())

    def test_directory_collision_stops_before_migrating(self):
        self.targets[0].write_text("保留", encoding="utf-8")
        self.targets[3].mkdir(parents=True)
        self.run_script(expected=1)
        self.assertFalse(self.targets[0].is_symlink())
        self.assertEqual(self.targets[0].read_text(encoding="utf-8"), "保留")
        self.assertFalse(self.backups())

    def test_parent_file_collision_stops_before_migrating(self):
        self.targets[0].write_text("保留", encoding="utf-8")
        (self.root / ".gemini").write_text("文件", encoding="utf-8")
        self.run_script(expected=1)
        self.assertFalse(self.targets[0].is_symlink())
        self.assertFalse(self.backups())

    def test_normalizes_indirect_links_to_direct_links(self):
        self.targets[0].symlink_to(SOURCE)
        self.targets[1].parent.mkdir()
        self.targets[1].symlink_to(self.targets[0])
        self.run_script()
        self.assert_targets()
        self.assertEqual(len(self.backups()), 1)

    def test_override_is_preserved_and_reported(self):
        self.run_script()
        override = self.root / ".codex/AGENTS.override.md"
        override.write_text("临时覆盖", encoding="utf-8")
        result = self.run_script("--check", expected=1)
        self.assertIn("AGENTS.override.md", result.stderr)
        self.assertEqual(override.read_text(encoding="utf-8"), "临时覆盖")

    def test_unrelated_legacy_claude_is_preserved(self):
        legacy = self.root / "CLAUDE.md"
        legacy.write_text("独立内容", encoding="utf-8")
        result = self.run_script()
        self.assertIn("CLAUDE.md 仍存在", result.stderr)
        self.assertEqual(legacy.read_text(encoding="utf-8"), "独立内容")


if __name__ == "__main__":
    unittest.main()
