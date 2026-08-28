import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  // Injected by the Omarchy shell service loader.
  property var shell: null
  property var manifest: null

  readonly property string homeDir: Quickshell.env("HOME")
  readonly property string settingsPath: homeDir + "/.config/wayvibes/omarchy.json"
  readonly property string soundpacksRoot: homeDir + "/.local/share/wayvibes/soundpacks"

  property bool settingsLoaded: false
  property bool soundsEnabled: true
  property string pack: "nk-cream"
  property real volume: 1.0
  property var packVolumes: ({})
  property string deviceName: ""
  property string lastMessage: "Loading settings…"
  property string lastError: ""
  property bool restartPending: false

  readonly property bool running: wayvibesProcess.running
  readonly property string statusLabel: running
    ? (deviceName !== "" ? "Listening on " + deviceName : "Listening for keyboard events")
    : (soundsEnabled ? "Starting…" : "Keyboard sounds are off")

  readonly property var packOptions: [
    { value: "nk-cream", label: "NK Cream" },
    { value: "eg-crystal-purple", label: "Everglide Crystal Purple" },
    { value: "eg-oreo", label: "Everglide Oreo" },
    { value: "Creams", label: "Creams" },
    { value: "akko_lavender_purples", label: "Akko Lavender Purple" },
    { value: "apex pro", label: "Apex Pro" },
    { value: "banana split lubed", label: "Banana Split — Lubed" },
    { value: "banana split stock", label: "Banana Split — Stock" },
    { value: "boxjade", label: "Box Jade" },
    { value: "cherrymx-black-abs", label: "Cherry MX Black — ABS" },
    { value: "cherrymx-black-pbt", label: "Cherry MX Black — PBT" },
    { value: "cherrymx-blue-abs", label: "Cherry MX Blue — ABS" },
    { value: "cherrymx-blue-pbt", label: "Cherry MX Blue — PBT" },
    { value: "cherrymx-brown-pbt", label: "Cherry MX Brown — PBT" },
    { value: "cherrymx-red-abs", label: "Cherry MX Red — ABS" },
    { value: "cherrymx-red-pbt", label: "Cherry MX Red — PBT" },
    { value: "kalih-box-white", label: "Kailh Box White" },
    { value: "mx-speed-silver", label: "MX Speed Silver" },
    { value: "Razer Green (Blackwidow Elite) - Akira", label: "Razer Green" },
    { value: "topre-purple-hybrid-pbt", label: "Topre Purple Hybrid — PBT" }
  ]

  function isKnownPack(name) {
    for (var i = 0; i < packOptions.length; i++) {
      if (String(packOptions[i].value) === String(name)) return true
    }
    return false
  }

  function packPath(name) {
    return soundpacksRoot + "/" + name
  }

  function clampVolume(value) {
    var numeric = Number(value)
    if (!isFinite(numeric)) return 1.0
    return Math.max(0, Math.min(3, Math.round(numeric * 20) / 20))
  }

  function sanitizedPackVolumes(raw) {
    var cleaned = {}
    if (!raw || typeof raw !== "object") return cleaned

    for (var i = 0; i < root.packOptions.length; i++) {
      var name = String(root.packOptions[i].value)
      if (raw[name] === undefined || !isFinite(Number(raw[name]))) continue
      cleaned[name] = root.clampVolume(raw[name])
    }
    return cleaned
  }

  function hasSavedPackVolume(name) {
    return root.packVolumes
      && root.packVolumes[String(name)] !== undefined
      && isFinite(Number(root.packVolumes[String(name)]))
  }

  function savedVolumeForPack(name, fallback) {
    return root.hasSavedPackVolume(name)
      ? root.clampVolume(root.packVolumes[String(name)])
      : root.clampVolume(fallback)
  }

  function rememberPackVolume(name, value) {
    var updated = root.sanitizedPackVolumes(root.packVolumes)
    updated[String(name)] = root.clampVolume(value)
    root.packVolumes = updated
  }

  function applySettings(raw) {
    var parsed = null
    try {
      parsed = JSON.parse(String(raw || "{}"))
    } catch (error) {
      root.lastError = "Could not read Wayvibes settings; defaults are in use."
      parsed = ({})
    }

    root.soundsEnabled = parsed.enabled === undefined ? true : !!parsed.enabled
    root.pack = root.isKnownPack(parsed.pack) ? String(parsed.pack) : "nk-cream"
    root.packVolumes = root.sanitizedPackVolumes(parsed.packVolumes)
    var legacyVolume = root.clampVolume(parsed.volume === undefined ? 1.0 : parsed.volume)
    var selectedPackHadProfile = root.hasSavedPackVolume(root.pack)
    root.volume = root.savedVolumeForPack(root.pack, legacyVolume)
    root.rememberPackVolume(root.pack, root.volume)
    root.deviceName = String(parsed.deviceName || "")
    root.settingsLoaded = true
    root.lastMessage = root.soundsEnabled ? "Starting Wayvibes…" : "Keyboard sounds are off"

    if (!selectedPackHadProfile) settingsMigrationTimer.restart()
    if (root.soundsEnabled) startTimer.restart()
  }

  function persistSettings() {
    if (!root.settingsLoaded) return
    settingsFile.setText(JSON.stringify({
      enabled: root.soundsEnabled,
      pack: root.pack,
      volume: root.volume,
      packVolumes: root.packVolumes,
      deviceName: root.deviceName
    }, null, 2) + "\n")
  }

  function setEnabled(value) {
    var next = !!value
    if (root.soundsEnabled === next) return
    root.soundsEnabled = next
    root.persistSettings()
    if (next) {
      root.lastMessage = "Starting Wayvibes…"
      startTimer.restart()
    } else {
      root.stop()
    }
  }

  function toggle() {
    root.setEnabled(!root.soundsEnabled)
  }

  function setPack(name) {
    var next = String(name || "")
    if (!root.isKnownPack(next) || root.pack === next) return

    var fallbackVolume = root.volume
    root.rememberPackVolume(root.pack, root.volume)
    root.pack = next
    root.volume = root.savedVolumeForPack(next, fallbackVolume)
    root.rememberPackVolume(next, root.volume)
    root.persistSettings()
    root.requestRestart()
  }

  function setVolume(value) {
    var next = root.clampVolume(value)
    if (Math.abs(root.volume - next) < 0.001) return
    root.volume = next
    root.rememberPackVolume(root.pack, next)
    root.persistSettings()
    root.requestRestart()
  }

  function requestRestart() {
    if (!root.soundsEnabled) return
    root.lastMessage = "Applying Wayvibes settings…"
    if (wayvibesProcess.running) {
      root.restartPending = true
      wayvibesProcess.running = false
    } else {
      startTimer.restart()
    }
  }

  function restart() {
    if (!root.soundsEnabled) {
      root.setEnabled(true)
      return
    }
    root.requestRestart()
  }

  function start() {
    if (!root.settingsLoaded || !root.soundsEnabled || wayvibesProcess.running) return

    root.restartPending = false
    root.lastError = ""
    root.lastMessage = "Starting Wayvibes…"
    var command = ["wayvibes"]
    if (root.deviceName !== "")
      command.push("--device-name", root.deviceName)
    command.push(root.packPath(root.pack), "-v", String(root.volume))
    wayvibesProcess.command = command
    wayvibesProcess.running = true
  }

  function stop() {
    root.restartPending = false
    startTimer.stop()
    if (wayvibesProcess.running) wayvibesProcess.running = false
    root.lastMessage = "Keyboard sounds are off"
    root.lastError = ""
  }

  function handleOutput(data) {
    var message = String(data || "").trim()
    if (!message) return
    root.lastMessage = message
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    atomicWrites: true
    printErrors: false
    onLoaded: root.applySettings(text())
    onLoadFailed: root.applySettings("{}")
  }

  Timer {
    id: startTimer
    interval: 180
    repeat: false
    onTriggered: root.start()
  }

  Timer {
    id: settingsMigrationTimer
    interval: 1
    repeat: false
    onTriggered: root.persistSettings()
  }

  Process {
    id: wayvibesProcess

    stdout: SplitParser {
      onRead: function(data) { root.handleOutput(data) }
    }

    stderr: SplitParser {
      onRead: function(data) {
        var message = String(data || "").trim()
        if (!message) return
        root.lastError = message
        root.lastMessage = message
      }
    }

    onRunningChanged: {
      if (running) root.lastMessage = "Wayvibes is listening"
    }

    onExited: function(exitCode) {
      if (root.restartPending && root.soundsEnabled) {
        root.restartPending = false
        startTimer.restart()
        return
      }

      if (!root.soundsEnabled) return
      if (!root.lastError)
        root.lastError = "Wayvibes stopped unexpectedly (exit " + exitCode + ")."
    }
  }

  Component.onDestruction: {
    if (wayvibesProcess.running) wayvibesProcess.running = false
  }

  IpcHandler {
    target: "typetone"

    function status(): string {
      return JSON.stringify({
        enabled: root.soundsEnabled,
        running: root.running,
        pack: root.pack,
        volume: root.volume,
        packVolumes: root.packVolumes,
        deviceName: root.deviceName,
        message: root.lastMessage,
        error: root.lastError
      })
    }

    function enable(): string {
      root.setEnabled(true)
      return "enabled"
    }

    function disable(): string {
      root.setEnabled(false)
      return "disabled"
    }

    function toggle(): string {
      var enabling = !root.soundsEnabled
      root.setEnabled(enabling)
      return enabling ? "enabled" : "disabled"
    }

    function restart(): string {
      root.restart()
      return "restarting"
    }
  }
}
