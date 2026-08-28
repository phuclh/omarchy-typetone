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
  readonly property string mouseSoundpacksRoot: resolvedLocalPath("mouse-sounds")
  readonly property string mouseDeviceListScript: resolvedLocalPath("scripts/list-pointing-devices.sh")
  readonly property string mouseRunnerScript: resolvedLocalPath("scripts/run-mouse-wayvibes.sh")
  readonly property string mouseConfigHome: homeDir + "/.config/wayvibes/typetone-mouse"

  property bool settingsLoaded: false
  property bool soundsEnabled: true
  property string pack: "nk-cream"
  property real volume: 1.0
  property var packVolumes: ({})
  property string deviceName: ""
  property bool mouseEnabled: false
  property string mousePack: "crisp"
  property real mouseVolume: 0.75
  property var mousePackVolumes: ({})
  property string mouseDeviceName: ""
  property var mouseDeviceOptions: []
  property bool mouseScanPending: false
  property string mouseLastMessage: "Mouse sounds are off"
  property string mouseLastError: ""
  property string lastMessage: "Loading settings…"
  property string lastError: ""
  property bool restartPending: false
  property bool mouseRestartPending: false

  readonly property bool running: wayvibesProcess.running
  readonly property bool mouseRunning: mouseWayvibesProcess.running
  readonly property string mouseDevicePath: pathForMouseDevice(mouseDeviceName)
  readonly property string keyboardStatusLabel: running
    ? (deviceName !== "" ? "Listening on " + deviceName : "Listening for keyboard events")
    : (soundsEnabled ? "Starting…" : "Keyboard sounds are off")
  readonly property string mouseStatusLabel: mouseRunning
    ? "Listening on " + currentMouseDeviceLabel()
    : (mouseEnabled
      ? (mouseDeviceOptions.length > 0 ? "Starting mouse sounds…" : "No pointing device found")
      : "Mouse sounds are off")
  readonly property string statusLabel: running && mouseRunning
    ? "Keyboard and mouse sounds active"
    : (running ? keyboardStatusLabel : (mouseRunning ? mouseStatusLabel
      : ((soundsEnabled || mouseEnabled) ? "Starting TypeTone…" : "All sounds are off")))

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

  readonly property var mousePackOptions: [
    { value: "crisp", label: "Crisp" },
    { value: "soft", label: "Soft" },
    { value: "deep", label: "Deep" }
  ]

  function resolvedLocalPath(relativePath) {
    var value = String(Qt.resolvedUrl(relativePath))
    if (value.indexOf("file://") === 0) return decodeURIComponent(value.substring(7))
    return value
  }

  function isKnownPack(name) {
    for (var i = 0; i < packOptions.length; i++) {
      if (String(packOptions[i].value) === String(name)) return true
    }
    return false
  }

  function isKnownMousePack(name) {
    for (var i = 0; i < mousePackOptions.length; i++) {
      if (String(mousePackOptions[i].value) === String(name)) return true
    }
    return false
  }

  function packPath(name) {
    return soundpacksRoot + "/" + name
  }

  function mousePackPath(name) {
    return mouseSoundpacksRoot + "/" + name
  }

  function pathForMouseDevice(name) {
    for (var i = 0; i < mouseDeviceOptions.length; i++) {
      if (String(mouseDeviceOptions[i].value) === String(name))
        return String(mouseDeviceOptions[i].path || "")
    }
    return ""
  }

  function currentMouseDeviceLabel() {
    for (var i = 0; i < mouseDeviceOptions.length; i++) {
      if (String(mouseDeviceOptions[i].value) === String(mouseDeviceName))
        return String(mouseDeviceOptions[i].label || mouseDeviceName)
    }
    return mouseDeviceName !== "" ? mouseDeviceName : "pointing device"
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

  function sanitizedMousePackVolumes(raw) {
    var cleaned = {}
    if (!raw || typeof raw !== "object") return cleaned

    for (var i = 0; i < root.mousePackOptions.length; i++) {
      var name = String(root.mousePackOptions[i].value)
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

  function hasSavedMousePackVolume(name) {
    return root.mousePackVolumes
      && root.mousePackVolumes[String(name)] !== undefined
      && isFinite(Number(root.mousePackVolumes[String(name)]))
  }

  function savedVolumeForMousePack(name, fallback) {
    return root.hasSavedMousePackVolume(name)
      ? root.clampVolume(root.mousePackVolumes[String(name)])
      : root.clampVolume(fallback)
  }

  function rememberMousePackVolume(name, value) {
    var updated = root.sanitizedMousePackVolumes(root.mousePackVolumes)
    updated[String(name)] = root.clampVolume(value)
    root.mousePackVolumes = updated
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

    root.mouseEnabled = parsed.mouseEnabled === undefined ? false : !!parsed.mouseEnabled
    root.mousePack = root.isKnownMousePack(parsed.mousePack) ? String(parsed.mousePack) : "crisp"
    root.mousePackVolumes = root.sanitizedMousePackVolumes(parsed.mousePackVolumes)
    var legacyMouseVolume = root.clampVolume(
      parsed.mouseVolume === undefined ? 0.75 : parsed.mouseVolume)
    var selectedMousePackHadProfile = root.hasSavedMousePackVolume(root.mousePack)
    root.mouseVolume = root.savedVolumeForMousePack(root.mousePack, legacyMouseVolume)
    root.rememberMousePackVolume(root.mousePack, root.mouseVolume)
    root.mouseDeviceName = String(parsed.mouseDeviceName || "")
    root.settingsLoaded = true
    root.lastMessage = root.soundsEnabled ? "Starting Wayvibes…" : "Keyboard sounds are off"
    root.mouseLastMessage = root.mouseEnabled ? "Finding pointing devices…" : "Mouse sounds are off"

    if (!selectedPackHadProfile || !selectedMousePackHadProfile
        || parsed.mouseEnabled === undefined || parsed.mouseDeviceName === undefined)
      settingsMigrationTimer.restart()
    if (root.soundsEnabled) startTimer.restart()
    root.rescanMouseDevices()
  }

  function persistSettings() {
    if (!root.settingsLoaded) return
    settingsFile.setText(JSON.stringify({
      enabled: root.soundsEnabled,
      pack: root.pack,
      volume: root.volume,
      packVolumes: root.packVolumes,
      deviceName: root.deviceName,
      mouseEnabled: root.mouseEnabled,
      mousePack: root.mousePack,
      mouseVolume: root.mouseVolume,
      mousePackVolumes: root.mousePackVolumes,
      mouseDeviceName: root.mouseDeviceName
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

  function setMouseEnabled(value) {
    var next = !!value
    if (root.mouseEnabled === next) return
    root.mouseEnabled = next
    root.persistSettings()
    if (next) {
      root.mouseLastMessage = "Finding pointing devices…"
      if (root.mouseDeviceOptions.length === 0) root.rescanMouseDevices()
      else mouseStartTimer.restart()
    } else {
      root.stopMouse()
    }
  }

  function toggleMouse() {
    root.setMouseEnabled(!root.mouseEnabled)
  }

  function setMousePack(name) {
    var next = String(name || "")
    if (!root.isKnownMousePack(next) || root.mousePack === next) return

    var fallbackVolume = root.mouseVolume
    root.rememberMousePackVolume(root.mousePack, root.mouseVolume)
    root.mousePack = next
    root.mouseVolume = root.savedVolumeForMousePack(next, fallbackVolume)
    root.rememberMousePackVolume(next, root.mouseVolume)
    root.persistSettings()
    root.requestMouseRestart()
  }

  function setMouseVolume(value) {
    var next = root.clampVolume(value)
    if (Math.abs(root.mouseVolume - next) < 0.001) return
    root.mouseVolume = next
    root.rememberMousePackVolume(root.mousePack, next)
    root.persistSettings()
    root.requestMouseRestart()
  }

  function setMouseDevice(name) {
    var next = String(name || "")
    if (root.pathForMouseDevice(next) === "" || root.mouseDeviceName === next) return
    root.mouseDeviceName = next
    root.persistSettings()
    root.requestMouseRestart()
  }

  function rescanMouseDevices() {
    if (mouseDeviceScanProcess.running) return
    root.mouseScanPending = true
    root.mouseLastError = ""
    root.mouseLastMessage = "Finding pointing devices…"
    mouseDeviceScanProcess.running = true
  }

  function applyMouseDeviceScan(raw) {
    var candidates = []
    var seen = ({})
    var lines = String(raw || "").split("\n")

    for (var i = 0; i < lines.length; i++) {
      var line = String(lines[i] || "").trim()
      if (line === "") continue
      var fields = line.split("\t")
      if (fields.length < 2) continue
      var path = String(fields.shift() || "")
      var name = String(fields.join("\t") || "")
      if (path === "" || name === "" || seen[name]) continue
      seen[name] = true
      candidates.push({ value: name, label: name, path: path })
    }

    var previousName = root.mouseDeviceName
    var savedDeviceStillAvailable = false
    for (var j = 0; j < candidates.length; j++) {
      if (String(candidates[j].value) === previousName) {
        savedDeviceStillAvailable = true
        break
      }
    }

    root.mouseDeviceOptions = candidates
    if (!savedDeviceStillAvailable)
      root.mouseDeviceName = candidates.length > 0 ? String(candidates[0].value) : ""
    root.mouseScanPending = false

    if (root.mouseDeviceName !== previousName) root.persistSettings()

    if (candidates.length === 0) {
      root.stopMouse()
      root.mouseLastMessage = "No mouse or touchpad found"
      root.mouseLastError = "No click-capable pointing device was detected."
      return
    }

    root.mouseLastMessage = root.mouseEnabled ? "Starting mouse sounds…" : "Mouse sounds are off"
    if (root.mouseEnabled) root.requestMouseRestart()
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

  function requestMouseRestart() {
    if (!root.mouseEnabled) return
    root.mouseLastMessage = "Applying mouse sound settings…"
    if (mouseWayvibesProcess.running) {
      root.mouseRestartPending = true
      mouseWayvibesProcess.running = false
    } else {
      mouseStartTimer.restart()
    }
  }

  function restartMouse() {
    if (!root.mouseEnabled) {
      root.setMouseEnabled(true)
      return
    }
    root.requestMouseRestart()
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

  function startMouse() {
    if (!root.settingsLoaded || !root.mouseEnabled || mouseWayvibesProcess.running) return
    if (root.mouseDevicePath === "") {
      root.rescanMouseDevices()
      return
    }

    root.mouseRestartPending = false
    root.mouseLastError = ""
    root.mouseLastMessage = "Starting mouse sounds…"
    mouseWayvibesProcess.command = [
      root.mouseRunnerScript,
      root.mouseConfigHome,
      root.mouseDevicePath,
      root.mousePackPath(root.mousePack),
      String(root.mouseVolume)
    ]
    mouseWayvibesProcess.running = true
  }

  function stopMouse() {
    root.mouseRestartPending = false
    mouseStartTimer.stop()
    if (mouseWayvibesProcess.running) mouseWayvibesProcess.running = false
    root.mouseLastMessage = "Mouse sounds are off"
    root.mouseLastError = ""
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
    id: mouseStartTimer
    interval: 180
    repeat: false
    onTriggered: root.startMouse()
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

  Process {
    id: mouseDeviceScanProcess
    command: [root.mouseDeviceListScript]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyMouseDeviceScan(text)
    }

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "") root.mouseLastError = message
      }
    }

    onExited: function(exitCode) {
      if (exitCode === 0) return
      root.mouseScanPending = false
      if (root.mouseLastError === "")
        root.mouseLastError = "Could not scan pointing devices (exit " + exitCode + ")."
    }
  }

  Process {
    id: mouseWayvibesProcess

    stdout: SplitParser {
      onRead: function(data) {
        var message = String(data || "").trim()
        if (message !== "") root.mouseLastMessage = message
      }
    }

    stderr: SplitParser {
      onRead: function(data) {
        var message = String(data || "").trim()
        if (message === "") return
        root.mouseLastError = message
        root.mouseLastMessage = message
      }
    }

    onRunningChanged: {
      if (running) root.mouseLastMessage = "Wayvibes is listening for mouse clicks"
    }

    onExited: function(exitCode) {
      if (root.mouseRestartPending && root.mouseEnabled) {
        root.mouseRestartPending = false
        mouseStartTimer.restart()
        return
      }

      if (!root.mouseEnabled) return
      if (!root.mouseLastError)
        root.mouseLastError = "Mouse Wayvibes stopped unexpectedly (exit " + exitCode + ")."
    }
  }

  Component.onDestruction: {
    if (wayvibesProcess.running) wayvibesProcess.running = false
    if (mouseWayvibesProcess.running) mouseWayvibesProcess.running = false
    if (mouseDeviceScanProcess.running) mouseDeviceScanProcess.running = false
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
        mouseEnabled: root.mouseEnabled,
        mouseRunning: root.mouseRunning,
        mousePack: root.mousePack,
        mouseVolume: root.mouseVolume,
        mousePackVolumes: root.mousePackVolumes,
        mouseDeviceName: root.mouseDeviceName,
        mouseDevicePath: root.mouseDevicePath,
        mouseDevices: root.mouseDeviceOptions,
        mouseMessage: root.mouseLastMessage,
        mouseError: root.mouseLastError,
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

    function enableMouse(): string {
      root.setMouseEnabled(true)
      return "enabled"
    }

    function disableMouse(): string {
      root.setMouseEnabled(false)
      return "disabled"
    }

    function toggleMouse(): string {
      var enabling = !root.mouseEnabled
      root.setMouseEnabled(enabling)
      return enabling ? "enabled" : "disabled"
    }

    function restartMouse(): string {
      root.restartMouse()
      return "restarting"
    }

    function rescanMouseDevices(): string {
      root.rescanMouseDevices()
      return "scanning"
    }
  }
}
