#!/bin/bash
echo "Installing Codex Usage widget..."
# Remove previous installs (including the old plugin id)
kpackagetool6 -t Plasma/Applet -r org.kde.plasma.codexusage 2>/dev/null
kpackagetool6 -t Plasma/Applet -r com.github.izll.codexusage 2>/dev/null
kpackagetool6 -t Plasma/Applet -i .

ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
mkdir -p "$ICON_DIR"
cp contents/icons/codex-usage-widget.svg "$ICON_DIR/"

echo ""
echo "Restart Plasma to apply changes:"
echo "  kquitapp6 plasmashell && kstart plasmashell"
