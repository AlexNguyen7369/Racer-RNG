"""Regression checks for workspace isolation, Codex lifecycle, and dashboard edits."""
import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

import agent_bus
import server
from codex_activity import CodexActivity


SID = "11111111-1111-1111-1111-111111111111"
CHILD = "22222222-2222-2222-2222-222222222222"


def entry(typ, payload):
    return {"type": typ, "timestamp": "2026-10-06T20:00:00Z", "payload": payload}


def message(role, text, phase=None):
    return entry("response_item", {"type": "message", "role": role, "phase": phase,
                                   "content": [{"type": "output_text" if role == "assistant" else "input_text", "text": text}]})


class CodexFixture(unittest.TestCase):
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


class CodexTests(CodexFixture):
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


def item(kind, **fields):
    return entry("event_msg", {"type": "item_completed", "item": {"type": kind, **fields}})


class AttributionTests(CodexFixture):
    def test_codex_model_edits_and_commits_are_attributed(self):
        inside, outside = str(self.root / "src" / "a.luau"), str(self.home / "elsewhere.py")
        self.rollout(extra=[entry("turn_context", {"model": "gpt-test"}),
                            item("FileChange", changes={inside: {"type": "update"}, outside: {"type": "add"}}),
                            item("CommandExecution", aggregated_output="[feature/x 1a2b3c4d] Subject\n 1 file changed")])
        self.assertEqual([(e[0], e[2]) for e in self.activity.edits()], [(os.path.join("src", "a.luau"), "gpt-test")])
        self.assertEqual(self.activity.commits(), {"1a2b3c4": ("gpt-test", "codex")})
        self.assertEqual(self.activity.sessions()[0]["model"], "gpt-test")
        self.assertEqual(self.activity.presence()["files"], [os.path.join("src", "a.luau")])

    def test_model_labels_and_commit_trailers(self):
        self.assertEqual(agent_bus.model_label("claude-opus-5-5"), "Opus 5.5")
        self.assertEqual(agent_bus.model_label("claude-haiku-4-5-20251001"), "Haiku 4.5")
        self.assertEqual(agent_bus.model_label("<synthetic>"), "")
        self.assertEqual(agent_bus.model_label("gpt-6.1-sol"), "gpt-6.1-sol")
        agents = server.commit_agents("abcdef1234", "Claude Opus 5.5 <noreply@anthropic.com>\x1dCodex", {})
        self.assertEqual([(a["agent"], a["model"]) for a in agents], [("claude", "Opus 5.5"), ("codex", "")])
        logged = {"abcdef1": {"agent": "codex", "model": "gpt-test", "role": "codex"}}
        self.assertEqual(server.commit_agents("abcdef1234", "", logged)[0]["model"], "gpt-test")
        self.assertEqual(server.commit_agents("abcdef1234", "Alex <a@b.c>", {}), [])

    def test_only_edits_since_the_last_commit_label_a_change(self):
        rows = [{"agent": "codex", "model": "m", "role": "codex", "ts": "2026-10-06T10:00:00Z"},
                {"agent": "claude", "model": "Opus 5.5", "role": "main", "ts": "2026-10-06T12:00:00Z"},
                {"agent": "claude", "model": "Opus 5.5", "role": "main", "ts": "2026-10-06T13:00:00Z"}]
        since = server.iso_epoch("2026-10-06T11:00:00Z")
        self.assertEqual([(r["agent"], r["ts"]) for r in server.label_edits(rows, since)], [("claude", "2026-10-06T13:00:00Z")])


class BusTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        patcher = patch.object(agent_bus, "BUS", tmp.name)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_messages_reach_only_their_reader_once(self):
        a = agent_bus.send("codex", "claude", "Please review server.py", model="gpt-test")
        b = agent_bus.send("user", "all", "Both: stop at 6")
        agent_bus.send("claude", "codex", "On it", re_id=a["id"])
        self.assertEqual(a["model"], "gpt-test")
        self.assertEqual([m["id"] for m in agent_bus.unread("claude")], [a["id"], b["id"]])
        self.assertEqual([m["text"] for m in agent_bus.unread("codex")], ["Both: stop at 6", "On it"])
        agent_bus.mark_read("claude", agent_bus.unread("claude"))
        self.assertEqual(agent_bus.unread("claude"), [])
        c = agent_bus.send("codex", "claude", "same second")
        self.assertEqual([m["id"] for m in agent_bus.unread("claude")], [c["id"]])

    def test_bad_messages_and_status(self):
        self.assertIn("error", agent_bus.send("codex", "codex", "self"))
        self.assertIn("error", agent_bus.send("someone", "claude", "x"))
        self.assertIn("error", agent_bus.send("claude", "codex", "   "))
        agent_bus.set_status("codex", "Racer UI tests", ["src/a.luau"], model="gpt-test")
        self.assertEqual(agent_bus.statuses()["codex"]["files"], ["src/a.luau"])
        agent_bus.set_status("codex", clear=True)
        self.assertNotIn("codex", agent_bus.statuses())
        self.assertIn("error", agent_bus.set_status("user", "x"))

    def test_page_posts_go_through_the_bus_and_network_stays_read_only(self):
        r = BoardTests.request(object(), "/api/bus", {"action": "send", "from": "user", "to": "codex", "text": "hi"})
        self.assertEqual(r[0], 200)
        self.assertEqual(agent_bus.unread("codex")[0]["text"], "hi")
        with patch.object(server.Handler, "lan_write", False):
            self.assertEqual(BoardTests.request(object(), "/api/bus", {"action": "send", "to": "codex", "text": "x"}, local=False)[0], 403)


if __name__ == "__main__":
    unittest.main()
