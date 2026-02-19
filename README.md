# Mac Automata

A macOS menu bar app that lets you set up common automations without scripting knowledge. Pick a recipe, fill in the parameters, and Mac Automata handles the rest — generating launchd plists and scripts behind the scenes.

## What It Does

Mac Automata runs in your menu bar. Click the gear icon to see your active automations, toggle them on/off, or add new ones.

### Available Recipes

| Recipe | What It Does |
|--------|-------------|
| **Open Apps** | Launch apps on a schedule |
| **Quit Apps** | Close apps at a set time |
| **Toggle Dark Mode** | Switch appearance mode on schedule |
| **Empty Trash** | Empty the Trash automatically |
| **Open URLs** | Open websites at a specific time |
| **Clean Downloads** | Remove old files from Downloads |
| **Set Volume** | Adjust system volume on schedule |

## How It Works

1. Click the menu bar icon → "Add Automation..."
2. Pick a recipe from the list
3. Configure the parameters (time, days, apps, etc.)
4. Click "Save Automation"

Mac Automata creates a launchd plist and script file that macOS runs on your schedule. No background processes, no daemon — just native macOS scheduling.

### Where Files Live

| What | Location |
|------|----------|
| Automation configs | `~/.mac-automata/manifest.json` |
| Generated scripts | `~/.mac-automata/scripts/` |
| Activity logs | `~/.mac-automata/logs/` |
| Launchd plists | `~/Library/LaunchAgents/com.macautomata.*.plist` |

## Requirements

- macOS 13 (Ventura) or later
- Automation permission for System Events and Finder (prompted on first use)

## Building from Source

```bash
# Clone and build
git clone https://github.com/madebysan/mac-automata.git
cd mac-automata
swift build

# Run
.build/debug/MacAutomata
```

### Create a .app bundle

```bash
chmod +x scripts/build-dmg.sh
./scripts/build-dmg.sh
```

## Uninstalling

Before removing the app, click "Remove All Automations..." from the menu bar dropdown. This unloads all launchd plists and deletes generated scripts.

To manually clean up:
```bash
# Remove all Mac Automata plists
launchctl list | grep macautomata | awk '{print $3}' | xargs -I {} launchctl remove {}
rm ~/Library/LaunchAgents/com.macautomata.*.plist

# Remove data directory
rm -rf ~/.mac-automata
```

## License

MIT
