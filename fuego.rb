cask "fuego" do
  version "1.0.0"
  sha256 :no_check

  url "https://github.com/your-username/Fuego/releases/download/v#{version}/Fuego-v#{version}.zip"
  name "Fuego"
  desc "Open-source Focus app alternative for macOS"
  homepage "https://github.com/your-username/Fuego"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "Fuego.app"

  uninstall quit: "com.fuego.app"

  zap trash: [
    "~/Library/Application Support/Fuego",
    "~/Library/Caches/com.fuego.app",
    "~/Library/Preferences/com.fuego.app.plist",
    "~/Library/Saved Application State/com.fuego.app.savedState",
    "~/Documents/Fuego.sqlite",
    "~/Documents/focus_log.txt",
  ]
end