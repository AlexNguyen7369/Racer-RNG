"""Regression checks for workspace isolation, Codex lifecycle, and dashboard edits."""
import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

import server
from codex_activity import CodexActivity


SID = "11111111-1111-1111-1111-111111111111"
CHILD = "22222222-2222-2222-2222-222222222222"


def entry(typ, payload):
    return {"type": typ, "timestamp": "2026-10-06T20:00:00Z", "payload": payload}


def message(role, text, phase=None):
    return entry("response_item", {"type": "message", "role": role, "phase": phase,
                                   "content": [{"type": "output_text" if role == "assistant" else "input_text", "text": text}]})


class CodexTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.root = self.home / "workspace"
        self.root.mkdir()
        self.logdir = self.home / "sessions" / "2026" / "10" / "06"
        self.logdir.mkdir(parents=True)
        self.activity = CodexActivity(str(self.root), str(self.home))

    def rollout(self, sid=SID, cwd=None, source="vscode", extra=()):
        path = self.logdir / f"rollout-{sid}.jsonl"
        rows = [entry("session_meta", {"id": sid, "cwd": str(cwd or self.root), "source": source}), *extra]
        path.write_text("\n".join(json.dumps(row) for row in rows) + "\n")
        return path

    def test_only_this_workspace_and_children_are_visible(self):
        self.rollout(extra=[message("user", "Build dashboard")])
        self.rollout(CHILD, cwd=self.root / "subdir", source={"subagent": {"thread_spawn": {
            "parent_thread_id": SID, "agent_role": "reviewer"}}})
        self.rollout("other", cwd=self.home / "workspace-other")
        self.assertEqual([s["id"] for s in self.activity.sessions()], ["codex-" + SID])
        self.assertEqual(self.activity.sessions()[0]["agents"], 2)
        self.assertEqual({a["type"] for a in self.activity.agents("codex-" + SID)}, {"codex", "reviewer"})
        self.assertIsNone(self.activity.agent_timeline("codex-" + SID, "other"))
        self.assertEqual(self.activity.messages("codex-../../elsewhere"), [])

    def test_only_user_visible_messages_and_tools_are_displayed(self):
        self.rollout(extra=[message("system", "PRIVATE SYSTEM"), message("developer", "PRIVATE DEVELOPER"),
                            message("user", "<environment_context>metadata</environment_context>"),
                            entry("response_item", {"type": "reasoning", "summary": "PRIVATE REASONING"}),
                            message("user", "Build dashboard"), message("assistant", "Working", "commentary"),
                            entry("response_item", {"type": "custom_tool_call", "name": "functions.exec", "input": "code"}),
                            entry("response_item", {"type": "custom_tool_call_output", "output": "result"}),
                            entry("response_item", {"type": "function_call", "name": "exec_command", "arguments": "{}"}),
                            message("assistant", "Finished", "final_answer")])
        items = self.activity.messages("codex-" + SID)
        self.assertEqual([i["kind"] for i in items], ["prompt", "say", "tool", "result", "tool", "report"])
        self.assertNotIn("PRIVATE", json.dumps(items))

    def test_resumed_turn_clears_previous_report(self):
        path = self.rollout(extra=[entry("event_msg", {"type": "task_started"}),
                                   message("assistant", "Finished", "final_answer"),
                                   entry("event_msg", {"type": "task_complete", "last_agent_message": "Finished"})])
        self.assertEqual(self.activity.agents("codex-" + SID)[0]["status"], "done")
        with path.open("a") as f:
            f.write(json.dumps(entry("event_msg", {"type": "task_started"})) + "\n")
        agent = self.activity.agents("codex-" + SID)[0]
        self.assertEqual(agent["status"], "running")
        self.assertEqual(agent["report"], "")
        self.assertIsNone(agent["verdict"])
        os.utime(path, (0, 0))
        self.assertEqual(self.activity.agents("codex-" + SID)[0]["status"], "stopped")

    def test_malformed_partial_records_and_missing_logs(self):
        path = self.rollout(extra=[message("user", "Task")])
        with path.open("a") as f:
            f.write("{unfinished")
        self.assertEqual(len(self.activity.messages("codex-" + SID)), 1)
        path.unlink()
        self.assertEqual(self.activity.sessions(), [])
        self.assertEqual(self.activity.agents("codex-" + SID), [])

    def test_server_dispatches_codex_and_preserves_claude(self):
        self.rollout(extra=[message("user", "Task")])
        claude = self.home / "claude"
        claude.mkdir()
        (claude / f"{CHILD}.jsonl").write_text(json.dumps({"type": "ai-title", "aiTitle": "Claude task"}) + "\n")
        with patch.object(server, "CODEX", self.activity), patch.object(server, "TRANSCRIPTS", str(claude)):
            self.assertEqual({s["source"] for s in server.sessions()}, {"claude", "codex"})
            self.assertEqual(server.agents("codex-" + SID)[0]["type"], "codex")
            self.assertEqual(server.messages("codex-" + SID)[0]["text"], "Task")
            self.assertIsNotNone(server.agent_timeline("codex-" + SID, SID))
            self.assertEqual(server.agents(CHILD), [])


