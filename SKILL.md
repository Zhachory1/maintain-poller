---
name: maintain-poller
description: "Install, update, or remove a macOS launchd poller that maintains the user's own open GitHub PRs: fixes in-scope review feedback and CI failures, and files issues for out-of-scope work, using the bundled pr-review-handler skill. Triggers: install maintain poller, update maintain poller, set up PR maintenance agent, auto-fix my PR feedback, stop maintain poller, uninstall maintain poller, maintain poller broken."
---

# Maintain Poller

`maintain-poller.sh` runs one pass. For each open, non-draft PR the `gh` user authored, it runs the user's agent with the bundled `skills/pr-review-handler/SKILL.md` when either is true:

- someone else left a review, PR comment, or inline comment newer than the last handled run;
- CI failed at a head SHA not yet handled.

It skips PRs while any check is pending, PRs from forks, and PRs with the `no-maintain` label. The user's own replies never trigger a run. There is no run cap. Each run works in a fresh git worktree at the PR's head SHA under `~/.local/state/maintain-poller/worktrees`, which is removed afterwards, so it never touches the user's own checkouts. The agent fixes in-scope feedback and CI, pushes to the PR branch (never force), and files repo issues for anything outside the PR's scope. A failed run is retried on the next pass. Handled keys live in `~/.local/state/maintain-poller/handled`.

Install only on macOS. When the user asks you to install the poller, do these steps:

- **Clone.** Run `git clone https://github.com/Zhachory1/maintain-poller ~/.local/share/maintain-poller`, then check out the newest release tag: `git -C ~/.local/share/maintain-poller checkout "$(git -C ~/.local/share/maintain-poller tag --sort=-v:refname | head -1)"`. If the folder already exists, follow Update instead. launchd runs the script from this path, so do not move it.
- **Check auth.** Confirm `gh auth status` succeeds, its token can push to the user's PR branches, and `jq` is installed. Commits, replies, and issues post as this GitHub account. Pushes use `gh` as the git credential helper, set only in the poller's own clones.
- **Agent command.** Ask the user for their agent command. It must run non-interactively, take the prompt as its last argument, and be allowed to edit files and run `git`, `gh`, and the repos' test commands, for example `claude -p --permission-mode acceptEdits --allowedTools "Bash(git:*)" "Bash(gh:*)" "Bash(npm test:*)"`. The agent works without supervision, so prefer an allowlist over skipping permissions. Use exactly what the user gives you; do not guess.
- **Interval.** Ask how often to poll (default 600 seconds).
- **Opt-out label.** Tell the user they can add the `no-maintain` label to any PR the poller should leave alone.
- **Write plist.** Write `~/Library/LaunchAgents/com.zhachory1.maintain-poller.plist` with this template. Replace each placeholder: `__POLLER_PATH__` with the absolute path of `~/.local/share/maintain-poller/maintain-poller.sh`, `__AGENT_CMD__` with the agent command, `__TOOL_PATH__` with the directories that contain `gh`, `jq`, and the agent CLI (`dirname "$(command -v gh)"`, etc.), and `__HOME__` with the user's home directory. Replace only the placeholders; do not change key names such as `PR_MAINTAIN_AGENT_CMD`. Afterwards no `__` placeholder may remain. XML-escape the values (`&` → `&amp;`, `<` → `&lt;`, `"` → `&quot;`). Set `StartInterval` to the chosen interval.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.zhachory1.maintain-poller</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>__POLLER_PATH__</string></array>
  <key>EnvironmentVariables</key><dict>
    <key>PATH</key><string>__TOOL_PATH__:/usr/bin:/bin</string>
    <key>PR_MAINTAIN_AGENT_CMD</key><string>__AGENT_CMD__</string>
  </dict>
  <key>StartInterval</key><integer>600</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>__HOME__/Library/Logs/maintain-poller.log</string>
  <key>StandardErrorPath</key><string>__HOME__/Library/Logs/maintain-poller.log</string>
</dict></plist>
```

- **Load.** Run `plutil -lint` on the plist, then `launchctl bootstrap gui/$(id -u) <plist>`. If the job is already loaded (update), run `launchctl bootout gui/$(id -u)/com.zhachory1.maintain-poller` first. Check `~/Library/Logs/maintain-poller.log` after the first run.
- **Tell the agent.** Add the block below to the user's global agent instructions so their interactive agent knows the poller exists. Use the file that the user's agent reads: `~/.claude/CLAUDE.md` for Claude Code, `~/.codex/AGENTS.md` for Codex, otherwise `~/AGENTS.md`. If you are not sure, ask. Create the file if it does not exist. If the markers already exist, replace the text between them; do not add a second block. Show the user the file path and the block before you write.

```markdown
<!-- maintain-poller:start -->
## Local PR maintenance poller

