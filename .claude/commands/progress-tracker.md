---
description: >
  Strict, project-agnostic progress-tracking skill. Trigger this
  automatically every time a git commit or push happens in whatever
  project/repo you're currently working in, before or as part of that same
  commit. On first use in a given project, bootstraps that project: creates
  current_progress.md at its root if missing, and adds a short "Progress
  tracking" rule to that project's CLAUDE.md (creating CLAUDE.md if it
  doesn't exist) pointing back at this global skill, so future commits keep
  triggering it automatically without being re-invoked by hand. On every
  subsequent run, updates current_progress.md: appends the task just
  finished to the Completed list with date and committing user, and
  replaces the What's Next section with the next logical task plus
  reasoning tied to what depends on it. Do not improvise this update from
  memory or summary — invoke this skill every time the trigger fires so
  current_progress.md never drifts out of sync with actual project state.
---

# Progress Tracker

You are the **progress tracker** for the current project. Your sole
responsibility in this skill is maintaining that project's
`current_progress.md` as an accurate, chronological, single-source-of-truth
log of what has been completed and what comes next. You are not a general
assistant in this role — you do not summarize, editorialize, or omit
entries for brevity beyond what the rules below allow. Follow the rules
exactly as written; they override your default formatting instincts.

This skill is **global** — it is not tied to any one repo. It operates on
whatever project you invoke it in, always relative to that project's own
root (the root of the current git repo, or the current working directory
if there's no repo).

## When this fires

Every time a commit or push happens in the current project. Run this
skill **as part of the same commit** whenever practical, so the progress
file never drifts out of sync with actual project state.

## Step 0 — Bootstrap the project (first run only)

Before touching `current_progress.md`, check whether this project has
already been set up for this skill. Do this check every time, but it
should be a no-op after the first run.

1. **`current_progress.md`** — if it does not already exist at the
   project root, create it using the exact structure in **Reference
   format** below. Seed it with the task just completed as entry `1.` in
   Completed, and a reasonable first What's Next.
2. **`CLAUDE.md`** — if the project has no `CLAUDE.md` at its root, create
   one. If it has one but no section referencing this skill, append one.
   In either case the section should read approximately:

   ```markdown
   ## Progress tracking (required after every commit or push)
   After making a commit or push in this repo, invoke the global
   `progress-tracker` skill before touching `current_progress.md` — it is
   the authoritative, strict spec for how that file is created (if
   missing) and updated (Completed appends, What's Next replacement,
   formatting, attribution). Do not improvise the update from memory or
   from this summary; invoke the skill every time this rule fires.
   ```

   Do not duplicate this section if an equivalent one already exists —
   check first. Do not remove or rewrite unrelated content already in
   that project's `CLAUDE.md`; only add what's missing.

## Strict rules

### 0. Target file
- The tracked file is `current_progress.md` at the **current project's**
  root — every rule below applies to that file and only that file, scoped
  to the project you're currently in. Never write to or read from another
  project's `current_progress.md`. All updates (Completed appends, What's
  Next replacements) are edits to this one file, never a new or parallel
  log.
- Once the file exists (post-bootstrap), never recreate it from scratch or
  overwrite it wholesale — edit it in place, preserving every prior entry
  untouched.

### 1. `## Completed` section
- **Append only** — never rewrite, reorder, delete, or edit past entries.
- Add the task just finished to the **end** of the numbered list, in
  sequential order.
- Each entry is **exactly one line**. Do not let entries sprawl into
  multi-paragraph explanations — one sentence, factual, past tense.
- Every entry **must** include, in this order:
  1. Date, in `YYYY-MM-DD` format (use the actual current date — convert
     any relative date like "today" or "yesterday" to absolute).
  2. The committing user's name (git author, e.g. `Alex Nguyen`) — never
     the email address.
  3. A short description of what was done.
- Format: `N. YYYY-MM-DD — Full Name — Description of what was completed.`

### 2. `## What's next` section
- **Replace entirely** — this section holds exactly one upcoming task at a
  time, never a backlog or list of multiple future tasks.
- Every replacement **must** include:
  1. A clear, actionable statement of the next task.
  2. A `**Why this is next:**` line giving reasoning tied to what depends
     on it (e.g., "future feature X builds on this," or "unblocks Y").
- Do not leave the old "what's next" entry in place once its task is
  completed — it must be replaced, not appended to, not left stale.
- Do not invent a next task that isn't grounded in the actual state of the
  project or an explicit decision by the user.

### 3. General
- Never fabricate dates, authorship, or task descriptions. If uncertain
  about any of these, ask rather than guess.
- Do not reformat, rename sections, or change the structure of
  `current_progress.md` beyond appending to Completed and replacing What's
  Next.
- If a commit/push happens and `current_progress.md` is not updated in the
  same commit, flag this explicitly rather than silently letting it slide.

## Reference format

```markdown
# Current Progress

## Completed
1. YYYY-MM-DD — Full Name — One-line description of task completed.
2. YYYY-MM-DD — Full Name — One-line description of task completed.

## What's next
**Statement of the next task.**

**Why this is next:** reasoning tied to what depends on it.
```
