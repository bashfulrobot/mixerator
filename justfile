# Nix-Darwin Configuration Management
# https://github.com/casey/just

# === Settings ===
set dotenv-load := true
set ignore-comments := true
set fallback := true
set shell := ["bash", "-euo", "pipefail", "-c"]

# === Variables ===
hostname := `scutil --get LocalHostName 2>/dev/null || hostname -s`
host_flake := ".#" + hostname
rebuild_log := "/tmp/mixerator-rebuild.log"
upgrade_log := "/tmp/mixerator-upgrade.log"
timestamp := `date +%Y-%m-%d_%H-%M-%S`

# === Help ===
# Show available recipes
default:
    @just --list --unsorted

# === Core Recipes ===
# Production rebuild of the current host
rebuild:
    #!/usr/bin/env bash
    set -uo pipefail
    log="{{rebuild_log}}"
    rc=0
    echo "Rebuilding nix-darwin configuration..."
    darwin-rebuild switch --flake {{host_flake}} &> "$log" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        warnings=$(grep -c -E -i 'warning:' "$log" 2>/dev/null || true)
        if [[ "$warnings" -gt 0 ]]; then
            echo "Rebuild succeeded with $warnings warning(s)"
            echo "View log: $log"
        else
            echo "Rebuild succeeded"
        fi
    else
        echo "Rebuild FAILED (exit $rc)"
        cat "$log"
        exit "$rc"
    fi

# Stage all, rebuild, unstage on exit
dev-rebuild:
    #!/usr/bin/env bash
    set -uo pipefail
    echo "Staging all changes..."
    git add -A
    trap 'git restore --staged .' EXIT
    just rebuild

# Full system upgrade
upgrade:
    #!/usr/bin/env bash
    set -uo pipefail
    log="{{upgrade_log}}"
    cp flake.lock flake.lock-backup-{{timestamp}}
    rc=0
    echo "Updating flake inputs..."
    nix flake update &> "$log" || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo "Flake update FAILED (exit $rc)"
        cat "$log"
        exit "$rc"
    fi
    echo "Flake inputs updated"
    echo "Rebuilding with upgrades..."
    darwin-rebuild switch --flake {{host_flake}} &>> "$log" || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo "Rebuild FAILED (exit $rc)"
        cat "$log"
        exit "$rc"
    fi
    echo "System upgraded successfully"

# Update a specific flake input
update input:
    @echo "Updating {{input}}..."
    @nix flake update {{input}}

# Garbage collection (default: 5 days)
clean days="5":
    @echo "Cleaning packages older than {{days}} days..."
    @sudo nix-collect-garbage --delete-older-than {{days}}d

# Check code health with deadnix and statix
health:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running code health checks..."
    echo ""
    echo "Checking for unused code with deadnix..."
    deadnix .
    echo ""
    echo "Running statix linter..."
    fd -e nix --hidden --no-ignore --follow . -x statix check {}
    echo ""
    echo "Code health check complete"

# Format all nix files
fmt:
    @echo "Formatting nix files..."
    @nix fmt

# === Quiet Recipes ===

# Quiet rebuild -- captures output, shows only errors on failure
quiet-rebuild:
    #!/usr/bin/env bash
    set -uo pipefail
    echo "Rebuilding (quiet mode)..."
    git add -A
    trap 'git restore --staged .' EXIT
    rc=0
    darwin-rebuild switch --flake {{host_flake}} &> {{rebuild_log}} || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "Rebuild succeeded. Full log: {{rebuild_log}}"
    else
        filtered=$(grep -E -i '(^error|error:|warning:|trace:|fatal|failed to)' {{rebuild_log}} | head -80)
        {
            echo "=== FILTERED ERRORS/WARNINGS ==="
            echo "$filtered"
            echo ""
            echo "=== FULL BUILD LOG ==="
            cat {{rebuild_log}}
        } > {{rebuild_log}}.tmp
        mv {{rebuild_log}}.tmp {{rebuild_log}}
        echo "Rebuild FAILED (exit $rc). Use a Nix subagent to diagnose {{rebuild_log}} and fix the issue."
        exit "$rc"
    fi

# Quiet upgrade -- captures output, shows only errors on failure
quiet-upgrade:
    #!/usr/bin/env bash
    set -uo pipefail
    echo "Upgrading (quiet mode)..."
    cp flake.lock flake.lock-backup-{{timestamp}}
    rc=0
    {
        nix flake update
        darwin-rebuild switch --flake {{host_flake}}
    } &> {{upgrade_log}} || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "Upgrade succeeded. Full log: {{upgrade_log}}"
    else
        filtered=$(grep -E -i '(^error|error:|warning:|trace:|fatal|failed to)' {{upgrade_log}} | head -80)
        {
            echo "=== FILTERED ERRORS/WARNINGS ==="
            echo "$filtered"
            echo ""
            echo "=== FULL BUILD LOG ==="
            cat {{upgrade_log}}
        } > {{upgrade_log}}.tmp
        mv {{upgrade_log}}.tmp {{upgrade_log}}
        echo "Upgrade FAILED (exit $rc). Use a Nix subagent to diagnose {{upgrade_log}} and fix the issue."
        exit "$rc"
    fi

# === Capture ===

# Pull runtime Claude Code config changes back into the repo
capture *args:
    #!/usr/bin/env bash
    set -uo pipefail
    if ! command -v claude-capture >/dev/null 2>&1; then
        echo "claude-capture not on PATH -- run 'just rebuild' first (apps.cli.claude-code)."
        exit 1
    fi
    echo "Capturing Claude Code config..."
    claude-capture {{args}} || echo "Capture reported problems (see above)"
    echo ""
    echo "Review with: git status && git diff modules/apps/cli/claude-code"

# Show what capture would change, without writing anything
capture-dry:
    #!/usr/bin/env bash
    set -uo pipefail
    claude-capture --dry-run | jq -r '
        "actions:", (.actions[].action),
        "conflicts: \(.conflicts | length)"' | sort | uniq -c

# === Aliases ===
alias r := rebuild
alias up := upgrade
alias gc := clean
alias qr := quiet-rebuild
alias qu := quiet-upgrade
