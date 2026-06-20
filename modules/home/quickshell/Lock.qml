import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
  id: root

  property string userName: "User"

  // ── shared lock state across every monitor ───────────────────────────
  QtObject {
    id: lockState
    property bool inputActive: false
    property bool authenticating: false
    property bool failed: false
    property string statusText: "Locked"
  }

  Timer {
    id: pamStartTimer
    interval: 50
    onTriggered: pam.start()
  }

  PamContext {
    id: pam
    Component.onCompleted: pamStartTimer.start()

    onCompleted: (result) => {
      lockState.authenticating = false
      if (result === PamResult.Success) {
        lockRoot.locked = false
        Qt.quit()
      } else {
        lockState.failed = true
        lockState.statusText = "Wrong password"
        pamStartTimer.start()
      }
    }
  }

  Process {
    id: userProc
    command: ["whoami"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.userName = this.text.trim() || "User"
    }
  }

  WlSessionLock {
    id: lockRoot
    locked: true

    WlSessionLockSurface {
      id: lockSurface

      // ── point this at your real wallpaper file ─────────────────────
      property string wallpaperPath: "file://" + Quickshell.env("HOME") + "/.config/hypr/wallpapers/s-b-vonlanthen-A8iLzX6OddM.jpg"

      // ── background: blurred + dimmed wallpaper ─────────────────────
      Image {
        id: bgImage
        anchors.fill: parent
        source: lockSurface.wallpaperPath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        visible: false
      }

      MultiEffect {
        source: bgImage
        anchors.fill: parent
        blurEnabled: true
        blur: 1.0
        blurMax: 64
      }

      Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: lockState.inputActive ? 0.45 : 0.25
        Behavior on opacity { NumberAnimation { duration: 400 } }
      }

      // ── click anywhere reveals the password box ────────────────────
      MouseArea {
        anchors.fill: parent
        onClicked: {
          lockState.inputActive = true
          pinField.forceActiveFocus()
        }
      }

      // ── any keypress also reveals it (catch-all under everything) ──
      Item {
        anchors.fill: parent
        focus: !lockState.inputActive
        Keys.onPressed: (event) => {
          lockState.inputActive = true
          pinField.forceActiveFocus()
        }
      }

      // ── IDLE: big clock ───────────────────────────────────────────
      ColumnLayout {
        id: clockBlock
        anchors.centerIn: parent
        anchors.verticalCenterOffset: lockState.inputActive ? -130 : -30
        spacing: -6

        opacity: lockState.inputActive ? 0 : 1
        scale: lockState.inputActive ? 0.9 : 1.0
        visible: opacity > 0.01

        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 550; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }

        Text {
          id: bigClock
          Layout.alignment: Qt.AlignHCenter
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 130
          font.weight: Font.Bold
          color: "#cdd6f4"
        }

        Text {
          id: bigDate
          Layout.alignment: Qt.AlignHCenter
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 20
          font.weight: Font.Medium
          color: "#a6adc8"
        }

        Timer {
          interval: 1000; running: true; repeat: true; triggeredOnStart: true
          onTriggered: {
            const d = new Date()
            bigClock.text = Qt.formatDateTime(d, "hh:mm")
            bigDate.text = Qt.formatDateTime(d, "dddd, MMMM d")
          }
        }
      }

      // ── REVEALED: welcome back + pin entry ──────────────────────────
      ColumnLayout {
        id: authBlock
        anchors.centerIn: parent
        anchors.verticalCenterOffset: lockState.inputActive ? -10 : 90
        spacing: 18

        opacity: lockState.inputActive ? 1 : 0
        scale: lockState.inputActive ? 1.0 : 0.9
        visible: opacity > 0.01

        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 550; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 450; easing.type: Easing.OutBack } }

        // avatar circle
        Rectangle {
          Layout.alignment: Qt.AlignHCenter
          width: 84; height: 84; radius: 42
          color: "#313244"
          border.width: 2
          border.color: lockState.failed ? "#f38ba8" : (lockState.authenticating ? "#fab387" : "#89b4fa")
          Behavior on border.color { ColorAnimation { duration: 250 } }

          Text {
            anchors.centerIn: parent
            text: root.userName.charAt(0).toUpperCase()
            font.pixelSize: 36
            font.weight: Font.Bold
            color: "#cdd6f4"
          }
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: "Welcome back, " + root.userName
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 22
          font.weight: Font.Bold
          color: "#cdd6f4"
        }

        Text {
          Layout.alignment: Qt.AlignHCenter
          text: lockState.failed ? "Wrong password — try again" : (lockState.authenticating ? "Checking..." : "Enter your password")
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 13
          color: lockState.failed ? "#f38ba8" : "#a6adc8"
          Behavior on color { ColorAnimation { duration: 200 } }
        }

        // pin pill
        Rectangle {
          id: pinPill
          Layout.alignment: Qt.AlignHCenter
          width: 280; height: 54; radius: 27
          clip: true

          color: lockState.failed ? Qt.rgba(0.95, 0.55, 0.66, 0.12) : Qt.rgba(0.19, 0.19, 0.27, 0.7)
          border.width: 2
          border.color: lockState.failed ? "#f38ba8"
                      : lockState.authenticating ? "#fab387"
                      : pinField.text.length > 0 ? "#89b4fa"
                      : Qt.rgba(1, 1, 1, 0.08)

          Behavior on color { ColorAnimation { duration: 200 } }
          Behavior on border.color { ColorAnimation { duration: 200 } }

          transform: Translate { id: shakeT; x: 0 }
          SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: shakeT; property: "x"; from: 0; to: -10; duration: 90 }
            NumberAnimation { target: shakeT; property: "x"; from: -10; to: 10; duration: 90 }
            NumberAnimation { target: shakeT; property: "x"; from: 10; to: -6; duration: 90 }
            NumberAnimation { target: shakeT; property: "x"; from: -6; to: 0; duration: 90 }
          }
          Connections {
            target: lockState
            function onFailedChanged() { if (lockState.failed) shakeAnim.restart() }
          }

          Row {
            anchors.centerIn: parent
            spacing: 10
            Repeater {
              model: pinField.text.length
              Rectangle {
                width: 10; height: 10; radius: 5
                color: lockState.failed ? "#f38ba8" : "#cdd6f4"
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          // placeholder — only visible when no dots are showing
          Text {
            anchors.centerIn: parent
            text: "Password"
            color: Qt.rgba(1, 1, 1, 0.3)
            font.pixelSize: 14
            font.family: "JetBrainsMono Nerd Font"
            visible: pinField.text.length === 0
          }

          TextInput {
            id: pinField
            anchors.fill: parent
            opacity: 0
            echoMode: TextInput.Password
            enabled: lockState.inputActive

            onTextChanged: lockState.failed = false

            Keys.onEscapePressed: {
              lockState.inputActive = false
              text = ""
            }

            onAccepted: {
              if (text.length > 0 && pam.responseRequired && !lockState.authenticating) {
                lockState.authenticating = true
                lockState.statusText = "Authenticating"
                lockState.failed = false
                pam.respond(text)
                text = ""
              }
            }
          }
        }
      }
    }
  }
}
