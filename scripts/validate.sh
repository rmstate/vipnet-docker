#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v bash >/dev/null || { echo "bash is required" >&2; exit 1; }
bash -n scripts/route.sh scripts/diagnose.sh scripts/validate.sh
echo "[OK] Bash syntax"

for file in README.md docs/01-installation.md docs/02-keys-and-startup.md docs/03-routing-and-connectivity.md docs/04-troubleshooting.md SECURITY.md APPLY.md; do
  [[ -s "$file" ]] || { echo "[FAIL] Missing or empty: $file" >&2; exit 1; }
done
echo "[OK] Documentation files exist"

if grep -nE '(^|[[:space:]])source[[:space:]]+.*STATE_FILE|^[[:space:]]*\.[[:space:]]+.*STATE_FILE' scripts/route.sh; then
  echo "[FAIL] route.sh must parse state as data, never source it" >&2
  exit 1
fi
grep -q 'flock -n 9' scripts/route.sh || { echo "[FAIL] route.sh is missing per-target locking" >&2; exit 1; }
grep -q 'trap rollback ERR' scripts/route.sh || { echo "[FAIL] route.sh is missing apply rollback" >&2; exit 1; }
echo "[OK] Route safety guards"

python3 - <<'PYLINKS'
from pathlib import Path
import re, sys
files = [Path("README.md"), *Path("docs").glob("*.md"), Path("SECURITY.md"), Path("APPLY.md")]
bad = []
for path in files:
    text = path.read_text(encoding="utf-8")
    for target in re.findall(r"\]\(([^)]+)\)", text):
        if target.startswith(("https://", "http://", "#", "mailto:")):
            continue
        resolved = (path.parent / target.split("#", 1)[0]).resolve()
        if not resolved.exists():
            bad.append(f"{path}: broken local link -> {target}")
if bad:
    print("\n".join(bad), file=sys.stderr)
    raise SystemExit(1)
print("[OK] Local Markdown links")
PYLINKS

echo "[OK] Validation complete"
