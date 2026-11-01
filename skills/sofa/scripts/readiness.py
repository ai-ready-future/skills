#!/usr/bin/env python3
"""Check if a repository is ready for a sofa team. Read-only.

    readiness.py [--repo PATH] [--json]

Prints one item per check. With --json, one JSON object per line:
{id, area, status, blocks_start, detail, fix}. Without it, an aligned table.
status is ok, missing, wrong or unknown. A check that fails with an error
gives unknown, with the error in detail.

Exit 0, or 2 when the repository path is not a git repository.

The commands it runs come from the environment, so tests can replace them:
READINESS_CLAUDE (default claude), READINESS_GH (gh), READINESS_CRONTAB (crontab).
"""
import argparse
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
CODE_SUFFIXES = {".py", ".ts", ".tsx", ".js", ".go", ".rs", ".java", ".rb", ".sh"}
SKIP_FOLDERS = {"node_modules", "vendor", "dist", "build"}
MAX_DEPTH = 3
MAX_ROUTER_LINES = 30
UNATTENDED_MODES = {"auto", "bypassPermissions", "dontAsk"}
BRAIN_FIX = {
    "knowledge": "/knowledge:setup",
    "adr": "/architecture:setup",
    "system-design": "/system-design:setup",
    "ddd": "/business-domain:setup",
    "prd": "/product:setup",
    "roadmap": "/product:setup",
}
BRAINS_THAT_BLOCK = {"prd", "roadmap"}
# Skills that Claude Code has built in, so no plugin or skill folder is necessary.
BUILT_IN_SKILLS = {"verify", "simplify", "security-review", "loop"}
# Skills of the sofa plugin, or skills a person installs under ~/.claude/skills.
OWN_SKILLS = {"station", "rebase", "wrapup", "find-docs", "bg-watch"}
# Tool names that are a command on the PATH. Other values are services, so a
# PATH check cannot judge them.
CLI_TOOLS = {"gh", "jira", "linear", "semgrep", "snyk", "sonar-scanner", "gitleaks", "trivy"}
NOT_A_TOOL = {"built-in", "none", "files", ""}


# --- helpers ---

def cmd_name(var, default):
    return os.environ.get(var) or default


def run(args, timeout=30):
    """Run a command. Returns (exit code, stdout+stderr). Never raises."""
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout + p.stderr
    except FileNotFoundError:
        return 127, f"{args[0]}: not found"
    except subprocess.TimeoutExpired:
        return 124, f"{args[0]}: timeout"
    except OSError as e:
        return 126, str(e)


def item(id_, area, status, detail="", fix="", blocks_start=False):
    return {"id": id_, "area": area, "status": status, "blocks_start": blocks_start,
            "detail": detail, "fix": fix}


def read_text(path):
    return Path(path).read_text(encoding="utf-8", errors="replace")


def read_json(path):
    return json.loads(read_text(path))


def strip_ticks(s):
    return s.replace("`", "").strip()


def parse_tables(text):
    """Each pipe table of a markdown text: {"headers": [...], "rows": [[...]], "section": "1"}.

    A table is a header line, a |---| line, then rows until a line that does
    not start with |. Cells keep their backticks; the callers strip them.
    A `\\|` inside a cell is a pipe, not a cell border.
    """
    def cells(line):
        return [c.replace("\\|", "|").strip() for c in re.split(r"(?<!\\)\|", line.strip())[1:-1]]

    tables = []
    section = ""
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^##\s+(\d+)", line)
        if m:
            section = m.group(1)
        if line.startswith("|") and i + 1 < len(lines) and re.match(r"^\|\s*:?-+", lines[i + 1]):
            headers = cells(line)
            rows = []
            i += 2
            while i < len(lines) and lines[i].startswith("|"):
                rows.append(cells(lines[i]))
                i += 1
            tables.append({"headers": headers, "rows": rows, "section": section})
            continue
        i += 1
    return tables


