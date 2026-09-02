import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.phuclh.typetone"

  readonly property var wayvibesService: bar?.shell?.serviceFor(root.moduleName)
  readonly property bool soundsEnabled: wayvibesService ? wayvibesService.soundsEnabled : false
  readonly property bool soundsRunning: wayvibesService ? wayvibesService.running : false
  readonly property bool mouseEnabled: wayvibesService ? wayvibesService.mouseEnabled : false
  readonly property bool mouseRunning: wayvibesService ? wayvibesService.mouseRunning : false
  readonly property bool anySoundsEnabled: soundsEnabled || mouseEnabled
  readonly property var packOptions: wayvibesService ? wayvibesService.packOptions : []
  readonly property var mousePackOptions: wayvibesService ? wayvibesService.mousePackOptions : []
  readonly property var mouseDeviceOptions: wayvibesService ? wayvibesService.mouseDeviceOptions : []
  readonly property int visiblePackRows: Math.min(packOptions.length, 8)
  readonly property real packPickerHeight: visiblePackRows * Style.spacing.popupRowHeight
    + Math.max(0, visiblePackRows - 1) * Style.spacing.labelGap
    + Style.spacing.hairline * 2
  readonly property real mousePackPickerHeight: mousePackOptions.length * Style.spacing.popupRowHeight
    + Math.max(0, mousePackOptions.length - 1) * Style.spacing.labelGap
    + Style.spacing.hairline * 2
  readonly property int visibleMouseDeviceRows: Math.min(mouseDeviceOptions.length, 4)
  readonly property real mouseDevicePickerHeight: visibleMouseDeviceRows * Style.spacing.popupRowHeight
    + Math.max(0, visibleMouseDeviceRows - 1) * Style.spacing.labelGap
    + Style.spacing.hairline * 2
  property bool popupOpen: false
  property bool packPickerOpen: false
  property bool mousePackPickerOpen: false
  property bool mouseDevicePickerOpen: false
  property bool restartConfirmOpen: false
  property string settingsPage: "keyboard"

  function packValue(option) {
    return option && typeof option === "object" ? String(option.value) : String(option)
  }

  function packLabel(option) {
    return option && typeof option === "object" ? String(option.label) : String(option)
  }

  function currentPackLabel() {
    var current = root.wayvibesService ? root.wayvibesService.pack : "nk-cream"
    for (var i = 0; i < root.packOptions.length; i++) {
      if (root.packValue(root.packOptions[i]) === current)
        return root.packLabel(root.packOptions[i])
    }
    return current
  }

  function currentPackIndex() {
    var current = root.wayvibesService ? root.wayvibesService.pack : "nk-cream"
    for (var i = 0; i < root.packOptions.length; i++) {
      if (root.packValue(root.packOptions[i]) === current) return i
    }
    return 0
  }

  function currentMousePackLabel() {
    var current = root.wayvibesService ? root.wayvibesService.mousePack : "crisp"
    for (var i = 0; i < root.mousePackOptions.length; i++) {
      if (root.packValue(root.mousePackOptions[i]) === current)
        return root.packLabel(root.mousePackOptions[i])
    }
    return current
  }

  function currentMousePackIndex() {
    var current = root.wayvibesService ? root.wayvibesService.mousePack : "crisp"
    for (var i = 0; i < root.mousePackOptions.length; i++) {
      if (root.packValue(root.mousePackOptions[i]) === current) return i
    }
    return 0
  }

  function currentMouseDeviceLabel() {
    if (!root.wayvibesService || root.mouseDeviceOptions.length === 0)
      return "No pointing device found"
    return root.wayvibesService.currentMouseDeviceLabel()
  }

  function currentMouseDeviceIndex() {
    var current = root.wayvibesService ? root.wayvibesService.mouseDeviceName : ""
    for (var i = 0; i < root.mouseDeviceOptions.length; i++) {
      if (root.packValue(root.mouseDeviceOptions[i]) === current) return i
    }
    return 0
  }

  function closePickers() {
    root.packPickerOpen = false
    root.mousePackPickerOpen = false
    root.mouseDevicePickerOpen = false
  }

  function showSettingsPage(page) {
    root.closePickers()
    root.settingsPage = page
  }

  function togglePackPicker() {
    root.mousePackPickerOpen = false
    root.mouseDevicePickerOpen = false
    root.packPickerOpen = !root.packPickerOpen
    if (root.packPickerOpen) {
      Qt.callLater(function() {
        packList.currentIndex = root.currentPackIndex()
        packList.positionViewAtIndex(packList.currentIndex, ListView.Center)
      })
    }
  }

  function toggleMousePackPicker() {
    root.packPickerOpen = false
    root.mouseDevicePickerOpen = false
    root.mousePackPickerOpen = !root.mousePackPickerOpen
    if (root.mousePackPickerOpen) {
      Qt.callLater(function() {
        mousePackList.currentIndex = root.currentMousePackIndex()
        mousePackList.positionViewAtIndex(mousePackList.currentIndex, ListView.Center)
      })
    }
  }

  function toggleMouseDevicePicker() {
    root.packPickerOpen = false
    root.mousePackPickerOpen = false
    root.mouseDevicePickerOpen = !root.mouseDevicePickerOpen
    if (root.mouseDevicePickerOpen) {
      Qt.callLater(function() {
        mouseDeviceList.currentIndex = root.currentMouseDeviceIndex()
        mouseDeviceList.positionViewAtIndex(mouseDeviceList.currentIndex, ListView.Center)
      })
    }
  }

  function close() {
    closePickers()
    restartConfirmOpen = false
    popupOpen = false
  }

  onPopupOpenChanged: if (!popupOpen) {
    closePickers()
    restartConfirmOpen = false
  }

  implicitWidth: statusIcon.implicitWidth + Style.space(14)
  implicitHeight: barSize

  Text {
    id: statusIcon
    anchors.centerIn: parent
    text: root.anySoundsEnabled ? "󰌌" : "󰌐"
    color: root.anySoundsEnabled
      ? root.bar.barForeground
      : Qt.darker(root.bar.barForeground, 1.9)
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.icon

    Behavior on color {
      enabled: !root.bar || root.bar.foregroundAnimationEnabled
      ColorAnimation { duration: 140 }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: function(mouse) {
      if (!root.wayvibesService) return
      if (mouse.button === Qt.LeftButton) root.popupOpen = !root.popupOpen
      else root.wayvibesService.toggleMaster()
    }

    onWheel: function(wheel) {
      if (!root.wayvibesService) return
      var delta = wheel.angleDelta.y > 0 ? 0.1 : -0.1
      if (root.settingsPage === "mouse")
        root.wayvibesService.setMouseVolume(root.wayvibesService.mouseVolume + delta)
      else
        root.wayvibesService.setVolume(root.wayvibesService.volume + delta)
    }

    onEntered: if (root.bar) root.bar.showTooltip(
      root,
      (root.soundsEnabled ? "Keyboard sounds on" : "Keyboard sounds off")
        + (root.mouseEnabled ? " · Mouse sounds on" : " · Mouse sounds off")
        + " · Left-click settings · Right-click "
        + (root.anySoundsEnabled ? "mute all" : "restore sounds")
    )
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(350))
    contentHeight: popup.fittedContentHeight(panelColumn.implicitHeight)

    Column {
      id: panelColumn
      anchors.fill: parent
      spacing: Style.space(10)

      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          text: "󰌌"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.iconLarge
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          width: parent.width - Style.space(38)
          spacing: Style.space(2)

          Text {
            text: "TypeTone"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }

          Text {
            text: root.wayvibesService
              ? root.wayvibesService.statusLabel
              : "Service unavailable"
            color: Qt.darker(root.bar.foreground, 1.45)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            width: parent.width
          }
        }
      }

      PanelSeparator { foreground: root.bar.foreground }

      BorderSurface {
        id: inputAccessCard
        width: parent.width
        visible: root.wayvibesService && root.wayvibesService.inputAccessMissing
        implicitHeight: inputAccessContent.implicitHeight + Style.space(20)
        color: Color.popups.background
        borderSpec: Border.flat(Color.urgent, Math.max(1, Style.spacing.hairline))
        radius: Style.cornerRadius

        Column {
          id: inputAccessContent
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(7)

          Row {
            width: parent.width
            spacing: Style.space(7)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.wayvibesService
                && root.wayvibesService.inputAccessNeedsRelogin ? "󰍁" : "󰌾"
              color: Color.urgent
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.icon
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(34)
              text: root.wayvibesService
                ? root.wayvibesService.inputAccessTitle : "Input access required"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.wayvibesService && root.wayvibesService.inputAccessNeedsRelogin
              ? "Access was granted, but an older desktop session is still active. Restart your computer once, then TypeTone will start automatically."
              : "TypeTone uses WayVibes to read global keyboard and mouse events. Granting access adds your account to the Linux input group."
            color: Qt.darker(root.bar.foreground, 1.25)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            visible: root.wayvibesService
              && !root.wayvibesService.inputAccessNeedsRelogin
            textFormat: Text.PlainText
            text: "Other applications running as your user could also read these input events."
            color: Color.urgent
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Row {
            width: parent.width
            spacing: Style.space(6)

            Button {
              width: root.wayvibesService
                && root.wayvibesService.inputAccessNeedsRelogin
                ? parent.width : (parent.width - parent.spacing) / 2
              text: root.wayvibesService && root.wayvibesService.inputAccessNeedsRelogin
                ? "Restart computer"
                : (root.wayvibesService && root.wayvibesService.inputAccessGranting
                  ? "Authorizing…" : "Grant access")
              iconText: root.wayvibesService && root.wayvibesService.inputAccessNeedsRelogin
                ? "󰜉" : (root.wayvibesService && root.wayvibesService.inputAccessGranting
                  ? "󰑐" : "󰌾")
              iconSpinning: root.wayvibesService
                && root.wayvibesService.inputAccessGranting
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              bordered: true
              enabled: root.wayvibesService
                && !root.wayvibesService.inputAccessGranting
              opacity: enabled ? 1 : 0.6
              onClicked: if (root.wayvibesService) {
                if (root.wayvibesService.inputAccessNeedsRelogin)
                  root.restartConfirmOpen = true
                else
                  root.wayvibesService.requestInputAccess()
              }
            }

            Button {
              visible: root.wayvibesService
                && !root.wayvibesService.inputAccessNeedsRelogin
              width: (parent.width - parent.spacing) / 2
              text: "Copy command"
              iconText: "󰆏"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              bordered: true
              enabled: root.wayvibesService
                && !root.wayvibesService.inputAccessGranting
              opacity: enabled ? 1 : 0.6
              onClicked: if (root.wayvibesService)
                root.wayvibesService.copyInputAccessCommand()
            }
          }

          Text {
            width: parent.width
            visible: root.wayvibesService
              && root.wayvibesService.inputAccessActionMessage !== ""
            text: root.wayvibesService
              ? root.wayvibesService.inputAccessActionMessage : ""
            color: Qt.darker(root.bar.foreground, 1.25)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            visible: root.wayvibesService
              && root.wayvibesService.inputAccessActionError !== ""
            text: root.wayvibesService
              ? root.wayvibesService.inputAccessActionError : ""
            color: Color.urgent
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }

        ConfirmDialog {
          anchors.fill: parent
          opened: root.restartConfirmOpen
          z: 10
          message: "Restart now to activate TypeTone? All open applications will be closed."
          confirmText: "Restart"
          background: Color.popups.background
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          onCanceled: root.restartConfirmOpen = false
          onConfirmed: {
            root.restartConfirmOpen = false
            if (root.wayvibesService) root.wayvibesService.restartComputer()
          }
        }
      }

      Row {
        width: parent.width
        spacing: Style.space(6)

        Button {
          width: (parent.width - parent.spacing) / 2
          text: "Keyboard"
          iconText: "󰌌"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          bordered: true
          selected: root.settingsPage === "keyboard"
          onClicked: root.showSettingsPage("keyboard")
        }

        Button {
          width: (parent.width - parent.spacing) / 2
          text: "Mouse"
          iconText: "󰍽"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          bordered: true
          selected: root.settingsPage === "mouse"
          onClicked: root.showSettingsPage("mouse")
        }
      }

      Column {
        id: keyboardSettings
        width: parent.width
        visible: root.settingsPage === "keyboard"
        spacing: Style.space(10)

        Toggle {
          width: parent.width
          label: "Mechanical keyboard sounds"
          description: root.soundsRunning ? "TypeTone is listening for key presses" : "Play a sample for each key press"
          checked: root.soundsEnabled
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          onClicked: if (root.wayvibesService) root.wayvibesService.toggle()
        }

        Column {
          width: parent.width
          spacing: Style.spacing.labelGap

          Text {
            text: "Switch sound"
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Button {
            width: parent.width
            text: root.currentPackLabel()
            iconText: root.packPickerOpen ? "▴" : "▾"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            bordered: true
            selected: root.packPickerOpen
            leftAlign: true
            onClicked: root.togglePackPicker()
          }

          BorderSurface {
            width: parent.width
            height: root.packPickerOpen ? root.packPickerHeight : 0
            visible: root.packPickerOpen
            clip: true
            color: Color.popups.background
            borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)
            radius: Style.cornerRadius

            ListView {
              id: packList
              anchors.fill: parent
              anchors.margins: Style.spacing.hairline
              clip: true
              spacing: Style.spacing.labelGap
              boundsBehavior: Flickable.StopAtBounds
              model: root.packOptions
              currentIndex: root.currentPackIndex()

              delegate: Button {
                required property var modelData

                width: packList.width
                height: Style.spacing.popupRowHeight
                text: root.packLabel(modelData)
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                fontSize: Style.font.body
                leftAlign: true
                selected: root.wayvibesService
                  && root.packValue(modelData) === root.wayvibesService.pack
                onClicked: {
                  if (root.wayvibesService) {
                    root.wayvibesService.setPack(root.packValue(modelData))
                    volumeSlider.liveValue = root.wayvibesService.volume
                  }
                  root.packPickerOpen = false
                }
              }
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(4)

          Item {
            width: parent.width
            implicitHeight: Math.max(volumeLabel.implicitHeight, volumeValue.implicitHeight)

            Text {
              id: volumeLabel
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Volume"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              id: volumeValue
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: Math.round((volumeSlider.dragging
                ? volumeSlider.liveValue
                : (root.wayvibesService ? root.wayvibesService.volume : 1)) * 100) + "%"
              color: Qt.darker(root.bar.foreground, 1.35)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          PanelSlider {
            id: volumeSlider
            bar: root.bar
            width: parent.width
            minimum: 0
            maximum: 3
            step: 0.05
            value: root.wayvibesService ? root.wayvibesService.volume : 1
            onMoved: function(value) {
              if (root.wayvibesService) root.wayvibesService.previewVolume(value)
            }
            onReleased: function(value) {
              if (root.wayvibesService) root.wayvibesService.commitVolume(value)
            }
          }
        }
      }

      Column {
        id: mouseSettings
        width: parent.width
        visible: root.settingsPage === "mouse"
        spacing: Style.space(10)

        Toggle {
          width: parent.width
          label: "Mouse click sounds"
          description: root.mouseRunning
            ? "TypeTone is listening for button clicks"
            : "Play sounds for left, right, and middle clicks"
          checked: root.mouseEnabled
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          onClicked: if (root.wayvibesService) root.wayvibesService.toggleMouse()
        }

        Column {
          width: parent.width
          spacing: Style.spacing.labelGap

          Item {
            width: parent.width
            implicitHeight: Math.max(mouseDeviceLabel.implicitHeight, rescanMouseButton.implicitHeight)

            Text {
              id: mouseDeviceLabel
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Pointing device"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Button {
              id: rescanMouseButton
              anchors.right: parent.right
              text: root.wayvibesService && root.wayvibesService.mouseScanPending ? "Scanning…" : "Rescan"
              iconText: "󰑐"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              onClicked: if (root.wayvibesService) root.wayvibesService.rescanMouseDevices()
            }
          }

          Button {
            width: parent.width
            text: root.currentMouseDeviceLabel()
            iconText: root.mouseDevicePickerOpen ? "▴" : "▾"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            bordered: true
            selected: root.mouseDevicePickerOpen
            leftAlign: true
            onClicked: if (root.mouseDeviceOptions.length > 0) root.toggleMouseDevicePicker()
          }

          BorderSurface {
            width: parent.width
            height: root.mouseDevicePickerOpen ? root.mouseDevicePickerHeight : 0
            visible: root.mouseDevicePickerOpen
            clip: true
            color: Color.popups.background
            borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)
            radius: Style.cornerRadius

            ListView {
              id: mouseDeviceList
              anchors.fill: parent
              anchors.margins: Style.spacing.hairline
              clip: true
              spacing: Style.spacing.labelGap
              boundsBehavior: Flickable.StopAtBounds
              model: root.mouseDeviceOptions
              currentIndex: root.currentMouseDeviceIndex()

              delegate: Button {
                required property var modelData

                width: mouseDeviceList.width
                height: Style.spacing.popupRowHeight
                text: root.packLabel(modelData)
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                fontSize: Style.font.body
                leftAlign: true
                selected: root.wayvibesService
                  && root.packValue(modelData) === root.wayvibesService.mouseDeviceName
                onClicked: {
                  if (root.wayvibesService)
                    root.wayvibesService.setMouseDevice(root.packValue(modelData))
                  root.mouseDevicePickerOpen = false
                }
              }
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.spacing.labelGap

          Text {
            text: "Click style"
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Button {
            width: parent.width
            text: root.currentMousePackLabel()
            iconText: root.mousePackPickerOpen ? "▴" : "▾"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            bordered: true
            selected: root.mousePackPickerOpen
            leftAlign: true
            onClicked: root.toggleMousePackPicker()
          }

          BorderSurface {
            width: parent.width
            height: root.mousePackPickerOpen ? root.mousePackPickerHeight : 0
            visible: root.mousePackPickerOpen
            clip: true
            color: Color.popups.background
            borderSpec: Border.controlSpec("normal", root.bar.foreground, Color.accent)
            radius: Style.cornerRadius

            ListView {
              id: mousePackList
              anchors.fill: parent
              anchors.margins: Style.spacing.hairline
              clip: true
              spacing: Style.spacing.labelGap
              boundsBehavior: Flickable.StopAtBounds
              model: root.mousePackOptions
              currentIndex: root.currentMousePackIndex()

              delegate: Button {
                required property var modelData

                width: mousePackList.width
                height: Style.spacing.popupRowHeight
                text: root.packLabel(modelData)
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                fontSize: Style.font.body
                leftAlign: true
                selected: root.wayvibesService
                  && root.packValue(modelData) === root.wayvibesService.mousePack
                onClicked: {
                  if (root.wayvibesService) {
                    root.wayvibesService.setMousePack(root.packValue(modelData))
                    mouseVolumeSlider.liveValue = root.wayvibesService.mouseVolume
                  }
                  root.mousePackPickerOpen = false
                }
              }
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(4)

          Item {
            width: parent.width
            implicitHeight: Math.max(mouseVolumeLabel.implicitHeight, mouseVolumeValue.implicitHeight)

            Text {
              id: mouseVolumeLabel
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Mouse volume"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              id: mouseVolumeValue
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: Math.round((mouseVolumeSlider.dragging
                ? mouseVolumeSlider.liveValue
                : (root.wayvibesService ? root.wayvibesService.mouseVolume : 0.75)) * 100) + "%"
              color: Qt.darker(root.bar.foreground, 1.35)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          PanelSlider {
            id: mouseVolumeSlider
            bar: root.bar
            width: parent.width
            minimum: 0
            maximum: 3
            step: 0.05
            value: root.wayvibesService ? root.wayvibesService.mouseVolume : 0.75
            onMoved: function(value) {
              if (root.wayvibesService) root.wayvibesService.previewMouseVolume(value)
            }
            onReleased: function(value) {
              if (root.wayvibesService) root.wayvibesService.commitMouseVolume(value)
            }
          }
        }
      }

      Text {
        width: parent.width
        visible: root.wayvibesService && !root.wayvibesService.inputAccessMissing
          && text !== ""
        text: !root.wayvibesService ? ""
          : (root.settingsPage === "mouse"
            ? root.wayvibesService.mouseLastError
            : root.wayvibesService.lastError)
        color: Color.urgent
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Row {
        anchors.right: parent.right
        spacing: Style.space(6)

        Button {
          text: "Restart"
          iconText: "󰑐"
          foreground: root.bar.foreground
          bordered: true
          onClicked: if (root.wayvibesService) {
            if (root.settingsPage === "mouse") root.wayvibesService.restartMouse()
            else root.wayvibesService.restart()
          }
        }

        Button {
          text: "Close"
          foreground: root.bar.foreground
          onClicked: root.close()
        }
      }
    }
  }
}
