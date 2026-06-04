import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick.Effects
import "."

Item {
  id: root
  property bool playerExpanded: false

  // ── Parsed state ──────────────────────────────────────────
  property string trackTitle:    "Not Playing"
  property string trackArtist:   ""
  property string trackAlbum:    ""
  property string trackStatus:   "Stopped"
  property int    positionSec:   0
  property int    lengthSec:     0
  property int    progressPct:   0
  property string positionStr:   "0:00"
  property string lengthStr:     "0:00"
  property string coverPath:     ""
  property string playerName:    ""

  property bool isPlaying: trackStatus === "Playing"

  // ── Poll script every second ──────────────────────────────────────────
Process {
    id: musicProc
    command: ["bash", "-c", "$HOME/.config/quickshell/music_info.sh"]

    stdout: StdioCollector {
      onStreamFinished: {
        if (!this.text) return

        try {
          const d = JSON.parse(this.text.trim())

          root.trackTitle = d.title || "Not Playing"
          root.trackArtist = d.artist || ""
          root.trackAlbum = d.album || ""
          root.trackStatus = d.status || "Stopped"
          root.positionSec = d.position_seconds || 0
          root.lengthSec = d.length_seconds || 0
          root.progressPct = d.progress || 0
          root.positionStr = d.position_str || "0:00"
          root.lengthStr = d.length_str || "0:00"
          root.coverPath = d.cover || ""
          root.playerName = d.player || ""
        } catch (e) {
          console.warn("music parse error", e)
        }
      }
    }
  }


Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: {
      if (musicProc.running) {
        musicProc.terminate();
      }
      musicProc.running = true;
    }
  }

  // ── Seek process (separate so it doesn't conflict with poll) ─────────
  Process { id: seekProc }
  // ── Helper: control via playerctl ────────────────────────────────────
  Process { id: ctlPrev;  command: ["playerctl", "previous"] }
  Process { id: ctlPlay;  command: ["playerctl", "play-pause"] }
  Process { id: ctlNext;  command: ["playerctl", "next"] }

  // ── Popup — Overlay PanelWindow above the bar ─────────────────────────
  PanelWindow {
    id: popup
    visible: root.playerExpanded
    implicitWidth: 600
    implicitHeight: 285

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-music-popup"

    anchors.top: true
    margins.top: 58
    color: "transparent"

    Rectangle {
      anchors.fill: parent
      color: Theme.background
      border.color: Theme.textDim
      border.width: 2
      radius: 10

      Row {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 16

        // Cover art (left)
        Rectangle {
          width: 200
          height: 200
          anchors.verticalCenter: parent.verticalCenter
          radius: 13
          color: Theme.surface0
          border.color: Theme.surface1
          border.width: 1

          Image {
            id: coverImg
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            source: root.coverPath !== "" ? ("file://" + root.coverPath) : ""
            mipmap: true
            visible: false
          }

          Rectangle {
            id: coverMask
            anchors.fill: parent
            radius: 13
            visible: false
            layer.enabled: true
          }

          MultiEffect {
            source: coverImg
            anchors.fill: parent
            maskEnabled: true
            maskSource: coverMask
            visible: root.coverPath !== ""
          }

          Text {
            anchors.centerIn: parent
            text: "♪"
            font.pixelSize: 64
            color: Theme.surface1
            visible: root.coverPath === ""
          }
        }

        // Right side: title/artist top, controls middle, progress bottom
        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 216
          spacing: 0

          // Title + artist
          Column {
            width: parent.width
            spacing: 3

            Text {
              text: root.trackTitle
              color: Theme.text
              font.pixelSize: 15
              font.weight: Font.Bold
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.trackArtist
              color: Theme.textMuted
              font.pixelSize: 12
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.trackAlbum
              color: Theme.textDim
              font.pixelSize: 10
              elide: Text.ElideRight
              width: parent.width
              visible: root.trackAlbum !== ""
            }
          }

          Item { width: 1; height: 20 }

          // Controls

          Item { width: 1; height: 20 }

          // Progress bar + timestamps
          Column {
            width: parent.width
            spacing: 6

            Rectangle {
              width: parent.width; height: 9; radius: 3; color: Theme.surface0

              Rectangle {
                width: parent.width * (root.progressPct / 100)
                height: parent.height; radius: 2; color: Theme.accent
                Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (root.lengthSec > 0) {
                    var target = (mouse.x / width) * root.lengthSec
                    seekProc.command = ["playerctl", "position", String(target)]
                    seekProc.running = true
                  }
                }
              }
            }

            Row {
              width: parent.width

              Text {
                text: root.positionStr
                color: Theme.textDim; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
              }

              Item { width: parent.width - 50; height: 1 }

              Text {
                text: root.lengthStr
                color: Theme.textDim; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
              }
            }
                      Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20

            Rectangle {
              width: 44; height: 44; radius: 6; color: 'transparent'; border.color: 'transparent'
              Text { anchors.centerIn: parent; text: "⏮"; font.pixelSize: 30; color: Theme.text }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ctlPrev.running = true }
            }

            Rectangle {
              width: 54; height: 54; radius: 8; color: 'transparent'
              Text { anchors.centerIn: parent; text: root.isPlaying ? "" : ""; font.pixelSize: 42; color: Theme.text }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ctlPlay.running = true }
            }

            Rectangle {
              width: 44; height: 44; radius: 6; color: 'transparent'; border.color: 'transparent'
              Text { anchors.centerIn: parent; text: "⏭"; font.pixelSize: 30; color: Theme.text }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ctlNext.running = true }
            }
          }
          }
        }
      }
    }
  }

  // ── Bar inline widget ─────────────────────────────────────────────────
  Row {
    anchors.centerIn: parent
    spacing: 8
    height: parent.height

    // Cover thumbnail
    Rectangle {
      width: 32; height: 32; radius: 4
      color: Theme.surface0; border.color: Theme.surface1; border.width: 1
      anchors.verticalCenter: parent.verticalCenter
      clip: true

      Image {
        anchors.fill: parent
        source: root.coverPath !== "" ? ("file://" + root.coverPath) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: root.coverPath !== ""
      }

      Text {
        anchors.centerIn: parent; text: "♪"
        font.pixelSize: 16; color: Theme.surface1
        visible: root.coverPath === ""
      }
    }

    // Info + mini controls
    Column {
      spacing: 1
      anchors.verticalCenter: parent.verticalCenter
      width: 200

      // Title — click to open popup
      Text {
        text: root.trackTitle
        color: Theme.text; font.pixelSize: 12; font.weight: Font.Bold
        elide: Text.ElideRight; width: parent.width

        MouseArea {
          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
          onClicked: root.playerExpanded = !root.playerExpanded
        }
      }

      Text {
        text: root.trackArtist !== "" ? root.trackArtist : (root.trackStatus === "Stopped" ? "Nothing playing" : "")
        color: Theme.textMuted; font.pixelSize: 10
        elide: Text.ElideRight; width: parent.width
      }

      // Mini progress bar
      Rectangle {
        width: parent.width; height: 2; radius: 1; color: Theme.surface0
        visible: root.trackStatus !== "Stopped"

        Rectangle {
          width: parent.width * (root.progressPct / 100)
          height: parent.height; radius: 1; color: Theme.accent
          Behavior on width { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
        }
      }
    }

    // Mini prev/play/next buttons
    Row {
      spacing: 6
      anchors.verticalCenter: parent.verticalCenter

      Repeater {
        model: ["⏮", root.isPlaying ? "" : "", "⏭"]

        Rectangle {
          width: 22; height: 22; radius: 3
          color: index === 1 && root.isPlaying ? Theme.accent : 'transparent'

          Text {
            anchors.centerIn: parent; text: modelData; font.pixelSize: 10
            color: index === 1 && root.isPlaying ? Theme.background : Theme.text
          }

          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (index === 0) ctlPrev.running = true
              else if (index === 1) ctlPlay.running = true
              else ctlNext.running = true
            }
          }
        }
      }
    }
  }
}