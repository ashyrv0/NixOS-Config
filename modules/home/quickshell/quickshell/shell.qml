import QtQuick
import Quickshell
import "."

PanelWindow {
  id: barWindow
  anchors {
    top: true
    left: true
    right: true
  }

  implicitHeight: 48
  color: Theme.background

  // Left: Workspaces
  Workspaces {
    id: workspaces
    anchors {
      left: parent.left
      leftMargin: 12
      verticalCenter: parent.verticalCenter
    }
    height: parent.height
  }

  // Center: Music Player
  MusicPlayer {
    anchors {
      left: workspaces.right
      right: systemStats.left
      leftMargin: 16
      rightMargin: 16
      verticalCenter: parent.verticalCenter
    }
    height: parent.height
  }

  // Right: System Stats
  SystemStats {
    id: systemStats
    anchors {
      right: clock.left
      rightMargin: 16
      verticalCenter: parent.verticalCenter
    }
    height: parent.height
    width: implicitWidth
  }

  // Far right: Clock
  Clock {
    id: clock
    anchors {
      right: parent.right
      rightMargin: 12
      verticalCenter: parent.verticalCenter
    }
    height: parent.height
  }
}