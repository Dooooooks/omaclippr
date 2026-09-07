import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Omaclippr bar widget + popout panel.
//
// The bar button is a status pill: a filled dot while buffering, an outline
// while idle. Left-click toggles the panel, middle-click toggles the buffer
// directly, so a clip flow works without ever opening the panel.
//
// The actual capture daemon and its state live on the shell-wide service
// (Service.qml); this widget only binds to it and calls its commands, so one
// daemon runs regardless of how many monitors the bar is on.
Panel {
  id: root
  moduleName: "dooooooks.omaclippr"
  ipcTarget: "dooooooks.omaclippr"

  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ------------------------------------------------------------- service
  property var buffer: null

  function bindService() {
    if (buffer) return
    var host = bar && bar.shell ? bar.shell : null
    if (!host || typeof host.serviceFor !== "function") return
    buffer = host.serviceFor("dooooooks.omaclippr")
  }

  onBarChanged: bindService()
  Component.onCompleted: bindService()

  Timer {
    interval: 250
    running: root.buffer === null
    repeat: true
    onTriggered: root.bindService()
  }

  // ------------------------------------------------------------- state
  readonly property bool active: buffer ? buffer.active : false
  readonly property int duration: buffer ? buffer.duration : setting("defaultDuration", 60)
  readonly property string quality: buffer ? buffer.quality : setting("defaultQuality", "balanced")
  readonly property var clips: buffer ? buffer.clips : []

  readonly property var allowedDurations: [30, 60, 120]
  readonly property var allowedQualities: ["low", "balanced", "high"]

  function start() {
    if (buffer) buffer.start()
  }
  function stop() {
    if (buffer) buffer.stop()
  }
  function toggleBuffer() {
    if (buffer) buffer.toggle()
  }
  function clipNow() {
    if (buffer) buffer.clip("")
  }
  function editClip(path) {
    Quickshell.execDetached(["omacut", String(path)])
  }
  function deleteClip(path) {
    if (buffer) buffer.deleteClip(path)
  }

  function setDuration(sec) {
    if (!buffer || buffer.active) return
    buffer.setDuration(sec)
  }
  function setQuality(q) {
    if (!buffer || buffer.active) return
    buffer.setQuality(q)
  }

  // ------------------------------------------------------------- formatting
  function clipName(path) {
    var base = String(path || "")
    var i = base.lastIndexOf("/")
    return i >= 0 ? base.substring(i + 1) : base
  }
  function clipTime(ts) {
    var t = Number(ts || 0)
    if (!t) return ""
    return Qt.formatDateTime(new Date(t * 1000), "MMM d · HH:mm")
  }

  // ------------------------------------------------------------- bar button
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    hasVisualContent: true
    active: root.active
    tooltipText: root.active
      ? "Clipping · " + root.duration + "s · " + root.quality
      : "Instant replay off"

    // A plain circle that recolours with state instead of a glyph.
    Rectangle {
      id: dot
      anchors.centerIn: parent
      width: button.height * 0.36
      height: width
      radius: width / 2
      color: root.active ? Color.accent : root.foreground
      Behavior on color { ColorAnimation { duration: 150 } }
    }

    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.toggleBuffer()
      else root.toggle()
    }
  }

  // ------------------------------------------------------------- popout panel
  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(360))
    contentHeight: popup.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {}

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.space(12)

        // ------------------------------------------------------ hero
        Item {
          id: hero
          width: parent.width
          height: Math.max(heroTitle.implicitHeight, powerSwitch.implicitHeight)

          Column {
            id: heroLabels
            anchors.left: parent.left
            anchors.right: powerSwitch.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              id: heroTitle
              text: "INSTANT REPLAY"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }
            Text {
              textFormat: Text.PlainText
              text: root.active
                ? ("Buffering " + root.duration + "s · " + root.quality).toUpperCase()
                : "OFF".toUpperCase()
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.1
              elide: Text.ElideRight
              width: parent.width
            }
          }

          ToggleSwitch {
            id: powerSwitch
            checked: root.active
            foreground: root.foreground
            accent: Color.accent
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            onToggled: root.toggleBuffer()
          }
        }

        // ------------------------------------------------------ clip now
        Button {
          width: parent.width
          text: root.active ? "Clip Now" : "Clip Now"
          foreground: root.foreground
          accent: Color.accent
          enabled: root.active
          bordered: true
          iconText: "\uF03D"
          tooltipText: root.active ? "Save the buffered " + root.duration + "s" : "Start the buffer first"
          onClicked: root.clipNow()
        }

        // ------------------------------------------------------ duration
        Column {
          width: parent.width
          spacing: Style.space(6)
          opacity: root.active ? 0.45 : 1.0
          Behavior on opacity { NumberAnimation { duration: 140 } }

          PanelSectionHeader {
            text: "REPLAY LENGTH"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(6)
            Repeater {
              model: root.allowedDurations
              delegate: Button {
                required property var modelData
                text: modelData + "s"
                foreground: root.foreground
                accent: Color.accent
                selected: modelData === root.duration
                width: (parent.width - Style.space(6) * (root.allowedDurations.length - 1))
                       / root.allowedDurations.length
                onClicked: if (!root.active) root.setDuration(modelData)
              }
            }
          }
        }

        // ------------------------------------------------------ quality
        Column {
          width: parent.width
          spacing: Style.space(6)
          opacity: root.active ? 0.45 : 1.0
          Behavior on opacity { NumberAnimation { duration: 140 } }

          PanelSectionHeader {
            text: "QUALITY"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(6)
            Repeater {
              model: root.allowedQualities
              delegate: Button {
                required property var modelData
                readonly property string shown: {
                  if (modelData === "low") return "Low"
                  if (modelData === "balanced") return "Balanced"
                  return "High"
                }
                text: shown
                foreground: root.foreground
                accent: Color.accent
                selected: modelData === root.quality
                width: (parent.width - Style.space(6) * (root.allowedQualities.length - 1))
                       / root.allowedQualities.length
                onClicked: if (!root.active) root.setQuality(modelData)
              }
            }
          }
        }

        // ------------------------------------------------------ clips shelf
        PanelSectionHeader {
          text: "RECENT CLIPS"
          foreground: root.foreground
          fontFamily: root.fontFamily
          visible: root.clips.length > 0
        }

        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: root.clips.length > 0
          Repeater {
            model: root.clips
            delegate: Row {
              required property var modelData
              property bool armed: false

              width: parent.width
              height: clipText.implicitHeight + Style.space(8)
              spacing: Style.space(4)

              Text {
                id: clipText
                textFormat: Text.PlainText
                text: root.clipName(modelData.path)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideMiddle
                width: parent.width
                       - playBtn.width - editBtn.width - folderBtn.width
                       - pathBtn.width - deleteBtn.width
                       - Style.space(4) * 5
                anchors.verticalCenter: parent.verticalCenter
              }

              Button {
                id: playBtn
                iconText: "\uF04B"
                foreground: root.foreground
                tooltipText: "Play"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: Quickshell.execDetached(["xdg-open", String(modelData.path)])
              }
              Button {
                id: editBtn
                iconText: "\uF0C4"
                foreground: root.foreground
                tooltipText: "Edit in Omacut"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.editClip(String(modelData.path))
              }
              Button {
                id: folderBtn
                iconText: "\uF07B"
                foreground: root.foreground
                tooltipText: "Open folder"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                  var p = String(modelData.path)
                  var i = p.lastIndexOf("/")
                  var dir = i >= 0 ? p.substring(0, i) : p
                  Quickshell.execDetached(["xdg-open", dir])
                }
              }
              Button {
                id: pathBtn
                iconText: "\uF0C5"
                foreground: root.foreground
                tooltipText: "Copy path"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: Quickshell.execDetached(["wl-copy", String(modelData.path)])
              }
              Button {
                id: deleteBtn
                iconText: armed ? "\uF00D" : "\uF1F8"
                foreground: armed ? Color.accent : root.foreground
                tooltipText: armed ? "Click again to delete" : "Delete"
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                  if (armed) {
                    armed = false
                    root.deleteClip(String(modelData.path))
                  } else {
                    armed = true
                    disarmTimer.restart()
                  }
                }
              }

              Timer {
                id: disarmTimer
                interval: 3000
                onTriggered: armed = false
              }
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          topPadding: Style.space(10)
          visible: root.clips.length === 0
          text: "No clips yet"
          wrapMode: Text.WordWrap
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          color: root.foreground
          opacity: 0.5
        }
      }
    }
  }
}
