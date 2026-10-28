# AI Usage

A macOS app that shows your Claude usage next to the MacBook notch.

- **Collapsed:** a small area on the right of the notch shows the 5-hour session % and the weekly %. It checks for new numbers every 5 seconds.
- **Hover:** a two-row box drops down under the whole notch, showing a bar, the % and the reset time for the 5-hour and weekly limits.
- **Settings:** choose from 9 styles for the collapsed view, show or hide the Claude icon, and turn on launch at login. To open Settings, click the gear in the hover box, right-click the notch, or open the app again.

On Macs without a notch, it shows as a small pill at the top centre of the screen.

## Install

```sh
brew tap umairnawaz333/tap
brew install --cask ai-usage
```

To remove it completely and restore your original Claude Code status line:

```sh
brew uninstall --zap --cask ai-usage
```

## Connecting Claude

There's no login. On first launch, click **Connect** in Settings.

Claude Code sends the usage limits (`rate_limits`) to whatever program is set as its status line. Connecting sets `statusLine.command` in `~/.claude/settings.json` to a small bridge script (`~/Library/Application Support/AIUsage/bridge.sh`). The bridge:

1. saves each update for the app (one file per Claude Code session), then
2. runs your original status line command, if you had one, with the same input, so your status line looks exactly as before.

Your own status line script is never edited. A backup of `settings.json` is kept as `settings.json.aiusage-backup`, and **Disconnect** restores the original `statusLine` setting.

The numbers refresh while Claude Code is running. If several sessions are open, the app shows the highest value for the current window, because idle sessions report older numbers. Once a reset time passes, that limit shows 0% until new numbers arrive.

## Macs without a notch

It shows as a small pill at the top centre of the screen. To preview that on a notched Mac:

```sh
defaults write com.umairnawaz.AIUsage simulateNoNotch -bool YES   # then relaunch; delete the key to undo
```

## Build and run

Requires macOS 14+ and Xcode command line tools.

```sh
scripts/build-app.sh          # builds "build/AI Usage.app"
open "build/AI Usage.app"
scripts/make-dmg.sh           # builds "build/AI-Usage-<version>.dmg" for sharing
scripts/release.sh            # builds build/AI-Usage.zip and the Homebrew cask build/ai-usage.rb
swift test                    # unit tests
swift scripts/make-icon.swift # redraws Resources/AppIcon.icns
```

The app is ad-hoc signed for now. To share it without macOS security warnings, it needs a Developer ID Application certificate (paid Apple Developer Program) plus notarization.

The version shown in Settings comes from the `VERSION` file. The build number is the git commit count.

## Design previews

`preview/index.html` and `preview/variants.html` are the HTML mockups used to choose the design.
