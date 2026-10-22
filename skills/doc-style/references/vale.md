# Reference: Check prose with Vale

Vale (https://vale.sh) is a command-line linter for prose. The `vale-cli/Google` package (https://github.com/vale-cli/Google, MIT license) holds 37 rules from the Google developer documentation style guide. The Vale project makes this package. Google does not.

Vale finds errors that a pattern can match: headings that are not in sentence case, a missing serial comma, "please", Latin abbreviations, words from the word list, exclamation marks, and "will". It does not check tone, the order of a procedure, or link text.

## Check that Vale is installed

```bash
command -v vale
```

If the command prints nothing, Vale is not installed. Tell the user, and give them one install command. Do not install it yourself.

| Platform | Command |
| --- | --- |
| macOS or Linux with Homebrew | `brew install vale` |
| Windows | `choco install vale` |
| Other | download a binary from https://github.com/vale-cli/vale/releases |

## Configure a repository

Put this file at the root of the repository as `.vale.ini`. The pinned URL makes each run use the same rules.

```ini
StylesPath = .github/styles
MinAlertLevel = suggestion

Packages = https://github.com/vale-cli/Google/releases/download/v0.7.1/Google.zip

[*.md]
BasedOnStyles = Google
```

Then download the rules:

```bash
vale sync
```

Add `.github/styles/Google/` to `.gitignore`, because `vale sync` makes it again.

## Run a check

```bash
vale README.md docs/
vale --output=line README.md
```

`--output=line` prints one line for each alert: `file:line:column:rule:message`.

## Read the result

| Level | Action |
| --- | --- |
| error | Fix it. |
| warning | Fix it, or keep the text when the project rule or the user asks for it. |
| suggestion | Fix it when the fix does not change the meaning. |

To turn off a rule for a project, add a line under `[*.md]`, for example `Google.Passive = NO`.
