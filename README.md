# AI Usage

A macOS app that shows your Claude usage next to the MacBook notch.

- **Collapsed:** a small area on the right of the notch shows the 5-hour session % and the weekly %.
- **Hover:** a two-row box drops down under the whole notch, showing a bar, the % and the reset time for the 5-hour and weekly limits.
- **Settings:** choose from 9 styles for the collapsed view, show or hide the Claude icon, and turn on launch at login. To open Settings, right-click the notch or open the app again.

On Macs without a notch, it shows as a small pill at the top centre of the screen.

## Where the numbers come from

The app reads `~/.claude/usage-now.txt`, which the Claude Code status line writes every 10 seconds while Claude Code is running:

```
<saved_epoch> <5h_pct> <5h_reset_epoch> <weekly_pct> <weekly_reset_epoch>
```

Once a reset time has passed, that limit shows 0% until fresh numbers arrive.

## Build and run

Requires macOS 14+ and Xcode command line tools.

```sh
scripts/build-app.sh          # builds "build/AI Usage.app"
open "build/AI Usage.app"
swift test                    # unit tests
```

The version shown in Settings comes from the `VERSION` file. The build number is the git commit count.

## Design previews

`preview/index.html` and `preview/variants.html` are the HTML mockups used to choose the design.
