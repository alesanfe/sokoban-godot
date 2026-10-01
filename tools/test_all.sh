#!/usr/bin/env bash
# Ejecuta TODA la suite de verificación — el único comando de tests.
set -uo pipefail
GODOT="${GODOT:-godot}"
fail=0

for s in tests/test_runner.gd tests/test_rules.gd \
         tests/test_playthrough.gd tests/test_e2e.gd \
         tests/test_ui.gd tools/audit_levels.gd; do
    echo "=== res://$s ==="
    "$GODOT" --headless --path . -s "res://$s" || fail=$((fail+1))
done

echo "=== lint: ruff + bandit + gdlint ==="
python -m py_compile server/community_server.py || fail=$((fail+1))
python -m ruff check server/                       || fail=$((fail+1))
python -m bandit -r server/ -q --severity-level medium \
                                                 || fail=$((fail+1))
gdlint scripts/ tests/ tools/                    || fail=$((fail+1))

echo "=== backend: load test ==="
python server/test_load.py || fail=$((fail+1))

if [ "$fail" -eq 0 ]; then echo "== SUITE COMPLETA: OK =="
else echo "== SUITE COMPLETA: $fail suites con fallos =="; fi
exit "$fail"
