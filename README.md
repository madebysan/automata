# Automata

A macOS menu bar app for setting up personal automations — no scripting required. Pick a trigger, pick an action, and Automata installs it as a native macOS scheduled job. **You can quit the app after setup — your automations keep running on their own.**

Built as a simpler, more focused alternative to Apple Shortcuts for people who want straightforward "when X happens, do Y" rules without flowcharts, Siri, or iCloud.

> **Important:** Automata is a setup tool, not a runtime. It creates native macOS `launchd` jobs that run whether Automata is open or not. You only need the app when you want to create, edit, or delete an automation.

## How It Works

Automata lives in your menu bar. You create automations by combining a **trigger** (when something happens) with an **action** (what to do about it). Once saved, the automation is handed off to macOS and runs independently — even if you quit Automata or restart your Mac.

### Triggers

| Trigger | How it works |
|---------|-------------|
| At a specific time | Pick a time and days of the week |
| Between specific hours | Start an action at one time, reverse it at another |
| Every N minutes | Repeating interval (reminders, cleanup) |
| On login | Runs once when you log in |
| When a file appears | Watches a folder for new files |
| When a drive is mounted | Fires when USB/SD card is plugged in |

### Actions

| Action | What it does |
|--------|-------------|
| Open app(s) | Launch one or more apps |
| Quit app(s) | Close one or more apps |
| Open a file | Open any file with its default app |
| Open URL(s) | Open websites in your browser |
| Empty the Trash | Clear the Trash |
| Clean old Downloads | Delete files older than N days |
| Toggle Dark Mode | Switch to dark, light, or toggle |
| Set volume | Change system volume to a specific level |
| Move files | Move files from one folder to another |
| Show a notification | Display a reminder message |
| Keep Mac awake | Prevent sleep (useful during presentations or long tasks) |

6 triggers × 11 actions = **66 possible automations** from just two dropdowns.

### Natural Language Input

Don't want to browse dropdowns? Just describe what you want in plain English:

> "remind me to stretch every 30 minutes"
> "empty the trash every Sunday at noon"
> "keep my Mac awake while I'm at work"

Automata parses your description and shows ranked suggestions — pick one and it creates the automation for you. You can also type partial ideas and Automata will suggest the closest matches from its 66 trigger+action combinations.

### Templates

20 pre-built templates across 7 categories — add with one click or customize before saving:

**Routines** — Morning Workspace, Open Daily Journal, Startup Apps, Morning Music
**Focus & Wind Down** — Night Mode (dark 8 PM→7 AM), Deep Work Block (quit Slack/Discord 9–12), Stay Awake at Work, End of Day Shutdown
**Volume** — Quiet Hours (mute 11 PM→7 AM), Morning Volume
**Reminders** — Stretch Break, Hydration Reminder, Eye Break (20-20-20)
**File Organization** — Screenshot Organizer, Downloads Sorter, Weekly Downloads Cleanup, Empty Trash Weekly
**Web & Links** — Daily Standup, Weekly Review Sites
**External Drives** — Backup Reminder

## Automata vs. Apple Shortcuts

Automata is not trying to replace Shortcuts. It's a focused tool for simple, repeating automations that run in the background without you thinking about them.

### What Automata does better

| | Automata | Apple Shortcuts |
|--|-------------|----------------|
| **Simplicity** | Two dropdowns: "When" + "Do this" | Flowchart editor with blocks, variables, conditions |
| **Setup time** | One-click templates, 10-second custom setup | Often requires chaining multiple blocks |
| **Runs without the app** | Automations are native launchd jobs — they run even if Automata isn't open | Shortcuts app must be installed; some triggers need it running |
| **File watching** | Watches folders for new files (launchd WatchPaths) | No native folder-watching trigger |
| **Drive mount trigger** | Fires when USB/SD card is plugged in | Not available as a trigger |
| **Transparency** | You can inspect the generated scripts and plists in `~/.mac-automata/` | Black box — no way to see what's running under the hood |
| **No account needed** | Works immediately, no Apple ID or iCloud | Requires iCloud for sync and some features |
| **Lightweight** | Menu bar icon, ~2 MB, no background daemon | Full app in /Applications, heavier footprint |

### What Apple Shortcuts does better

