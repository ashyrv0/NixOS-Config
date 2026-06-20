import QtQuick
import Quickshell.Io

Item {
  id: root
  implicitWidth: pillBg.width
  implicitHeight: pillBg.height

  property int cascadeIndex: 2
  property string layoutFull: "English (US)"
  property string layoutShort: {
    var first = layoutFull.split(" ")[0]
    return first.length >= 2 ? first.substring(0, 2).toUpperCase() : "??"
  }

  // ── Entrance ────────────────────────────────────────────────────────
  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutBack } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  Process {
    id: kbProc
    command: ["bash", "-c", "$HOME/.config/quickshell/kb_layout.sh"]
    stdout: StdioCollector {
      onStreamFinished: {
        var t = this.text.trim()
        if (t !== "") root.layoutFull = t
      }
    }
  }

  Process { id: switchProc; command: ["hyprctl", "switchxkblayout", "main", "next"] }

  Timer {
    interval: 1000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: { if (kbProc.running) kbProc.terminate(); kbProc.running = true }
  }

  Rectangle {
    id: pillBg
    height: 50
    width: kbLabel.implicitWidth + 24
    radius: 14
    color: pillMouse.containsMouse ? Qt.rgba(0.19, 0.19, 0.27, 0.85) : Qt.rgba(0.118, 0.118, 0.180, 0.75)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    anchors.verticalCenter: parent.verticalCenter

    scale: pillMouse.containsMouse ? 1.05 : 1.0
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }

    Text {
      id: kbLabel
      anchors.centerIn: parent
      text: root.layoutShort
      color: "#cdd6f4"
      font.pixelSize: 13
      font.weight: Font.Black
      font.family: "JetBrainsMono Nerd Font"
    }

    MouseArea {
      id: pillMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: switchProc.running = true
    }
  }
}