def find_table(tables, *needed, section=None):
    for t in tables:
        if all(h in t["headers"] for h in needed) and (section is None or t["section"] == section):
            return t
    return None


def table_dict(table, value_col):
    """{first-column value: cell of value_col}, backticks stripped from the key."""
    out = {}
    if table is None:
        return out
    ki, vi = 0, table["headers"].index(value_col)
    for row in table["rows"]:
        if len(row) > max(ki, vi):
            out[strip_ticks(row[ki])] = row[vi]
    return out


def first_token(cell):
    """The first backticked value of a cell, or the whole cell without backticks."""
    m = re.search(r"`([^`]*)`", cell)
    return m.group(1).strip() if m else cell.strip()


def template_version(text):
    m = re.search(r"sofa-template-version:\s*(\d+)", text)
    return m.group(1) if m else None


class Repo:
    def __init__(self, root):
        self.root = Path(root)
        self.adlc = self.root / "docs" / "adlc.md"
        self.template = PLUGIN_ROOT / "templates" / "ADLC.md"
        self._tables = None
        self._adlc_text = None

    def adlc_text(self):
        if self._adlc_text is None:
            self._adlc_text = read_text(self.adlc) if self.adlc.exists() else ""
        return self._adlc_text

    def tables(self):
        """Tables of docs/adlc.md, or of the template when docs/adlc.md is missing."""
        if self._tables is None:
            text = self.adlc_text() or (read_text(self.template) if self.template.exists() else "")
            self._tables = parse_tables(text)
        return self._tables

    def setup_values(self):
        """Section 1 values of docs/adlc.md. Empty when the file is missing: the
        template holds only placeholders, and the adlc item reports the file."""
        if not self.adlc.exists():
            return {}
        return table_dict(find_table(self.tables(), "Key", "Value", section="1"), "Value")

    def roles(self):
        return find_table(self.tables(), "Role", "Model")

    def tools_per_role(self):
        # The first column is "Tool of" (template 6) or "Role" (older files).
        if not self.adlc.exists():
            return {}
        return table_dict(find_table(self.tables(), "Tool", section="1"), "Tool")


# --- checks: each one returns a list of items ---

def check_claude(repo):
    items = []
    claude = cmd_name("READINESS_CLAUDE", "claude")
    rc, out = run([claude, "--help"])
    if rc == 127:
        items.append(item("claude-cli", "claude", "missing", out, "install Claude Code", True))
    else:
        lost = [f for f in ("--bg", "--autocompact") if f not in out]
        if lost:
            items.append(item("claude-cli", "claude", "wrong", f"claude --help has no {' '.join(lost)}",
                              "update Claude Code", True))
        else:
            items.append(item("claude-cli", "claude", "ok", "--bg and --autocompact exist"))

    settings_path = Path.home() / ".claude" / "settings.json"
    settings = {}
    if settings_path.exists():
        try:
            settings = read_json(settings_path)
        except ValueError as e:
            items.append(item("settings-json", "claude", "wrong", f"{settings_path}: {e}", "fix the JSON"))
            settings = {}

    if settings.get("autoCompactEnabled") is False:
        items.append(item("autocompact", "claude", "wrong", "autoCompactEnabled is false in ~/.claude/settings.json",
                          "set autoCompactEnabled to true, or remove it"))
    else:
        items.append(item("autocompact", "claude", "ok", "autoCompactEnabled is not false"))

    mode = settings.get("permissions", {}).get("defaultMode") if isinstance(settings.get("permissions"), dict) else None
    source = "~/.claude/settings.json"
    if mode is None:
        for name in ("settings.json", "settings.local.json"):
            p = repo.root / ".claude" / name
            if p.exists():
                try:
                    perms = read_json(p).get("permissions", {})
                    if isinstance(perms, dict) and perms.get("defaultMode"):
                        mode, source = perms["defaultMode"], f".claude/{name}"
                        break
                except ValueError:
                    pass
    if mode is None:
        items.append(item("permission-mode", "claude", "unknown", "no permissions.defaultMode in the settings",
                          "/auto-mode-setup"))
    elif mode in UNATTENDED_MODES:
        items.append(item("permission-mode", "claude", "ok", f"defaultMode {mode} in {source}"))
    else:
        items.append(item("permission-mode", "claude", "wrong", f"defaultMode {mode} in {source} needs a person",
                          "/auto-mode-setup"))

    advisor = settings.get("advisor")
    if isinstance(advisor, dict) and "enabled" in advisor:
        advisor = advisor["enabled"]
    elif "advisorEnabled" in settings:
        advisor = settings["advisorEnabled"]
    if advisor is None or isinstance(advisor, dict):
        items.append(item("advisor", "claude", "unknown", "no advisor enabled key in ~/.claude/settings.json", "/config"))
    elif advisor:
        items.append(item("advisor", "claude", "ok", "advisor is on"))
    else:
        items.append(item("advisor", "claude", "wrong", "advisor is off", "/config"))
    return items