class BoardTests(unittest.TestCase):
    def request(self, path, body, local=True):
        handler = object.__new__(server.Handler)
        handler.path = path
        data = json.dumps(body).encode()
        handler.headers = {"Content-Length": str(len(data))}
        handler.rfile = io.BytesIO(data)
        handler.client_address = ("127.0.0.1" if local else "192.0.2.1", 1234)
        handler.send = Mock()
        handler.do_POST()
        return handler.send.call_args.args

    def test_board_edits_sync_readme_without_git_actions(self):
        with tempfile.TemporaryDirectory() as tmp:
            todo, readme = Path(tmp) / "todo.json", Path(tmp) / "README.md"
            todo.write_text('{"items": []}')
            readme.write_text("User introduction\n" + server.readme_sync.START + "\n" + server.readme_sync.END + "\nUser footer\n")
            with patch.object(server, "TODO_FILE", str(todo)), \
                    patch.object(server.readme_sync, "TODO", str(todo)), \
                    patch.object(server.readme_sync, "README", str(readme)), \
                    patch.object(server, "developer", return_value="Test user"), \
                    patch.object(server, "AUTO_BRANCH", False), patch.object(server, "start_branch") as branch:
                code, board = self.request("/api/todo", {"action": "add", "title": "Integration check", "status": "backlog"})
                self.assertEqual(code, 200)
                tid = board["items"][0]["id"]
                self.assertIn("Integration check", readme.read_text())
                code, _ = self.request("/api/todo", {"action": "move", "id": tid, "status": "doing"})
                self.assertEqual(code, 200)
                branch.assert_not_called()
                code, _ = self.request("/api/todo", {"action": "move", "id": tid, "status": "done"})
                self.assertEqual(code, 200)
                self.assertTrue(json.loads(todo.read_text())["items"][0]["done"])
                self.assertTrue(readme.read_text().startswith("User introduction\n"))
                self.assertTrue(readme.read_text().endswith("User footer\n"))
                code, _ = self.request("/api/todo", {"action": "delete", "id": tid})
                self.assertEqual(code, 200)
                self.assertEqual(json.loads(todo.read_text())["items"], [])

    def test_network_clients_cannot_edit_or_perform_git_actions(self):
        with patch.object(server.Handler, "lan_write", False):
            self.assertEqual(self.request("/api/todo", {"action": "add"}, local=False)[0], 403)
        with patch.object(server.Handler, "lan_write", True), patch.object(server, "team_action") as action:
            self.assertEqual(self.request("/api/team/push", {}, local=False)[0], 403)
            action.assert_not_called()


if __name__ == "__main__":
    unittest.main()