A launchd job (`com.zhachory1.maintain-poller`) runs on this Mac. When someone else reviews or comments on one of my open PRs, or its CI fails, it runs `~/.local/share/maintain-poller/skills/pr-review-handler/SKILL.md` on that PR. It pushes in-scope fixes to the PR branch as me, replies on threads, and files repo issues for out-of-scope requests.

- Before editing one of my PR branches by hand, pull first: the poller may have pushed fixes.
- If I ask you to handle review feedback on my PR, use the same skill and its Scope Rule.
- This does not apply to a run that the poller starts. Its prompt names a PR and a worktree; do that maintenance.
- To make the poller leave a PR alone, add the `no-maintain` label.
- Log: `~/Library/Logs/maintain-poller.log`. Handled keys: `~/.local/state/maintain-poller/handled`.
- To stop, update, or debug the poller, follow `~/.local/share/maintain-poller/SKILL.md`.
<!-- maintain-poller:end -->
```

- **Run again.** To make the poller handle a PR again without new feedback, delete that PR's lines from the handled file.

launchd does not start a second run of a job while the first is still running, so the poller needs no lock. The first pass handles every open PR the user authored that has feedback from others or failing CI, so tell the user how many are open (`gh search prs --author @me --state open --json number --jq length`) before you load the plist, and suggest `no-maintain` for any they want left alone.

## Update

Releases are git tags (`v0.1.0`, `v0.2.0`, ...). Install only tagged releases, never `main`. Each pass of the poller fetches tags and switches to the newest `v*` tag on its own, so script fixes apply without the user doing anything. If a new release changes `SKILL.md`, the log says `changes install steps; ask your agent to update the maintain poller`. If local edits block the switch, the log says `could not check out`. The steps below are for those cases, for a and for rollback.

When the user asks you to update the poller, do these steps:

- **Find versions.** Run `git -C ~/.local/share/maintain-poller fetch --tags`. The current version is `git -C ~/.local/share/maintain-poller describe --tags`. The newest is `git -C ~/.local/share/maintain-poller tag --sort=-v:refname | head -1`. If they match, tell the user they are up to date and stop.
- **Show changes.** Show the user the newest tag's message (`git -C ~/.local/share/maintain-poller tag -l --format='%(contents)' <new>`) and the files that changed (`git -C ~/.local/share/maintain-poller diff --stat <current> <new>`). Ask before you continue.
- **Check out.** Run `git -C ~/.local/share/maintain-poller checkout <new>`. If git refuses because of local changes, show them to the user and stop. Do not discard them.
- **Apply.** If only `maintain-poller.sh` or `skills/` changed, you are done: launchd reads the script fresh on each run. If `SKILL.md` changed, read it again and redo **Write plist**, **Load**, and **Tell the agent** from Install. Keep the user's agent command, `PATH`, and interval from the current plist; ask only about new settings.
- **Verify.** Check `~/Library/Logs/maintain-poller.log` after the next run.
- **Roll back or pin.** Auto-update moves back to the newest tag on the next pass. To stay on an older tag, add `PR_MAINTAIN_UPDATED=1` to the plist `EnvironmentVariables`, check out the tag, and redo **Load**. Remove the variable to resume auto-update.

## Uninstall

When the user asks you to stop, remove, or uninstall the poller, or says it is broken, do these steps:

- **Unload.** Run `launchctl bootout gui/$(id -u)/com.zhachory1.maintain-poller`. This also stops a maintenance run in progress. A leftover worktree is replaced on the next run for that PR. If it fails with `3: No such process`, the job is already unloaded; continue.
- **Remove plist.** Delete `~/Library/LaunchAgents/com.zhachory1.maintain-poller.plist`, so the job does not load again at the next login.
- **Verify.** `launchctl print gui/$(id -u)/com.zhachory1.maintain-poller` must fail. If it still succeeds, report this to the user and stop.
- **Remove context.** Delete the maintain-poller block that **Tell the agent** added (its start marker, end marker, and every line between them) from the agent instructions file you wrote at install (`~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, or `~/AGENTS.md`). Do not change other text in that file.
- **Ask before you delete data.** If the poller is broken, show the user the last 50 lines of `~/Library/Logs/maintain-poller.log` first. Then ask if they also want to delete the log, the state folder `~/.local/state/maintain-poller` (handled keys, cached repo clones, leftover worktrees), and the clone `~/.local/share/maintain-poller`. Delete only what they approve. Without the handled file, a reinstall handles the latest feedback on each PR once more.

Commits, replies, and issues that are already posted stay on GitHub.