def code_folders(root):
    """Folders below root that hold code files, up to MAX_DEPTH, with the skips."""
    found = []
    for dirpath, dirnames, filenames in os.walk(root):
        rel = os.path.relpath(dirpath, root)
        depth = 0 if rel == "." else rel.count(os.sep) + 1
        dirnames[:] = sorted(d for d in dirnames
                             if not d.startswith(".") and d not in SKIP_FOLDERS and depth < MAX_DEPTH)
        if rel != "." and any(Path(f).suffix in CODE_SUFFIXES for f in filenames):
            found.append(rel)
    return found


def check_repo(repo):
    items = []
    root = repo.root
    if (root / "CLAUDE.md").exists() or (root / "AGENTS.md").exists():
        items.append(item("root-claude-md", "repo", "ok", "root CLAUDE.md or AGENTS.md exists"))
    else:
        items.append(item("root-claude-md", "repo", "missing", "no CLAUDE.md or AGENTS.md at the root", "/init"))

    folders = code_folders(root)
    without = [f for f in folders if not (root / f / "CLAUDE.md").exists()]
    if not folders:
        items.append(item("folder-routers", "repo", "ok", "no code folder below the root"))
    elif without:
        shown = ", ".join(without[:10]) + (" ..." if len(without) > 10 else "")
        items.append(item("folder-routers", "repo", "wrong", f"{len(without)} code folder(s) without CLAUDE.md: {shown}",
                          "designer, or /sofa:setup"))
    else:
        items.append(item("folder-routers", "repo", "ok", f"{len(folders)} code folder(s) have a CLAUDE.md"))

    long_routers = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if not d.startswith(".") and d not in SKIP_FOLDERS]
        if dirpath != str(root) and "CLAUDE.md" in filenames:
            n = len(read_text(Path(dirpath) / "CLAUDE.md").splitlines())
            if n > MAX_ROUTER_LINES:
                long_routers.append(f"{os.path.relpath(dirpath, root)}/CLAUDE.md ({n} lines)")
    if long_routers:
        items.append(item("router-length", "repo", "wrong", "over 30 lines: " + ", ".join(long_routers[:10]),
                          "shorten the router; move the detail to .claude/rules/"))
    else:
        items.append(item("router-length", "repo", "ok", "each router below the root is 30 lines or fewer"))

    if (root / ".gitignore").exists():
        items.append(item("gitignore", "repo", "ok", ".gitignore exists"))
    else:
        items.append(item("gitignore", "repo", "missing", "no .gitignore", "add a .gitignore for the stack"))

    exclude = root / ".git" / "info" / "exclude"
    if exclude.exists() and re.search(r"^\.sofa/?\s*$", read_text(exclude), re.M):
        items.append(item("git-exclude-sofa", "repo", "ok", ".git/info/exclude has .sofa/"))
    else:
        items.append(item("git-exclude-sofa", "repo", "missing", ".git/info/exclude has no .sofa/ line",
                          "echo .sofa/ >> .git/info/exclude"))

    claude_md = root / "CLAUDE.md"
    names_verify = claude_md.exists() and re.search(r"\bverify\b", read_text(claude_md), re.I)
    if (root / ".claude" / "skills" / "verify").exists():
        items.append(item("verify-skill", "repo", "ok", ".claude/skills/verify exists"))
    elif names_verify:
        items.append(item("verify-skill", "repo", "ok", "CLAUDE.md names how to verify"))
    else:
        items.append(item("verify-skill", "repo", "missing", "no .claude/skills/verify, and CLAUDE.md does not say verify",
                          "add a verify skill, or a verify line in CLAUDE.md"))
    return items


