import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick.Effects

Item {
  id: root
  implicitWidth: pillBg.width
  implicitHeight: pillBg.height

  property int cascadeIndex: 1
  property bool playerExpanded: false

  // ── Parsed state ──────────────────────────────────────────────────
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
  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutBack } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  // ── Poll script every second ───────────────────────────────────────
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
      if (musicProc.running) musicProc.terminate()
      musicProc.running = true
    }
  }

  Process { id: seekProc }
  Process { id: ctlPrev;  command: ["playerctl", "previous"] }
  Process { id: ctlPlay;  command: ["playerctl", "play-pause"] }
  Process { id: ctlNext;  command: ["playerctl", "next"] }

  // ── Floating pill (bar widget) ──────────────────────────────────────
  Rectangle {
    id: pillBg
    height: 50
    width: barRow.implicitWidth + 24
    radius: 14
    color: pillHover.containsMouse || root.playerExpanded ? Qt.rgba(0.19, 0.19, 0.27, 0.85) : Qt.rgba(0.118, 0.118, 0.180, 0.75)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    anchors.verticalCenter: parent.verticalCenter

    scale: pillHover.containsMouse ? 1.03 : 1.0
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
    Behavior on color { ColorAnimation { duration: 200 } }
    Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

    MouseArea {
      id: pillHover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.playerExpanded = !root.playerExpanded
    }

    Row {
      id: barRow
      anchors.centerIn: parent
      spacing: 8
      height: 32

      // Cover thumbnail
      Rectangle {
        width: 32; height: 32; radius: 8
        color: "#313244"; border.color: "#45475a"; border.width: 1
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
          font.pixelSize: 16; color: "#45475a"
          visible: root.coverPath === ""
        }
      }

      // Info + mini progress
      Column {
        spacing: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 190

        Text {
          text: root.trackTitle
          color: "#cdd6f4"; font.pixelSize: 12; font.weight: Font.Bold
          elide: Text.ElideRight; width: parent.width
        }

        Text {
          text: root.trackArtist !== "" ? root.trackArtist : (root.trackStatus === "Stopped" ? "Nothing playing" : "")
          color: "#a6adc8"; font.pixelSize: 10
          elide: Text.ElideRight; width: parent.width
        }
      }

      // Mini prev/play/next
      Row {
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
          model: ["⏮", root.isPlaying ? "⏸" : "▶", "⏭"]

          Rectangle {
            id: miniBtn
            width: 22; height: 22; radius: 6
            property bool isHovered: miniMouse.containsMouse
            color: index === 1 && root.isPlaying ? "#89b4fa" : (isHovered ? "#313244" : "transparent")
            scale: isHovered ? 1.15 : 1.0
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
              anchors.centerIn: parent; text: modelData; font.pixelSize: 10
              color: index === 1 && root.isPlaying ? "#1e1e2e" : "#cdd6f4"
            }

            MouseArea {
              id: miniMouse
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
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

  // ── Popup — Overlay PanelWindow above the bar ─────────────────────────
  PanelWindow {
    id: popup
    visible: animOpacity > 0.01
    implicitWidth: 600
    implicitHeight: 285

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-music-popup"

    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"

    property real animOpacity: root.playerExpanded ? 1.0 : 0.0
    Behavior on animOpacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    MouseArea {
      anchors.fill: parent
      onClicked: root.playerExpanded = false
    }

    FocusScope {
      anchors.fill: parent
      focus: root.playerExpanded
      Keys.onEscapePressed: root.playerExpanded = false

    Rectangle {
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.topMargin: 70
      width: 600
      implicitHeight: 285
      height: implicitHeight
      color: "#1e1e2e"
      border.color: "#585b70"
      border.width: 2
      radius: 10

      opacity: popup.animOpacity
      scale: 0.94 + 0.06 * popup.animOpacity
      transform: Translate { y: (1 - popup.animOpacity) * -10 }

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
          color: "#313244"
          border.color: "#45475a"
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
            color: "#45475a"
            visible: root.coverPath === ""
          }
        }

        // Right side: title block, then timeline, then timestamps,
        // then controls — that order, top to bottom
        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 216
          spacing: 0

          Column {
            width: parent.width
            spacing: 3

            Text {
              text: root.trackTitle
              color: "#cdd6f4"
              font.pixelSize: 15
              font.weight: Font.Bold
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.trackArtist
              color: "#a6adc8"
              font.pixelSize: 12
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.trackAlbum
              color: "#6c7086"
              font.pixelSize: 10
              elide: Text.ElideRight
              width: parent.width
              visible: root.trackAlbum !== ""
            }
          }

          Item { width: 1; height: 20 }

          // ── Timeline
          Item {
            id: progressTrack
            width: parent.width
            height: 16

            property bool dragging: false
            property real dragPct: root.progressPct
            readonly property real shownPct: dragging ? dragPct : root.progressPct

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width; height: 8; radius: 3; color: "#313244"

              Rectangle {
                id: fillBar
                width: parent.width * (progressTrack.shownPct / 100)
                height: parent.height; radius: 3; color: "#89b4fa"
                Behavior on width { enabled: !progressTrack.dragging; NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
              }
            }

            // drag handle knob bigger hit target, shows on hover/drag
            Rectangle {
              width: 13; height: 13; radius: 7
              color: "#cdd6f4"
              anchors.verticalCenter: parent.verticalCenter
              x: Math.max(0, Math.min(parent.width - width, parent.width * (progressTrack.shownPct / 100) - width / 2))
              visible: timelineArea.containsMouse || progressTrack.dragging
              scale: progressTrack.dragging ? 1.2 : 1.0
              Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            }

            MouseArea {
              id: timelineArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor

              function pctFromX(mx) {
                return Math.max(0, Math.min(100, (mx / width) * 100))
              }

              onPressed: (mouse) => {
                progressTrack.dragging = true
                progressTrack.dragPct = pctFromX(mouse.x)
              }
              onPositionChanged: (mouse) => {
                if (progressTrack.dragging) progressTrack.dragPct = pctFromX(mouse.x)
              }
              onReleased: (mouse) => {
                progressTrack.dragPct = pctFromX(mouse.x)
                if (root.lengthSec > 0) {
                  var target = (progressTrack.dragPct / 100) * root.lengthSec
                  seekProc.command = ["playerctl", "position", String(target)]
                  seekProc.running = true
                }
                progressTrack.dragging = false
              }
            }
          }

          // ── Timestamps under the timeline ──────────────────
          Row {
            width: parent.width

            Text {
              text: root.positionStr
              color: "#6c7086"; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
            }

            Item { width: parent.width - 50; height: 1 }

            Text {
              text: root.lengthStr
              color: "#6c7086"; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
            }
          }

          Item { width: 1; height: 16 }

          // ── Controls below the timestamps ─────────────────────────
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20

            Rectangle {
              id: prevBtn
              width: 44; height: 44; radius: 10
              property bool isHovered: prevMouse.containsMouse
              color: isHovered ? "#313244" : "transparent"
              scale: isHovered ? 1.1 : 1.0
              Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
              Behavior on color { ColorAnimation { duration: 150 } }
              Text { anchors.centerIn: parent; text: "⏮"; font.pixelSize: 26; color: "#cdd6f4" }
              MouseArea { id: prevMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ctlPrev.running = true }
            }

            Rectangle {
              id: playBtn
              width: 54; height: 54; radius: 27
              property bool isHovered: playMouse.containsMouse
              color: root.isPlaying ? "#89b4fa" : (isHovered ? "#313244" : "transparent")
              scale: isHovered ? 1.08 : 1.0
              Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
              Behavior on color { ColorAnimation { duration: 150 } }
              Text { anchors.centerIn: parent; text: root.isPlaying ? "⏸" : "▶"; font.pixelSize: 30; color: root.isPlaying ? "#1e1e2e" : "#cdd6f4" }
              MouseArea { id: playMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ctlPlay.running = true }
            }

            Rectangle {
              id: nextBtn
              width: 44; height: 44; radius: 10
              property bool isHovered: nextMouse.containsMouse
              color: isHovered ? "#313244" : "transparent"
              scale: isHovered ? 1.1 : 1.0
              Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
              Behavior on color { ColorAnimation { duration: 150 } }
              Text { anchors.centerIn: parent; text: "⏭"; font.pixelSize: 26; color: "#cdd6f4" }
              MouseArea { id: nextMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ctlNext.running = true }
            }
          }
        }
      }

      MouseArea { anchors.fill: parent }
    }
    }
  }
}
