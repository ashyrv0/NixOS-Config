
import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
  id: root
  implicitWidth: pillBg.width

  property int cascadeIndex: 0
  property int wsCount: 6
  property int pillH: 36
  property int step: pillH + 6

  implicitHeight: pillBg.height

  // ── Entrance: fade in + slide up, staggered by cascadeIndex ───────────
  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutBack } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  // ── Floating pill background ───────────────────────────────────────────
  Rectangle {
    id: pillBg
    height: 50
    width: wsLayout.implicitWidth + 20
    radius: 14
    color: Qt.rgba(0.118, 0.118, 0.180, 0.75)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    anchors.verticalCenter: parent.verticalCenter

    // sliding highlight that glides between workspace numbers instead of
    // each button just recoloring instantly
    Rectangle {
      id: activeHighlight
      y: (pillBg.height - root.pillH) / 2
      height: root.pillH
      radius: 10
      color: "#89b4fa"
      z: 0

      property int curIdx: focusedIndex()
      x: wsLayout.x + curIdx * root.step
      width: root.pillH

      Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
      Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
    }

    Row {
      id: wsLayout
      anchors.centerIn: parent
      spacing: 6

      Repeater {
        model: root.wsCount

        Rectangle {
          id: wsButton
          width: root.pillH
          height: root.pillH
          radius: 10
          color: "transparent"

          property bool isFocused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === (index + 1)
          property bool isOccupied: {
            var list = Hyprland.workspaces.values
            for (var i = 0; i < list.length; i++) {
              if (list[i].id === (index + 1)) return true
            }
            return false
          }
          property bool isHovered: wsMouse.containsMouse

          scale: isHovered && !isFocused ? 1.1 : 1.0
          Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

          Text {
            anchors.centerIn: parent
            text: (index + 1).toString()
            font.pixelSize: 13
            font.weight: wsButton.isFocused ? Font.Black : (wsButton.isOccupied ? Font.Bold : Font.Normal)
            color: wsButton.isFocused  ? "#1e1e2e"
                 : wsButton.isHovered  ? "#cdd6f4"
                 : wsButton.isOccupied ? "#89b4fa"
                 :                       "#585b70"
            Behavior on color { ColorAnimation { duration: 200 } }
          }

          MouseArea {
            id: wsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Hyprland.dispatch("workspace " + (index + 1))
          }
        }
      }
    }
  }

  function focusedIndex() {
    if (!Hyprland.focusedWorkspace) return 0
    return Hyprland.focusedWorkspace.id - 1
  }
}