def check_brains(repo):
    items = []
    registry = repo.root / ".claude" / "knowledge.json"
    graphs = {}
    if registry.exists():
        graphs = read_json(registry).get("graphs", {})
    for name, fix in BRAIN_FIX.items():
        blocks = name in BRAINS_THAT_BLOCK
        entry = graphs.get(name)
        if entry is None:
            where = "" if registry.exists() else " (no .claude/knowledge.json)"
            items.append(item(f"brain-{name}", "brains", "missing", f"graph {name} not in the registry{where}", fix, blocks))
        elif "path" in entry and not (repo.root / entry["path"]).is_dir():
            items.append(item(f"brain-{name}", "brains", "wrong", f"graph {name}: {entry['path']} is not a folder", fix, blocks))
        else:
            items.append(item(f"brain-{name}", "brains", "ok", f"graph {name} is in the registry"))
    return items


def check_team(repo):
    items = []
    if not repo.adlc.exists():
        items.append(item("adlc", "team", "missing", "no docs/adlc.md", "/sofa:setup", True))
    else:
        items.append(item("adlc", "team", "ok", "docs/adlc.md exists"))
        want = template_version(read_text(repo.template)) if repo.template.exists() else None
        have = template_version(repo.adlc_text())
        if want is None:
            items.append(item("adlc-version", "team", "unknown", f"no sofa-template-version in {repo.template}", ""))
        elif have == want:
            items.append(item("adlc-version", "team", "ok", f"sofa-template-version {have}"))
        else:
            items.append(item("adlc-version", "team", "wrong", f"sofa-template-version {have or 'absent'}, the template has {want}",
                              "/sofa:sofa migrates it", True))
        left = [k for k, v in repo.setup_values().items() if first_token(v).startswith("<")]
        if left:
            items.append(item("adlc-placeholders", "team", "wrong", "placeholders left in section 1: " + ", ".join(left),
                              "/sofa:setup"))
        else:
            items.append(item("adlc-placeholders", "team", "ok", "no placeholder in section 1"))

    rc, out = run([cmd_name("READINESS_CRONTAB", "crontab"), "-l"])
    if rc == 127:
        items.append(item("scheduler", "team", "unknown", out, "/sofa:setup"))
    elif "bg-watch check" in out:
        items.append(item("scheduler", "team", "ok", "crontab has the bg-watch check line"))
    else:
        items.append(item("scheduler", "team", "missing", "crontab -l has no bg-watch check line", "/sofa:setup"))

    db = repo.root / ".sofa" / "state.db"
    if not db.exists():
        items.append(item("state-store", "team", "missing", "no .sofa/state.db", "sofa-state init"))
    else:
        try:
            con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
            con.execute("select name from sqlite_master limit 1")
            con.close()
            items.append(item("state-store", "team", "ok", ".sofa/state.db opens"))
        except sqlite3.Error as e:
            items.append(item("state-store", "team", "wrong", f".sofa/state.db: {e}", "sofa-state init"))
    return items