| | Apple Shortcuts | Automata |
|--|----------------|-------------|
| **Conditional logic** | If/else, loops, variables, data passing between steps | Single trigger + single action only, no chaining |
| **Multi-step workflows** | Chain unlimited actions, pass output from one to the next | One action per automation |
| **Siri integration** | Trigger any shortcut by voice | No voice control |
| **Location triggers** | Run when arriving at or leaving a location | No location awareness |
| **Third-party integrations** | 300+ app integrations via Intents framework | Only system-level actions (apps, files, scripts) |
| **HomeKit / smart home** | Control lights, locks, thermostats | No smart home support |
| **iOS sync** | Shortcuts sync across iPhone, iPad, Mac | macOS only |
| **Data processing** | Text manipulation, math, JSON parsing, API calls | No data processing — just "do this thing" |
| **Focus modes** | Toggle system Focus modes (Do Not Disturb, Work, etc.) | Cannot control Focus modes (requires private API) |
| **App Intents** | Deep integration with apps that expose their actions | Can only open/quit apps, not control them internally |
| **Sandbox safety** | Runs in Apple's sandbox with permission prompts per action | Scripts run with your full user permissions |
| **Gallery** | Thousands of community-shared shortcuts | Only the 20 built-in templates |

### The bottom line

Use Automata when you want **simple, reliable, set-and-forget rules**: open my apps at 9 AM, mute at 11 PM, clean Downloads every Sunday, remind me to stretch. These are the automations most people actually use daily, and Automata makes them trivial to set up.

Use Apple Shortcuts when you need **complex workflows**: "When I arrive at the office, check my calendar, send a Slack message, set my Focus to Work, and adjust my HomeKit lights." That kind of chained logic is what Shortcuts was built for.

## Installation

Download the latest `Automata.dmg`, open it, and drag **Automata** to your Applications folder. On first launch, macOS may ask you to confirm opening an app from the internet — click Open.

## Permissions

Automata needs a few macOS permissions to work. These are requested on first launch:

| Permission | Why it's needed | Which automations use it |
|-----------|----------------|-------------------------|
| **Automation (System Events)** | Control appearance (Dark Mode), read system state | Dark Mode toggle |
| **Automation (Finder)** | Empty the Trash programmatically | Empty Trash |
| **Notifications** | Display reminder notifications | Stretch Break, Hydration, Eye Break, Backup Reminder |

These are standard macOS permission prompts. Automata never accesses your data — it just needs permission to run AppleScripts that talk to System Events and Finder.

## Technical Details

### Architecture

```
Trigger (When)          Action (Do this)
     |                       |
     v                       v
TriggerType.swift       ActionType.swift
  - plist entries          - script generation
  - sentence fragment      - sentence fragment
  - config fields          - config fields
     |                       |
     +----------+------------+
                |
          Automation model
          (trigger + action + configs)
                |
        +-------+--------+
        |                |
  LaunchdService    ScriptService
  (plist install)   (script write)
        |                |
        v                v
  ~/Library/        ~/.mac-automata/
  LaunchAgents/     scripts/
```

### Where files live

| What | Location |
|------|----------|
| Automation configs | `~/.mac-automata/manifest.json` |
| Generated scripts | `~/.mac-automata/scripts/` |
| Activity logs | `~/.mac-automata/logs/` |
| Launchd plists | `~/Library/LaunchAgents/com.macautomata.*.plist` |

### How scheduling works

Automata doesn't run a background daemon. It generates standard macOS launchd property list files — the same mechanism that macOS itself uses for system services. Once a plist is installed, macOS handles the scheduling natively:

- **Scheduled time** automations use `StartCalendarInterval` — fires at a specific hour/minute/weekday
- **Interval** automations use `StartInterval` — fires every N seconds
- **Login** automations use `RunAtLoad` — fires once when the launchd agent loads
- **File watcher** automations use `WatchPaths` — fires when a directory's contents change
- **Drive mount** automations use `StartOnMount` — fires when a volume is mounted

This means automations keep running even if Automata is quit. The app is only needed for creating and managing automations.

## Building from Source

```bash
git clone https://github.com/madebysan/mac-automata.git
cd mac-automata
swift build
.build/debug/MacAutomata
```

### Create a distributable .app + DMG

```bash
chmod +x scripts/build-dmg.sh
./scripts/build-dmg.sh
```

## Uninstalling

Before removing the app, use "Manage Automations" to delete all automations, or use the menu bar's remove option. This unloads the launchd plists and deletes scripts.

Manual cleanup:
```bash
launchctl list | grep macautomata | awk '{print $3}' | xargs -I {} launchctl remove {}
rm ~/Library/LaunchAgents/com.macautomata.*.plist
rm -rf ~/.mac-automata
```

## Requirements

- macOS 13 (Ventura) or later
- No dependencies, no frameworks, no package manager packages

## License

MIT
