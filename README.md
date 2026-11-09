# maintain-poller

> **Moved:** this poller now lives in [Zhachory1/pr-pollers](https://github.com/Zhachory1/pr-pollers) with the review, maintain, and build pollers together. New installs should use that repo; its install steps replace this one. This repo stays working for existing installs.


A macOS launchd job that keeps your own open PRs moving. When someone else reviews or comments on your PR, or its CI fails, it runs your coding agent with the bundled [`pr-review-handler`](skills/pr-review-handler/SKILL.md) skill. The agent:

- fixes review feedback that is in scope for the PR, pushes, replies, and resolves those threads;
- fixes CI failures the PR caused, and reruns flaky GitHub Actions jobs once;
- files a repo issue for anything outside the PR's scope and links it on the PR.

It never force-pushes, never merges, and never resolves a thread it did not fix in code. It skips draft PRs, fork PRs, PRs with pending CI, and PRs labeled `no-maintain`.

Pairs with [review-poller](https://github.com/Zhachory1/review-poller), which reviews PRs assigned to you.

## Install

Ask your coding agent:

> Install the maintain poller from https://github.com/Zhachory1/maintain-poller by following its SKILL.md.

The agent clones this repo to `~/.local/share/maintain-poller`, checks `gh` and `jq`, asks you for your agent command and poll interval, loads a LaunchAgent, and adds a short note to your global agent instructions so your agent knows the poller is running. Uninstall removes the note.

Commits, replies, and issues post under your own GitHub account.

## Operate

- Logs: `~/Library/Logs/maintain-poller.log`
- Leave a PR alone: add the `no-maintain` label.
- Update: automatic. Each pass switches to the newest release tag. If a release changes install steps, the log tells you to ask your agent to "update the maintain poller".
- Stop or uninstall: ask your agent to "uninstall the maintain poller".
- Test: `./test.sh` (needs `jq` and `git`)

## Release (maintainer)

Installed pollers switch to a new `v*` tag on their next pass, so a pushed tag runs on every teammate's Mac within one poll interval, under their GitHub account, and can push code to their PRs. Tag only what you would run yourself. To undo a bad release, push a newer tag with the fix.

```bash
./test.sh
git tag -a v0.2.0 -m "What changed and whether users must redo any install step"
git push origin v0.2.0
```