def check_tools(repo):
    items = []
    rc, out = run([cmd_name("READINESS_GH", "gh"), "auth", "status"])
    if rc == 0:
        items.append(item("gh-auth", "tools", "ok", "gh is logged in"))
    elif rc == 127:
        items.append(item("gh-auth", "tools", "missing", "gh is not installed", "install gh, then gh auth login", True))
    else:
        items.append(item("gh-auth", "tools", "wrong", out.strip().splitlines()[-1] if out.strip() else "gh auth status failed",
                          "gh auth login", True))

    if shutil.which("npx"):
        items.append(item("npx", "tools", "ok", "npx is on the PATH (for ctx7)"))
    else:
        items.append(item("npx", "tools", "missing", "npx is not on the PATH, so ctx7 cannot run", "install Node.js"))

    for role, cell in repo.tools_per_role().items():
        value = first_token(cell)
        if value.startswith("<"):
            items.append(item(f"tool-{role}", "tools", "wrong", f"tools per role: {role} is a placeholder", "/sofa:setup"))
            continue
        if value.lower() in NOT_A_TOOL:
            items.append(item(f"tool-{role}", "tools", "ok", f"{role}: {value or 'none'}"))
            continue
        name = value.split()[0].lower()
        if name not in CLI_TOOLS:
            items.append(item(f"tool-{role}", "tools", "unknown", f"{role}: {value} is not a command this script knows", ""))
        elif shutil.which(name):
            items.append(item(f"tool-{role}", "tools", "ok", f"{role}: {name} is on the PATH"))
        else:
            items.append(item(f"tool-{role}", "tools", "missing", f"{role}: {name} is not on the PATH", f"install {name}"))
    return items


def installed_plugins(claude):
    """Names of the enabled plugins from `claude plugin list`. None when the command fails."""
    rc, out = run([claude, "plugin", "list", "--json"])
    if rc == 127:
        return None
    try:
        data = json.loads(out)
        return {p["id"].split("@")[0] for p in data if p.get("enabled", True)}
    except (ValueError, KeyError, TypeError, AttributeError):
        pass
    rc, out = run([claude, "plugin", "list"])
    return set(re.findall(r"^\s*❯?\s*([\w.-]+)@", out, re.M))


def skill_names(roles):
    """The plugin or skill names of the Skills column, without duplicates."""
    if roles is None or "Skills" not in roles["headers"]:
        return []
    si = roles["headers"].index("Skills")
    names = []
    for row in roles["rows"]:
        if len(row) <= si:
            continue
        for part in strip_ticks(row[si]).split(","):
            part = re.sub(r"\s*\(.*\)\s*$", "", part.strip())
            if not part or part == "—":
                continue
            name = part.split(":")[0].strip()
            if name and name not in names:
                names.append(name)
    return names


def check_skills(repo):
    items = []
    plugins = installed_plugins(cmd_name("READINESS_CLAUDE", "claude"))
    names = skill_names(repo.roles())
    home_skills = Path.home() / ".claude" / "skills"
    repo_skills = repo.root / ".claude" / "skills"
    if not names:
        items.append(item("skills", "skills", "unknown", "no Skills column in the roles table", ""))
        return items
    for name in names:
        if name in BUILT_IN_SKILLS:
            continue
        as_skill = (home_skills / name).exists() or (repo_skills / name).exists()
        if name in OWN_SKILLS and (as_skill or (plugins and "sofa" in plugins)):
            continue
        if as_skill or (plugins is not None and name in plugins):
            items.append(item(f"skill-{name}", "skills", "ok", f"{name} is installed"))
        elif plugins is None:
            items.append(item(f"skill-{name}", "skills", "unknown", f"claude plugin list did not run, and no skill folder {name}",
                              f"claude plugin install {name}"))
        else:
            items.append(item(f"skill-{name}", "skills", "missing", f"{name} is not an enabled plugin, and no skill folder",
                              f"claude plugin install {name}"))
    return items


