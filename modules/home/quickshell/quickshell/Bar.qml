import QtQuick
import Quickshell
import Quickshell.Io

PanelWindow {
  id: barWindow
  anchors {
    top: true
    left: true
    right: true
  }

  height: 48
  color: Theme.background

  Row {
    anchors.fill: parent
    anchors.margins: 8
    spacing: 16

    Workspaces {
      height: parent.height
      width: 200
    }

    MusicPlayer {
      height: parent.height
      Layout.fillWidth: true
    }

    SystemStats {
      height: parent.height
      width: 180
    }

    Calendar {
      height: parent.height
      width: 80
    }

    Clock {
      height: parent.height
      width: 155
    }
  }
}