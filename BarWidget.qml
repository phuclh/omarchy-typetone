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
  readonly property var packOptions: wayvibesService ? wayvibesService.packOptions : []
  readonly property int visiblePackRows: Math.min(packOptions.length, 8)
  readonly property real packPickerHeight: visiblePackRows * Style.spacing.popupRowHeight
    + Math.max(0, visiblePackRows - 1) * Style.spacing.labelGap
    + Style.spacing.hairline * 2
  property bool popupOpen: false
  property bool packPickerOpen: false

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

  function togglePackPicker() {
    root.packPickerOpen = !root.packPickerOpen
    if (root.packPickerOpen) {
      Qt.callLater(function() {
        packList.currentIndex = root.currentPackIndex()
        packList.positionViewAtIndex(packList.currentIndex, ListView.Center)
      })
    }
  }

  function close() {
    packPickerOpen = false
    popupOpen = false
  }

  onPopupOpenChanged: if (!popupOpen) packPickerOpen = false

  implicitWidth: content.implicitWidth + Style.space(14)
  implicitHeight: barSize

  Row {
    id: content
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "󰌌"
      color: root.soundsRunning
        ? root.bar.barForeground
        : Qt.darker(root.bar.barForeground, 1.7)
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.icon

      Behavior on color {
        enabled: !root.bar || root.bar.foregroundAnimationEnabled
        ColorAnimation { duration: 140 }
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.vertical
      text: root.soundsEnabled ? "TypeTone" : "TypeTone off"
      color: root.bar.barForeground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: function(mouse) {
      if (!root.wayvibesService) return
      if (mouse.button === Qt.RightButton) root.popupOpen = !root.popupOpen
      else root.wayvibesService.toggle()
    }

    onWheel: function(wheel) {
      if (!root.wayvibesService) return
      var delta = wheel.angleDelta.y > 0 ? 0.1 : -0.1
      root.wayvibesService.setVolume(root.wayvibesService.volume + delta)
    }

    onEntered: if (root.bar) root.bar.showTooltip(
      root,
      (root.soundsEnabled ? "Keyboard sounds on" : "Keyboard sounds off")
        + " · Left-click toggle · Right-click settings"
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
                if (root.wayvibesService)
                  root.wayvibesService.setPack(root.packValue(modelData))
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
          onReleased: function(value) {
            if (root.wayvibesService) root.wayvibesService.setVolume(value)
          }
        }
      }

      Text {
        width: parent.width
        visible: root.wayvibesService && root.wayvibesService.lastError !== ""
        text: root.wayvibesService ? root.wayvibesService.lastError : ""
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
          onClicked: if (root.wayvibesService) root.wayvibesService.restart()
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
