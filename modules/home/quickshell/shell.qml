import QtQuick
import Quickshell

// ── Main bar window ──────────────────────────────────────────────────────
// Window itself is invisible (transparent, no fill). Every widget you see
// draws its own floating pill background. That gap and round corner look
// come from margins here plus radius on each pill, not from this window.
PanelWindow {
  id: barWindow
  anchors {
    top: true
    left: true
    right: true
  }

  implicitHeight: 56
  margins {
    top: 10
    left: 10
    right: 10
  }
  exclusiveZone: implicitHeight + 8
  color: "transparent"

  // Left: Workspaces
  Workspaces {
    id: workspaces
    cascadeIndex: 0
    anchors {
      left: parent.left
      verticalCenter: parent.verticalCenter
    }
    height: parent.height
  }

  // Center: Music Player
  MusicPlayer {
    cascadeIndex: 1
    anchors {
      horizontalCenter: parent.horizontalCenter
      verticalCenter: parent.verticalCenter
    }
    height: parent.height
  }

  // Far right edge: Clock (with calendar popup)
  Clock {
    id: clock
    cascadeIndex: 1
    anchors {
      right: parent.right
      verticalCenter: parent.verticalCenter
    }
    height: parent.height
  }

  // Wifi + Volume — sits next to the clock
  SystemStats {
    id: systemStats
    cascadeIndex: 2
    anchors {
      right: clock.left
      rightMargin: 8
      verticalCenter: parent.verticalCenter
    }
    height: parent.height
  }

  // Keyboard layout (EN / JA / etc) — sits next to the wifi/volume pill
  Keyboard {
    id: keyboard
    cascadeIndex: 3
    anchors {
      right: systemStats.left
      rightMargin: 8
      verticalCenter: parent.verticalCenter
    }
    height: parent.height
  }

  // System Tray (apps like Spotify, Discord, etc) — sits next to the keyboard pill
  SystemTray {
    id: tray
    cascadeIndex: 4
    anchors {
      right: keyboard.left
      rightMargin: 8
      verticalCenter: parent.verticalCenter
    }
    height: parent.height
  }
}
