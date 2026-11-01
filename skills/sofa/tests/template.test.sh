#!/usr/bin/env bash
# Checks that the template, the role files and the skills of the plugin agree.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
template="$root/templates/ADLC.md"
fails=0
ok() { echo "ok   $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }

# The role names: the first cell of each row of the roles table.
roles=$(awk '/^\| Role \| Tier \|/{t=1; getline; next} t && /^\|/{gsub(/^\| */,""); split($0,a," *\\|"); print a[1]; next} t{exit}' "$template")
count=$(printf '%s\n' "$roles" | grep -c .)
[ "$count" -eq 29 ] && ok "the roles table has 29 roles" || fail "the roles table has $count roles, not 29"

for role in $roles; do
  [ -f "$root/references/roles/$role.md" ] || fail "role $role has no role file"
done
ok "each role of the table has a role file"

for file in "$root"/references/roles/*.md; do
  name=$(basename "$file" .md)
  printf '%s\n' "$roles" | grep -qx "$name" || fail "role file $name.md has no row in the roles table"
done
ok "each role file has a row in the roles table"

version=$(grep -o 'sofa-template-version: [0-9]*' "$template" | grep -o '[0-9]*$')
[ "$version" = 6 ] && ok "the template version is 6" || fail "the template version is $version"
grep -q "^## 5 → 6" "$root/templates/MIGRATION.md" && ok "MIGRATION.md has the step to version $version" || fail "MIGRATION.md has no step 5 → 6"

# Old names may appear only in MIGRATION.md, which maps them.
stale=$(grep -rnE '\b(prd|adr):[a-z*]|pr-flow:|ui-judge|\.sofa\.state\.json' "$root" --include='*.md' | grep -v '/templates/MIGRATION.md' || true)
[ -z "$stale" ] && ok "no old skill names outside MIGRATION.md" || { fail "old skill names:"; echo "$stale"; }

for skill in sofa station readiness setup maturity; do
  head -5 "$root/skills/$skill/SKILL.md" 2>/dev/null | grep -q "^name: $skill$" || fail "skills/$skill/SKILL.md has no name: $skill"
done
ok "each sub-skill has its SKILL.md"

styles=$(awk '/^\| Role \| Tier \|/{t=1; getline; next} t && /^\|/{print; next} t{exit}' "$template" | awk -F'|' '{gsub(/[ `]/,"",$8); print $8}' | sort -u | tr '\n' ' ')
for style in $styles; do
  case "$style" in Proactive|Concise|Explanatory|Learning|—) ;; *) fail "unknown output style $style" ;; esac
done
ok "each output style is a built-in style"

[ "$fails" -eq 0 ] && { echo; echo "all cases pass"; } || { echo; echo "$fails case(s) fail"; exit 1; }
