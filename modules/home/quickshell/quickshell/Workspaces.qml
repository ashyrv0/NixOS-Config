import QtQuick
import Quickshell
import Quickshell.Hyprland
import "."

Item {
  implicitWidth: row.implicitWidth

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 6

    Repeater {
      model: 6

      Rectangle {
        id: wsButton
        width: 32
        height: 32
        radius: 6

        property bool isFocused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === (index + 1)
        property bool isOccupied: {
          var list = Hyprland.workspaces.values;
          for (var i = 0; i < list.length; i++) {
            if (list[i].id === (index + 1)) return true;
          }
          return false;
        }

        color: isFocused  ? Theme.accent
             : isOccupied ? Theme.surface0
             :               Theme.background

        border.color: isFocused  ? Theme.accent
                    : isOccupied ? Theme.accentMuted
                    :              Theme.surface1
        border.width: 1
        opacity: isFocused ? 1.0 : isOccupied ? 0.6 : 0.3

        Text {
          anchors.centerIn: parent
          text: (index + 1).toString()
          color: isFocused  ? Theme.background
               : isOccupied ? Theme.accent
               :              Theme.textDim
          font.pixelSize: 13
          font.weight: Font.Bold
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: Hyprland.dispatch("workspace " + (index + 1))
        }
      }
    }
  }
}