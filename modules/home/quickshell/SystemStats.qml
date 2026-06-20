import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
  id: root
  implicitWidth: barRow.implicitWidth + 20

  // ── State ──────────────────────────────────────────────────────────────
  property bool   networkMenuOpen: false
  property bool   volumeMenuOpen:  false
  property int    volumeLevel:  0
  property string volumeIcon:   "󰝟"
  property string sinkName:     ""
  property string wifiName:     "..."
  property var    wifiNetworks: []
  property var    btDevices:    []
  property string activeTab:    "wifi"
  property bool   wifiPowered:  true
  property bool   btPowered:    false

  property bool   showPasswordPrompt: false
  property string pendingSsid:   ""
  property string typedPassword: ""

  property bool   ethConnected: false
  property string ethName:      "enp5s0"

  property bool   muted:        false
  property bool   osdVisible:   false
  property bool   osdFirstRun:  true

  // ── Volume ──────────────────────────────────────────────────────────────
  Process {
    id: volProc
    command: ["bash", "-c",
      // volume level + icon
      "RAW=$(wpctl get-volume @DEFAULT_AUDIO_SINK@); " +
      "VOL=$(echo \"$RAW\" | awk '{print int($2*100)}'); " +
      "MUTEDCOUNT=$(echo \"$RAW\" | grep -c MUTED); " +
      "if [ \"$MUTEDCOUNT\" -gt 0 ]; then MUTED='true'; else MUTED='false'; fi; " +
      "if [ \"$MUTEDCOUNT\" -gt 0 ] || [ \"$VOL\" -eq 0 ]; then ICON='󰝟'; " +
      "elif [ \"$VOL\" -ge 70 ]; then ICON='󰕾'; " +
      "elif [ \"$VOL\" -ge 30 ]; then ICON='󰖀'; " +
      "else ICON='󰕿'; fi; " +
      // sink name
      "SINK=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep 'node.nick\\|node.description\\|node.name' | head -1 | sed 's/.*= \"\\(.*\\)\"/\\1/'); " +
      "[ -z \"$SINK\" ] && SINK='Audio Output'; " +
      "printf '{\"vol\":%d,\"icon\":\"%s\",\"sink\":\"%s\",\"muted\":%s}\\n' \"$VOL\" \"$ICON\" \"$SINK\" \"$MUTED\""
    ]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var d = JSON.parse(this.text.trim())

          // only flash the OSD when something actually changed, and skip
          // the very first read so it doesn't pop on startup
          var changed = d.vol !== root.volumeLevel || d.muted !== root.muted
          if (!root.osdFirstRun && changed && !root.volumeMenuOpen) {
            root.osdVisible = true
            osdHideTimer.restart()
          }
          root.osdFirstRun = false

          root.volumeLevel = d.vol
          root.volumeIcon  = d.icon
          root.sinkName    = d.sink || "Audio Output"
          root.muted       = d.muted === true
        } catch(e) {}
      }
    }
  }
  Timer {
    interval: 1000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: { if (volProc.running) volProc.terminate(); volProc.running = true }
  }

  Timer { id: osdHideTimer; interval: 1200; onTriggered: root.osdVisible = false }

  Process { id: volSetProc }
  Process { id: muteToggleProc; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }

  function setVolume(pct) {
    var clamped = Math.max(0, Math.min(150, pct))
    volSetProc.command = ["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (clamped / 100).toFixed(2)]
    volSetProc.running = true
    root.volumeLevel = clamped
    if (!root.volumeMenuOpen) {
      root.osdVisible = true
      osdHideTimer.restart()
    }
  }

  // ── WiFi name (bar label) ───────────────────────────────────────────────
  Process {
    id: wifiNameProc
    command: ["bash", "-c", "$HOME/.config/quickshell/wifi_info.sh name"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var s = this.text.trim()
        root.wifiName = s !== "" ? s : "Disconnected"
      }
    }
  }
  Timer {
    interval: 4000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: { if (wifiNameProc.running) wifiNameProc.terminate(); wifiNameProc.running = true }
  }

  // ── WiFi list (popup) ───────────────────────────────────────────────────
  Process {
    id: wifiListProc
    command: ["bash", "-c", "$HOME/.config/quickshell/wifi_info.sh"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var raw = this.text.trim()
          if (raw === "") return
          var d = JSON.parse(raw)
          root.wifiPowered = d.power === "on"
          var nets = d.networks || []
          if (d.connected && d.connected.ssid) {
            root.wifiName = d.connected.ssid
            // mark connected network with active flag then prepend
            d.connected.active = "yes"
            nets = [d.connected].concat(nets.filter(function(n) { return n.ssid !== d.connected.ssid }))
          }
          root.wifiNetworks = nets
        } catch(e) { console.warn("wifiListProc parse error:", e) }
      }
    }
  }

  // ── BT list ─────────────────────────────────────────────────────────────
  Process {
    id: btListProc
    command: ["bash", "-c", "$HOME/.config/quickshell/Bluetooth.sh"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var raw = this.text.trim()
        if (raw === "") { root.btDevices = []; return }
        try {
          var d = JSON.parse(raw)
          root.btPowered = d.powered === "yes"
          if (d.powered !== "yes") { root.btDevices = []; return }
          var devs = d.devices.map(function(dev) {
            return { connected: dev.state === "connected" ? 1 : 0, mac: dev.mac, name: dev.name }
          })
          root.btDevices = devs
        } catch(e) { root.btDevices = [] }
      }
    }
  }

  // ── Processes ───────────────────────────────────────────────────────────
  Process { id: connectWifiProc }
  Process { id: btConnectProc }
  Process { id: wifiToggleProc }
  Process { id: btToggleProc }
  Process {
    id: wifiRescanProc
    command: ["bash", "-c", "nmcli dev wifi rescan 2>/dev/null; sleep 1"]
    onRunningChanged: {
      if (!running) {
        if (wifiListProc.running) wifiListProc.terminate()
        wifiListProc.running = true
      }
    }
  }

  onNetworkMenuOpenChanged: {
    if (networkMenuOpen) {
      root.activeTab          = "wifi"
      root.wifiNetworks       = []
      root.btDevices          = []
      root.showPasswordPrompt = false
      root.pendingSsid        = ""
      root.typedPassword      = ""
      if (wifiListProc.running) wifiListProc.terminate()
      wifiListProc.running  = true
      if (btListProc.running) btListProc.terminate()
      btListProc.running    = true
    }
  }

  // ── Volume OSD  ──────────────
  PanelWindow {
    id: volOsd
    visible: osdAnim > 0.01
    color: "transparent"
    implicitWidth: 220
    implicitHeight: 110

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-volume-osd"

    anchors.bottom: true
    margins.bottom: 80

    property real osdAnim: root.osdVisible ? 1.0 : 0.0
    Behavior on osdAnim { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    Rectangle {
      anchors.centerIn: parent
      width: 188
      height: 96
      radius: 26
      color: root.muted ? Qt.rgba(0.16, 0.18, 0.24, 0.92) : Qt.rgba(0.118, 0.118, 0.180, 0.88)
      border.color: Qt.rgba(1, 1, 1, 0.08)
      border.width: 1

      opacity: volOsd.osdAnim
      scale: 0.85 + 0.15 * volOsd.osdAnim
      transform: Translate { y: (1 - volOsd.osdAnim) * -8 }

      Column {
        anchors.centerIn: parent
        spacing: 10

        Text {
          text: root.muted ? "󰝟" : root.volumeIcon
          font.pixelSize: 30
          color: root.muted ? "#a6adc8" : "#89b4fa"
          anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
          width: 130; height: 6; radius: 3; color: "#313244"
          anchors.horizontalCenter: parent.horizontalCenter

          Rectangle {
            width: parent.width * (root.muted ? 0 : Math.min(root.volumeLevel, 100) / 100)
            height: parent.height; radius: 3
            color: root.volumeLevel > 100 ? "#fab387" : "#89b4fa"
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
          }
        }
      }
    }
  }

  // ── Volume popup ────────────────────────────────────────────────────────
  PanelWindow {
    id: volPopup
    visible: root.volumeMenuOpen
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-volume-popup"

    anchors { top: true; left: true; right: true; bottom: true }

    MouseArea {
      anchors.fill: parent
      onClicked: root.volumeMenuOpen = false
    }

    FocusScope {
      anchors.fill: parent
      focus: root.volumeMenuOpen
      Keys.onEscapePressed: root.volumeMenuOpen = false

      Rectangle {
        id: volCard
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 70
        anchors.rightMargin: 54
        width: 280
        height: volCardCol.implicitHeight + 28
        radius: 10
        color: "#1e1e2e"
        border.color: "#585b70"
        border.width: 2

        // swallow clicks so they don't reach the close MouseArea behind
        MouseArea { anchors.fill: parent }

        Column {
          id: volCardCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: 16
          spacing: 14

          // Sink name + icon
          Row {
            width: parent.width
            spacing: 10

            Text {
              text: root.volumeIcon
              font.pixelSize: 20
              color: "#89b4fa"
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 1

              Text {
                text: root.sinkName
                color: "#cdd6f4"
                font.pixelSize: 12
                font.weight: Font.Bold
                elide: Text.ElideRight
                width: 220
              }

              Text {
                text: root.volumeLevel + "%"
                color: "#a6adc8"
                font.pixelSize: 10
                font.family: "JetBrainsMono Nerd Font"
              }
            }
          }

          // Draggable volume slider
          Item {
            id: volTrack
            width: parent.width
            height: 20

            property bool dragging: false

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width; height: 6; radius: 3; color: "#313244"

              Rectangle {
                width: parent.width * Math.min(root.volumeLevel, 100) / 100
                height: parent.height; radius: 3
                color: root.volumeLevel > 100 ? "#fab387" : "#89b4fa"
                Behavior on width { enabled: !volTrack.dragging; NumberAnimation { duration: 200 } }
              }
            }

            // knob
            Rectangle {
              width: 14; height: 14; radius: 7
              color: "#cdd6f4"
              anchors.verticalCenter: parent.verticalCenter
              x: Math.max(0, Math.min(parent.width - width, parent.width * Math.min(root.volumeLevel, 100) / 100 - width / 2))
              scale: volTrack.dragging || volSliderArea.containsMouse ? 1.2 : 1.0
              Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            }

            MouseArea {
              id: volSliderArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor

              function pctFromX(mx) {
                return Math.round(Math.max(0, Math.min(150, (mx / width) * 150)))
              }

              onPressed: (mouse) => {
                volTrack.dragging = true
                root.setVolume(pctFromX(mouse.x))
              }
              onPositionChanged: (mouse) => {
                if (volTrack.dragging) root.setVolume(pctFromX(mouse.x))
              }
              onReleased: (mouse) => {
                volTrack.dragging = false
              }
              onWheel: (wheel) => {
                root.setVolume(root.volumeLevel + (wheel.angleDelta.y > 0 ? 5 : -5))
              }
            }

            MouseArea {
              id: muteHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                muteToggleProc.running = true
                root.muted = !root.muted
                root.osdVisible = true
                osdHideTimer.restart()
              }
            }
          }
        }
      }
    }
  }

  // ── Network popup ────────────────────────────────────────────────────────
  PanelWindow {
    id: netPopup
    visible: root.networkMenuOpen
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell-network-popup"

    anchors { top: true; left: true; right: true; bottom: true }

    MouseArea {
      anchors.fill: parent
      onClicked: root.networkMenuOpen = false
    }

    FocusScope {
      anchors.fill: parent
      focus: root.networkMenuOpen
      Keys.onEscapePressed: root.networkMenuOpen = false

      Rectangle {
        id: netCard
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 70
        anchors.rightMargin: 8
        width: 370
        height: root.showPasswordPrompt ? 160 : 360
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        color: "#1e1e2e"
        border.color: "#585b70"
        border.width: 2
        radius: 10
        clip: true

        // swallow: prevents close MouseArea behind from firing when clicking inside card
        MouseArea { anchors.fill: parent }

        // ── Password prompt ──────────────────────────────────────────
        Column {
          anchors.fill: parent
          anchors.margins: 14
          spacing: 10
          visible: root.showPasswordPrompt

          Row {
            width: parent.width; spacing: 8
            Text { text: "󰤨"; font.pixelSize: 14; color: "#89b4fa"; anchors.verticalCenter: parent.verticalCenter }
            Text { text: root.pendingSsid; font.pixelSize: 12; font.weight: Font.Bold; color: "#cdd6f4"; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: parent.width - 30 }
          }

          Rectangle {
            width: parent.width; height: 36; radius: 8
            color: "#313244"; border.color: "#45475a"; border.width: 1

            TextInput {
              id: pwInput
              anchors.fill: parent
              anchors.leftMargin: 12; anchors.rightMargin: 12
              verticalAlignment: TextInput.AlignVCenter
              echoMode: TextInput.Password
              color: "#cdd6f4"; font.pixelSize: 12
              focus: root.showPasswordPrompt

              Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                text: "Password"
                color: "#585b70"; font.pixelSize: 12
                visible: pwInput.text.length === 0
              }

              onAccepted: connectBtn.doConnect()
            }
          }

          Row {
            width: parent.width; spacing: 8

            Rectangle {
              width: (parent.width - 8) / 2; height: 36; radius: 8
              color: cancelHover.containsMouse ? "#313244" : "#252535"
              Behavior on color { ColorAnimation { duration: 150 } }

              Text { anchors.centerIn: parent; text: "Cancel"; color: "#a6adc8"; font.pixelSize: 11 }
              MouseArea {
                id: cancelHover
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { root.showPasswordPrompt = false; pwInput.text = "" }
              }
            }

            Rectangle {
              id: connectBtn
              width: (parent.width - 8) / 2; height: 36; radius: 8
              color: connHover.containsMouse ? "#6ba3e8" : "#89b4fa"
              Behavior on color { ColorAnimation { duration: 150 } }

              function doConnect() {
                if (!root.pendingSsid || !pwInput.text) return
                connectWifiProc.command = ["bash", "-c",
                  "nmcli dev wifi connect \"" + root.pendingSsid + "\" password \"" + pwInput.text + "\" 2>/dev/null"]
                connectWifiProc.running = true
                root.showPasswordPrompt = false
                root.networkMenuOpen   = false
                pwInput.text = ""
              }

              Text { anchors.centerIn: parent; text: "Connect"; color: "#1e1e2e"; font.pixelSize: 11; font.weight: Font.Bold }
              MouseArea {
                id: connHover
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: connectBtn.doConnect()
              }
            }
          }
        }

        // ── Normal list view ─────────────────────────────────────────
        Column {
          anchors.fill: parent
          anchors.margins: 12
          spacing: 10
          visible: !root.showPasswordPrompt

          // ── Tab row + power toggles ──────────────────────────────
          Item {
            width: parent.width; height: 32

            Row {
              anchors.left: parent.left
              anchors.top: parent.top; anchors.bottom: parent.bottom
              width: parent.width * 0.55

              Repeater {
                model: [{ key: "wifi", label: "󰤨   WiFi" }, { key: "bt", label: "󰂯   Bluetooth" }]
                Item {
                  width: parent.width / 2; height: 32
                  Text {
                    anchors.centerIn: parent
                    text: modelData.label
                    color: root.activeTab === modelData.key ? "#cdd6f4" : "#585b70"
                    font.pixelSize: 11
                    font.weight: root.activeTab === modelData.key ? Font.Bold : Font.Normal
                  }
                  Rectangle {
                    anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 20; height: 2; radius: 1; color: "#89b4fa"
                    visible: root.activeTab === modelData.key
                  }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.activeTab = modelData.key
                  }
                }
              }
            }

            Row {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: 6

              // Rescan button — wifi tab only
              Rectangle {
                width: 26; height: 26; radius: 6
                visible: root.activeTab === "wifi" && root.wifiPowered
                color: rescanArea.containsMouse ? "#313244" : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text { anchors.centerIn: parent; text: "󰑐"; font.pixelSize: 13; color: rescanArea.containsMouse ? "#cdd6f4" : "#585b70" }

                MouseArea {
                  id: rescanArea
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.wifiNetworks = []
                    if (wifiRescanProc.running) wifiRescanProc.terminate()
                    wifiRescanProc.running = true
                  }
                }
              }

              // WiFi power toggle
              Rectangle {
                width: 48; height: 26; radius: 13
                visible: root.activeTab === "wifi"
                color: root.wifiPowered ? "#89b4fa" : "#313244"
                Behavior on color { ColorAnimation { duration: 250 } }

                Rectangle {
                  width: 20; height: 20; radius: 10; color: "white"
                  anchors.verticalCenter: parent.verticalCenter
                  x: root.wifiPowered ? parent.width - width - 3 : 3
                  Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                }

                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var on = !root.wifiPowered
                    wifiToggleProc.command = ["bash", "-c", on ? "nmcli radio wifi on" : "nmcli radio wifi off"]
                    wifiToggleProc.running = true
                    root.wifiPowered = on
                    if (!on) root.wifiNetworks = []
                  }
                }
              }

              // BT power toggle
              Rectangle {
                width: 48; height: 26; radius: 13
                visible: root.activeTab === "bt"
                color: root.btPowered ? "#89b4fa" : "#313244"
                Behavior on color { ColorAnimation { duration: 250 } }

                Rectangle {
                  width: 20; height: 20; radius: 10; color: "white"
                  anchors.verticalCenter: parent.verticalCenter
                  x: root.btPowered ? parent.width - width - 3 : 3
                  Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                }

                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var on = !root.btPowered
                    btToggleProc.command = ["bash", "-c", on ? "bluetoothctl power on" : "bluetoothctl power off"]
                    btToggleProc.running = true
                    root.btPowered = on
                    if (!on) root.btDevices = []
                  }
                }
              }
            }
          }

          // ── WiFi list ──────────────────────────────────────────────
          Column {
            width: parent.width; spacing: 4
            visible: root.activeTab === "wifi"

            Item {
              width: parent.width; height: 34; visible: !root.wifiPowered
              Text { anchors.centerIn: parent; text: "WiFi is turned off"; color: "#585b70"; font.pixelSize: 11 }
            }
            Item {
              width: parent.width; height: 34; visible: root.wifiPowered && root.wifiNetworks.length === 0
              Text { anchors.centerIn: parent; text: "Scanning..."; color: "#585b70"; font.pixelSize: 11 }
            }

            Repeater {
              model: root.wifiNetworks
              Rectangle {
                width: parent.width; height: 34; radius: 5
                color: modelData.active === "yes" ? "#2a2a3d" : wifiHover.containsMouse ? "#252535" : "#313244"

                Row {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left; anchors.leftMargin: 10
                  spacing: 8

                  Text {
                    text: {
                      var s = parseInt(modelData.signal) || 0
                      if (s >= 80) return "󰤨"
                      if (s >= 60) return "󰤥"
                      if (s >= 40) return "󰤢"
                      if (s >= 20) return "󰤟"
                      return "󰤯"
                    }
                    color: modelData.active === "yes" ? "#89b4fa" : "#585b70"; font.pixelSize: 13
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Text {
                    text: modelData.ssid !== "" ? modelData.ssid : "Hidden"
                    color: modelData.active === "yes" ? "#cdd6f4" : "#a6adc8"; font.pixelSize: 11
                    font.weight: modelData.active === "yes" ? Font.Bold : Font.Normal
                    anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: 200
                  }
                  Text {
                    text: modelData.active === "yes" ? "✓" : ""
                    color: "#89b4fa"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
                  }
                }

                MouseArea {
                  id: wifiHover
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (!modelData.ssid || modelData.active === "yes") return
                    root.pendingSsid = modelData.ssid
                    root.typedPassword = ""
                    root.showPasswordPrompt = true
                  }
                }
              }
            }
          }

          // ── BT list ────────────────────────────────────────────────
          Column {
            width: parent.width; spacing: 4
            visible: root.activeTab === "bt"

            Item {
              width: parent.width; height: 34; visible: !root.btPowered
              Text { anchors.centerIn: parent; text: "Bluetooth is turned off"; color: "#585b70"; font.pixelSize: 11 }
            }
            Item {
              width: parent.width; height: 34; visible: root.btPowered && root.btDevices.length === 0
              Text { anchors.centerIn: parent; text: "Scanning..."; color: "#585b70"; font.pixelSize: 11 }
            }

            Repeater {
              model: root.btDevices
              Rectangle {
                width: parent.width; height: 34; radius: 5
                color: modelData.connected === 1 ? "#2a2a3d" : btHover.containsMouse ? "#252535" : "#313244"

                Row {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left; anchors.leftMargin: 10
                  spacing: 8

                  Text { text: "󰂯"; color: modelData.connected === 1 ? "#89b4fa" : "#585b70"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                  Text {
                    text: modelData.name !== "" ? modelData.name : modelData.mac
                    color: modelData.connected === 1 ? "#cdd6f4" : "#a6adc8"; font.pixelSize: 11
                    font.weight: modelData.connected === 1 ? Font.Bold : Font.Normal
                    anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: 210
                  }
                  Text { text: modelData.connected === 1 ? "✓" : ""; color: "#89b4fa"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                  id: btHover
                  anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    if (!modelData.mac || modelData.mac === "") return
                    var cmd = modelData.connected === 1
                      ? "bluetoothctl disconnect " + modelData.mac
                      : "bluetoothctl connect "    + modelData.mac
                    btConnectProc.command = ["bash", "-c", cmd]
                    btConnectProc.running = true
                    root.networkMenuOpen = false
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // ── Entrance ─────────────────────────────────────────────────────────────
  property int  cascadeIndex: 1
  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutBack } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  // ── Floating pill background ──────────────────────────────────────────────
  Rectangle {
    id: pillBg
    height: 50
    width: barRow.implicitWidth + 24
    radius: 14
    color: Qt.rgba(0.118, 0.118, 0.180, 0.75)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
  }

  // ── Bar row ────────────────────────────────────────────────────────────────
  Row {
    id: barRow
    anchors.verticalCenter: parent.verticalCenter
    anchors.right: parent.right
    anchors.rightMargin: 14
    spacing: 16

    // Volume — click to open volume popup
    Item {
      width: volInner.implicitWidth; height: 56
      Row {
        id: volInner; spacing: 8
        anchors.verticalCenter: parent.verticalCenter

        Text { text: root.volumeIcon; font.pixelSize: 13; color: root.volumeMenuOpen ? "#89b4fa" : "#a6adc8"; anchors.verticalCenter: parent.verticalCenter }

        Item {
          width: 60; height: 56
          Rectangle {
            width: parent.width; height: 4; radius: 2; color: "#45475a"
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
              width: parent.width * Math.min(root.volumeLevel, 100) / 100
              height: parent.height; radius: 2
              color: root.volumeLevel > 100 ? "#fab387" : "#89b4fa"
            }
          }
        }

        Text { text: root.volumeLevel + "%"; font.pixelSize: 10; color: root.volumeMenuOpen ? "#89b4fa" : "#cdd6f4"; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
      }
      MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.volumeMenuOpen = !root.volumeMenuOpen
          if (root.networkMenuOpen) root.networkMenuOpen = false
        }
      }
    }

    Item { width: 1; height: 56; Rectangle { anchors.centerIn: parent; width: 1; height: 18; color: "#45475a" } }

    // WiFi — click to open network popup
    Item {
      width: wifiInner.implicitWidth; height: 56
      Row {
        id: wifiInner; spacing: 5
        anchors.verticalCenter: parent.verticalCenter
        Text { text: "󰤨"; font.pixelSize: 13; color: root.networkMenuOpen ? "#89b4fa" : "#a6adc8"; anchors.verticalCenter: parent.verticalCenter }
        Text { text: root.wifiName; font.pixelSize: 10; color: root.networkMenuOpen ? "#89b4fa" : "#cdd6f4"; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: Math.min(implicitWidth, 90) }
      }
      MouseArea {
        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.networkMenuOpen = !root.networkMenuOpen
          if (root.volumeMenuOpen) root.volumeMenuOpen = false
        }
      }
    }
  }
}
