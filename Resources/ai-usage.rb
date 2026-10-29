cask "ai-usage" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "https://github.com/umairnawaz333/AIUsage/releases/download/v#{version}/AI-Usage.zip"
  name "AI Usage"
  desc "Shows Claude usage limits next to the MacBook notch"
  homepage "https://github.com/umairnawaz333/AIUsage"

  depends_on macos: :sonoma

  app "AI Usage.app"

  # The app is ad-hoc signed, so remove the download quarantine to let it open.
  postflight_steps do
    run "/usr/bin/xattr",
        args:         ["-rd", "com.apple.quarantine", "{{appdir}}/AI Usage.app"],
        must_succeed: false
  end

  uninstall quit: "com.umairnawaz.AIUsage"

  # Restore the user's original Claude Code status line before removing the bridge.
  zap script: {
        executable:   "#{appdir}/AI Usage.app/Contents/MacOS/AIUsage",
        args:         ["--disconnect"],
        must_succeed: false,
      },
      trash:  [
        "~/Library/Application Support/AIUsage",
        "~/Library/Preferences/com.umairnawaz.AIUsage.plist",
      ]

  caveats <<~EOS
    Open AI Usage and click Connect in Settings to link it to Claude Code.
    To remove it completely (and restore your original status line), use:
      brew uninstall --zap --cask umairnawaz333/tap/ai-usage
  EOS
end
