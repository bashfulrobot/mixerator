#!/usr/bin/env bash
# Diagnostic test for https://github.com/anthropics/claude-code/issues/70077:
# does wrapping the native-installer binary in a minimal .app bundle change
# whether macOS Keychain accepts writes from it? Builds a throwaway app
# bundle around a COPY of the real, still-signed claude binary (never
# re-signs it -- ad-hoc signing would invalidate Anthropic's real
# notarized signature and test a different failure mode entirely), then
# runs `claude doctor` through the bundle path so the Keychain line can be
# compared against a normal `claude doctor` run.
#
# Usage:
#   ./test-claude-app-bundle.sh          # build the bundle and run doctor through it
#   ./test-claude-app-bundle.sh --clean  # remove the throwaway bundle

set -euo pipefail

bundle="$HOME/Applications/ClaudeCodeTest.app"

if [[ "${1:-}" == "--clean" ]]; then
    rm -rf "$bundle"
    echo "Removed $bundle"
    exit 0
fi

real_bin="$(python3 -c "import os; print(os.path.realpath(os.path.expanduser('~/.local/bin/claude')))")"
if [[ ! -x "$real_bin" ]]; then
    echo "test-claude-app-bundle: $real_bin not found or not executable." >&2
    echo "  Expected the native installer's launcher at ~/.local/bin/claude." >&2
    exit 1
fi
echo "Real binary: $real_bin"

mkdir -p "$bundle/Contents/MacOS"

cat > "$bundle/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>claude</string>
    <key>CFBundleIdentifier</key>
    <string>com.anthropic.claude-code.test</string>
    <key>CFBundleName</key>
    <string>Claude Code Test</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
EOF

# Copy, not symlink: a copy keeps the embedded Anthropic PBC signature
# intact (codesign covers file contents, not path) while guaranteeing the
# running process's own path is unambiguously inside Contents/MacOS, with
# no symlink resolution that could resolve back out of the bundle.
cp "$real_bin" "$bundle/Contents/MacOS/claude"
chmod +x "$bundle/Contents/MacOS/claude"

echo ""
echo "=== codesign verification (should still show Anthropic PBC) ==="
codesign -dv --verbose=2 "$bundle/Contents/MacOS/claude"

echo ""
echo "=== claude doctor, run through the bundle path ==="
"$bundle/Contents/MacOS/claude" doctor

echo ""
echo "Compare the Keychain line above against a normal 'claude doctor' run."
echo "Clean up with: ./test-claude-app-bundle.sh --clean"
