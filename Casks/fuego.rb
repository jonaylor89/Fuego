cask "fuego" do
  version "1.0.0"
  sha256 "71b7279e4b49e1c1db89edf749f2edb5f382e52f0acef2071c7cde37148383f2"

  url "https://github.com/jonaylor89/Fuego/releases/download/v#{version}/Fuego-#{version}.dmg"
  name "Fuego"
  desc "Menu bar focus timer that blocks distracting websites and apps"
  homepage "https://getfuego.dev/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sequoia

  app "Fuego.app"

  uninstall quit: "dev.getfuego.FuegoFocus"

  zap trash: "~/Library/Preferences/dev.getfuego.FuegoFocus.plist"

  caveats <<~EOS
    Fuego blocks websites with a content filter that macOS asks you to approve
    the first time you start a focus session.

    `brew uninstall` leaves the content filter installed. Remove it in
    System Settings → General → Login Items & Extensions → Network Extensions.
  EOS
end
