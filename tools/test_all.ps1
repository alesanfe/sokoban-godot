# Ejecuta TODA la suite de verificación — el único comando de tests.
# Uso: powershell tools/test_all.ps1  (o tools/test_all.sh en POSIX)
$ErrorActionPreference = "Stop"
$godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
$fail = 0

$suites = @(
    "res://tests/test_runner.gd",
    "res://tests/test_rules.gd",
    "res://tests/test_playthrough.gd",
    "res://tests/test_e2e.gd",
    "res://tests/test_ui.gd",
    "res://tools/audit_levels.gd"
)
foreach ($s in $suites) {
    Write-Output "=== $s ==="
    & $godot --headless --path . -s $s
    if ($LASTEXITCODE -ne 0) { $fail++ }
}
Write-Output "=== lint: ruff + bandit + gdlint ==="
python -m py_compile server/community_server.py
python -m ruff check server/;          if ($LASTEXITCODE -ne 0) { $fail++ }
python -m bandit -r server/ -q --severity-level medium
                                         if ($LASTEXITCODE -ne 0) { $fail++ }
gdlint scripts/ tests/ tools/;         if ($LASTEXITCODE -ne 0) { $fail++ }
Write-Output "=== backend: rutas (sin socket) + load test ==="
python server/test_routes.py;         if ($LASTEXITCODE -ne 0) { $fail++ }
python server/test_load.py
if ($LASTEXITCODE -ne 0) { $fail++ }

if ($fail -eq 0) { Write-Output "== SUITE COMPLETA: OK ==" } else {
    Write-Output "== SUITE COMPLETA: $fail suites con fallos ==" }
exit $fail