def check_human(repo):
    items = []
    slack = first_token(repo.setup_values().get("Slack", "none"))
    if not repo.adlc.exists():
        items.append(item("slack", "human", "unknown", "no docs/adlc.md, so no Slack value", "/sofa:setup"))
    elif slack.startswith("<"):
        items.append(item("slack", "human", "wrong", "Slack value is a placeholder", "/sofa:setup"))
    elif slack.lower() == "none":
        items.append(item("slack", "human", "ok", "Slack is none"))
    elif os.environ.get("SLACK_BOT_TOKEN"):
        items.append(item("slack", "human", "ok", f"Slack {slack}, SLACK_BOT_TOKEN is set"))
    else:
        items.append(item("slack", "human", "missing", f"Slack {slack}, but SLACK_BOT_TOKEN is not in the environment",
                          "export SLACK_BOT_TOKEN"))

    registry = repo.root / ".claude" / "knowledge.json"
    entry = read_json(registry).get("graphs", {}).get("knowledge") if registry.exists() else None
    if not entry or "path" not in entry:
        items.append(item("people-page", "human", "unknown", "no knowledge brain in the registry", "/knowledge:setup"))
    else:
        brain = repo.root / entry["path"]
        if (brain / "people").is_dir() or (brain / "people.md").exists():
            items.append(item("people-page", "human", "ok", f"{entry['path']} has a people page"))
        else:
            items.append(item("people-page", "human", "missing", f"{entry['path']} has no people/ folder or people.md",
                              "/knowledge:learn the human team"))
    return items


CHECKS = [check_claude, check_repo, check_brains, check_team, check_tools, check_skills, check_human]
AREAS = {"check_claude": "claude", "check_repo": "repo", "check_brains": "brains", "check_team": "team",
         "check_tools": "tools", "check_skills": "skills", "check_human": "human"}


def run_checks(repo):
    items = []
    for check in CHECKS:
        try:
            items.extend(check(repo))
        except Exception as e:  # a check must never stop the others
            area = AREAS[check.__name__]
            items.append(item(area, area, "unknown", f"{type(e).__name__}: {e}", ""))
    return items


def git_root(path):
    rc, out = run(["git", "-C", str(path), "rev-parse", "--show-toplevel"])
    return out.strip() if rc == 0 else None


def print_table(items):
    order = {"missing": 0, "wrong": 0, "unknown": 1, "ok": 2}
    rows = sorted(items, key=lambda x: (x["area"], order[x["status"]], x["id"]))
    cols = ["area", "id", "status", "blocks", "detail", "fix"]
    def short(s, n=80):
        return s if len(s) <= n else s[:n - 3] + "..."
    data = [[r["area"], r["id"], r["status"], "yes" if r["blocks_start"] else "", short(r["detail"]), r["fix"]]
            for r in rows]
    widths = [max(len(c), *(len(d[i]) for d in data)) for i, c in enumerate(cols)]
    fmt = "  ".join("{:<%d}" % w for w in widths)
    print(fmt.format(*cols).rstrip())
    for d in data:
        print(fmt.format(*d).rstrip())
    blocking = [r["id"] for r in rows if r["blocks_start"] and r["status"] != "ok"]
    print()
    print("blocks start: " + (", ".join(blocking) if blocking else "nothing"))


def main():
    ap = argparse.ArgumentParser(description="Check if a repository is ready for a sofa team.")
    ap.add_argument("--repo", default=".", help="repository path (default: the git top level of the current folder)")
    ap.add_argument("--json", action="store_true", help="one JSON object per line")
    args = ap.parse_args()
    root = git_root(args.repo)
    if root is None:
        print(f"readiness.py: not a git repository: {args.repo}", file=sys.stderr)
        return 2
    items = run_checks(Repo(root))
    if args.json:
        for it in items:
            print(json.dumps(it, ensure_ascii=False))
    else:
        print_table(items)
    return 0


if __name__ == "__main__":
    sys.exit(main())
