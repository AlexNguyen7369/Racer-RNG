#!/usr/bin/env python3
"""PostToolUse hook. Two reminders, combined into one message:
1. A track spec or track test was written: the test-first subagent loop is mandatory and only ends on a
   fully green suite.
2. Any project file was written (src/, CLAUDE.md, .claude/): keep context/ProjectContext.luau current."""
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

path = (data.get("tool_input") or {}).get("file_path", "")
name = path.rsplit("/", 1)[-1]
messages = []

if "/src/shared/Tracks/" in path or "/src/server/CarTest/TrackTests/" in path:
    messages.append(
        "Track work detected ("
        + name
        + "). Every track build must run the test-first loop in .claude/commands/build-track.md: "
        "test-writer -> red run -> track-designer/physics-tuner -> test-writer audit -> full physics-tester run, "
        "repeated until '[CARTEST] END fail=0'. The Track rules in CLAUDE.md apply (numbered, separate start/finish, "
        "wide checkpoint, left-hand winnings pad paying $, right-hand lane, auto-race speed, never flipping, "
        "60-stud proximity text). Do not report the track as done before that."
    )

is_project_file = "/src/" in path or path.endswith("/CLAUDE.md") or "/.claude/" in path
if is_project_file and not path.endswith("ProjectContext.luau"):
    messages.append(
        "Keep context/ProjectContext.luau (Studio: ServerScriptService > ProjectContext) current: update its "
        "change log and dated test results at the end of the loop."
    )

if messages:
    print(
        json.dumps(
            {"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": " ".join(messages)}}
        )
    )
