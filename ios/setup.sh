#!/usr/bin/env bash
set -e

echo "=== Atlas iOS Setup ==="

# ── 1. Homebrew ─────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# ── 2. xcodegen ─────────────────────────────────────────────────────────────
if ! command -v xcodegen &>/dev/null; then
  echo "Installing xcodegen..."
  brew install xcodegen
fi

# ── 3. Generate Xcode project ────────────────────────────────────────────────
echo "Generating Atlas.xcodeproj..."
cd "$(dirname "$0")"
xcodegen generate

echo ""
echo "✅  Atlas.xcodeproj created successfully."
echo ""
echo "Next steps:"
echo "  1. Open Atlas.xcodeproj in Xcode"
echo "  2. Select the Atlas target > Signing & Capabilities"
echo "     → Set your Team (Apple Developer account)"
echo "     → The App Group 'group.com.atlas.app' must be enabled on ALL three targets:"
echo "        Atlas, AtlasShareExtension, AtlasMessageExtension"
echo "  3. Repeat step 2 for AtlasShareExtension and AtlasMessageExtension"
echo "  4. Build and run on a real device (extensions require a physical device)"
echo "  5. Add your Gemini API key inside the Atlas app → Settings"
echo ""
echo "iMessage extension:"
echo "  • Open Messages > any conversation > tap the four-dot icon > Atlas"
echo "  • Copy a message from the conversation, then tap 'Process'"
echo "  • The on/off toggle is visible in the Atlas bar inside Messages"
echo ""
echo "Share extension (WhatsApp / Messenger / Instagram):"
echo "  • Long-press any message > Share icon > Atlas"
