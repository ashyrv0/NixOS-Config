import QtQuick
import Quickshell
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Wayland
import "."

Item {
  id: root
  implicitWidth: barRow.implicitWidth + 20

  // ── State ─────────────────────────────────────────────────────────────
  property bool   networkMenuOpen: false
  property int    volumeLevel: 0
  property string volumeIcon:  "󰝟"
  property string wifiName:    "..."
  property string wifiIcon:    "󰤨"
  property string btName:      "..."
  property string btIcon:      "󰂯"
  property var    wifiNetworks: []
  property var    btDevices:    []
  property string activeTab:   "wifi"

  // password prompt state
  property bool   showPasswordPrompt: false
  property string pendingSsid: ""
  property string typedPassword: ""

property bool   ethConnected: false
property string ethName: "enp5s0"
  property int    ramUsage: 0
  // ── Volume ────────────────────────────────────────────────────────────
  Process {
    id: volProc
    command: ["bash", "-c", "$HOME/.config/quickshell/volume_info.sh"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var d = JSON.parse(this.text.trim())
          root.volumeLevel = d.vol
          root.volumeIcon  = d.icon
        } catch(e) {}
      }
    }
  }
  Timer {
    interval: 1000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: { if (volProc.running) volProc.terminate(); volProc.running = true }
  }

  // ── RAM ───────────────────────────────────────────────────────────────
  Process {
    id: ramProc
    command: ["bash", "-c", "free | awk '/Mem:/{printf \"%d\", $3/$2*100}'"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var v = parseInt(this.text.trim())
        if (!isNaN(v)) root.ramUsage = v
      }
    }
  }
  Timer {
    interval: 2000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: { if (ramProc.running) ramProc.terminate(); ramProc.running = true }
  }

  // ── WiFi bar label — uses friend's exact field names ──────────────────
  // nmcli -t -f ACTIVE,SSID (uppercase) is what works on most systems
  Process {
    id: wifiNameProc
    command: ["bash", "-c",
      "ETH_IFACE=$(nmcli -t -f DEVICE,TYPE d 2>/dev/null | awk -F: '$2==\"ethernet\"{print $1;exit}'); " +
      "if [ -n \"$ETH_IFACE\" ] && ip link show $ETH_IFACE 2>/dev/null | grep -q UP; then echo 'Ethernet'; exit 0; fi; " +
      "STATUS=$(nmcli -t -f WIFI g 2>/dev/null); " +
      "if [ \"$STATUS\" != 'enabled' ]; then echo 'Disconnected'; exit 0; fi; " +
      "SSID=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2); " +
      "[ -z \"$SSID\" ] && echo 'Disconnected' || echo \"$SSID\""
    ]
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

  // ── WiFi list ─────────────────────────────────────────────────────────
  Process {
    id: wifiListProc
    command: ["bash", "-c",
      "STATUS=$(nmcli -t -f WIFI g 2>/dev/null); " +
      "if [ \"$STATUS\" != 'enabled' ]; then echo '{\"power\":\"off\",\"connected\":null,\"networks\":[]}'; exit 0; fi; " +
      // Get connected network using ACTIVE,SSID (friend's field names)
      "ACTIVE_LINE=$(nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi 2>/dev/null | grep '^yes'); " +
      "SSID=$(echo \"$ACTIVE_LINE\" | cut -d: -f2); " +
      "SIG=$(echo \"$ACTIVE_LINE\" | cut -d: -f3); " +
      "SEC=$(echo \"$ACTIVE_LINE\" | cut -d: -f4); " +
      "CJSON='null'; " +
      "[ -n \"$SSID\" ] && CJSON=$(printf '{\"id\":\"%s\",\"ssid\":\"%s\",\"signal\":\"%s\",\"security\":\"%s\",\"active\":\"yes\"}' \"$SSID\" \"$SSID\" \"${SIG:-0}\" \"${SEC:-Open}\"); " +
      // Get other networks
      "NETS=$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi list --rescan no 2>/dev/null | " +
      "  grep -v '^yes' | grep -v '^--' | " +
      "  awk -F: '!seen[$2]++ && $2!=\"\" {printf \"{\\\"id\\\":\\\"%s\\\",\\\"ssid\\\":\\\"%s\\\",\\\"signal\\\":%s,\\\"active\\\":\\\"no\\\"}\\n\", $2, $2, ($3==\"\" ? 0 : $3)}' | " +
      "  head -15 | jq -s '.'); " +
      "jq -n --arg p 'on' --argjson c \"${CJSON}\" --argjson n \"${NETS:-[]}\" '{power:$p,connected:$c,networks:$n}'"
    ]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var raw = this.text.trim()
          if (raw === "") return
          var d = JSON.parse(raw)
          var nets = d.networks || []
          if (d.connected && d.connected.ssid) {
            root.wifiName = d.connected.ssid
            nets = [d.connected].concat(nets.filter(function(n) { return n.ssid !== d.connected.ssid }))
          }
          root.wifiNetworks = nets
        } catch(e) { console.warn("wifiListProc parse error:", e) }
      }
    }
  }

  // ── BT list — uses Bluetooth.sh ──────────────────────────────────────
  Process {
    id: btListProc
    command: ["bash", "-c", "$HOME/.config/quickshell/Bluetooth.sh"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        var raw = this.text.trim()
        if (raw === "") {
          root.btDevices = [{ connected: 0, mac: "", name: "No paired devices" }]
          return
        }
        try {
          var d = JSON.parse(raw)
          if (d.powered !== "yes") {
            root.btDevices = [{ connected: 0, mac: "", name: "Bluetooth is off" }]
            return
          }
          var devs = d.devices.map(function(dev) {
            return {
              connected: dev.state === "connected" ? 1 : 0,
              mac: dev.mac,
              name: dev.name
            }
          })
          root.btDevices = devs.length > 0 ? devs : [{ connected: 0, mac: "", name: "No paired devices" }]
        } catch(e) {
          root.btDevices = [{ connected: 0, mac: "", name: "No paired devices" }]
        }
      }
    }
  }

  Process { id: connectWifiProc }
  Process { id: btConnectProc }

  onNetworkMenuOpenChanged: {
    if (networkMenuOpen) {
      root.activeTab        = "wifi"
      root.wifiNetworks     = []
      root.btDevices        = []
      root.showPasswordPrompt = false
      root.pendingSsid      = ""
      root.typedPassword    = ""
      wifiListProc.running  = true
      if (btListProc.running) btListProc.terminate()
      btListProc.running    = true
    }
  }

  // ── Popup ─────────────────────────────────────────────────────────────
  PanelWindow {
    id: netPopup
    visible: root.networkMenuOpen
    implicitWidth:  270
    implicitHeight: root.showPasswordPrompt ? 160 : 360

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-network-popup"

    anchors.top:   true
    anchors.right: true
    margins.top:   58
    color: "transparent"

    Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    Rectangle {
      anchors.fill: parent
      color: Theme.background
      border.color: "#585b70"
      border.width: 2
      radius: 10
      clip: true

      // ── Password prompt view ─────────────────────────────────────────
      Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10
        visible: root.showPasswordPrompt

        Row {
          width: parent.width
          spacing: 8

          Text {
            text: "󰤨"
            font.pixelSize: 14; color: Theme.accent
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: root.pendingSsid
            font.pixelSize: 12; font.weight: Font.Bold; color: Theme.text
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            width: parent.width - 30
          }
        }

        // Password input field
        Rectangle {
          width: parent.width; height: 36; radius: 6
          color: Theme.surface0; border.color: pwInput.activeFocus ? Theme.accent : Theme.surface1; border.width: 1

          Row {
            anchors.fill: parent; anchors.margins: 10; spacing: 6

            Text {
              text: "󰌋"
              font.pixelSize: 13; color: "#585b70"
              anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
  id: pwInput
  width: parent.width - 40
  anchors.verticalCenter: parent.verticalCenter
  color: Theme.text
  font.pixelSize: 11
  echoMode: TextInput.Password

  // This replaces placeholderText
  Text {
    text: "Password..."
    color: "#585b70"
    font.pixelSize: 11
    visible: !pwInput.text && !pwInput.activeFocus
  }

  onTextChanged: root.typedPassword = text
  Keys.onReturnPressed: connectBtn.doConnect()
  Keys.onEscapePressed: {
    root.showPasswordPrompt = false
    root.typedPassword = ""
    pwInput.text = ""
  }
  Component.onCompleted: forceActiveFocus()
}
          }
        }

        // Buttons row
        Row {
          width: parent.width; spacing: 8

          Rectangle {
            width: (parent.width - 8) / 2; height: 32; radius: 6
            color: cancelMa.containsMouse ? Theme.surface1 : Theme.surface0
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
              anchors.centerIn: parent
              text: "Cancel"; color: Theme.text; font.pixelSize: 11
            }
            MouseArea {
              id: cancelMa
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.showPasswordPrompt = false
                root.typedPassword = ""
                pwInput.text = ""
              }
            }
          }

          Rectangle {
            id: connectBtn
            width: (parent.width - 8) / 2; height: 32; radius: 6
            color: connMa.containsMouse ? "#74c7ec" : Theme.accent
            Behavior on color { ColorAnimation { duration: 120 } }

            function doConnect() {
              if (root.typedPassword !== "") {
                connectWifiProc.command = ["bash", "-c",
                  "nmcli dev wifi connect '" + root.pendingSsid + "' password '" + root.typedPassword + "' 2>&1"
                ]
              } else {
                connectWifiProc.command = ["bash", "-c",
                  "nmcli dev wifi connect '" + root.pendingSsid + "' 2>&1"
                ]
              }
              connectWifiProc.running = true
              root.showPasswordPrompt = false
              root.networkMenuOpen    = false
              root.typedPassword = ""
              pwInput.text = ""
            }

            Text {
              anchors.centerIn: parent
              text: "Connect"; color: Theme.background; font.pixelSize: 11; font.weight: Font.Bold
            }
            MouseArea {
              id: connMa
              anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: connectBtn.doConnect()
            }
          }
        }
      }

      // ── Normal list view ─────────────────────────────────────────────
      Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10
        visible: !root.showPasswordPrompt

        // Tabs
        Row {
          width: parent.width; height: 32; spacing: 0

          Repeater {
            model: [
              { key: "wifi", label: "󰤨   WiFi"     },
              { key: "bt",   label: "󰂯   Bluetooth" }
            ]
            Item {
              width: parent.width / 2; height: 32

              Text {
                anchors.centerIn: parent
                text: modelData.label
                color: root.activeTab === modelData.key ? Theme.text : "#585b70"
                font.pixelSize: 11
                font.weight: root.activeTab === modelData.key ? Font.Bold : Font.Normal
              }
              Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 20; height: 2; radius: 1
                color: Theme.accent
                visible: root.activeTab === modelData.key
              }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: root.activeTab = modelData.key
              }
            }
          }
        }

        // WiFi list
        Column {
          width: parent.width; spacing: 4
          visible: root.activeTab === "wifi"

          Item {
            width: parent.width; height: 34
            visible: root.wifiNetworks.length === 0
            Text { anchors.centerIn: parent; text: "Scanning..."; color: "#585b70"; font.pixelSize: 11 }
          }

          Repeater {
            model: root.wifiNetworks

            Rectangle {
              width: parent.width; height: 34; radius: 5
              color: modelData.active === "yes" ? "#2a2a3d"
                   : wifiHover.containsMouse    ? "#252535"
                   :                              Theme.surface0

              Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: 10
                spacing: 8

                Text {
                  text: {
                    var s = parseInt(modelData.signal) || 0
                    if (s >= 75) return "󰤨"
                    if (s >= 50) return "󰤥"
                    if (s >= 25) return "󰤢"
                    return "󰤟"
                  }
                  color: modelData.active === "yes" ? Theme.accent : "#585b70"
                  font.pixelSize: 13
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: modelData.ssid !== "" ? modelData.ssid : "Hidden"
                  color: modelData.active === "yes" ? Theme.text : Theme.text
                  font.pixelSize: 11
                  font.weight: modelData.active === "yes" ? Font.Bold : Font.Normal
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight; width: 180
                }

                Text {
                  text: modelData.active === "yes" ? "✓" : ""
                  color: Theme.accent; font.pixelSize: 11
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                id: wifiHover
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (!modelData.ssid) return
                  if (modelData.active === "yes") return
                  // Show inline password prompt
                  root.pendingSsid = modelData.ssid
                  root.typedPassword = ""
                  root.showPasswordPrompt = true
                }
              }
            }
          }
        }

        // BT list
        Column {
          width: parent.width; spacing: 4
          visible: root.activeTab === "bt"

          Item {
            width: parent.width; height: 34
            visible: root.btDevices.length === 0
            Text { anchors.centerIn: parent; text: "Scanning..."; color: "#585b70"; font.pixelSize: 11 }
          }

          Repeater {
            model: root.btDevices

            Rectangle {
              width: parent.width; height: 34; radius: 5
              color: modelData.connected === 1 ? "#2a2a3d"
                   : btHover.containsMouse     ? "#252535"
                   :                             Theme.surface0

              Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left; anchors.leftMargin: 10
                spacing: 8

                Text {
                  text: "󰂯"
                  color: modelData.connected === 1 ? Theme.accent : "#585b70"
                  font.pixelSize: 14
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  text: modelData.name !== "" ? modelData.name : modelData.mac
                  color: modelData.connected === 1 ? Theme.text : Theme.text
                  font.pixelSize: 11
                  font.weight: modelData.connected === 1 ? Font.Bold : Font.Normal
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight; width: 185
                }

                Text {
                  text: modelData.connected === 1 ? "✓" : ""
                  color: Theme.accent; font.pixelSize: 11
                  anchors.verticalCenter: parent.verticalCenter
                }
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
                  root.networkMenuOpen  = false
                }
              }
            }
          }
        }
      }
    }
  }

  // ── Bar row ───────────────────────────────────────────────────────────
  Row {
    id: barRow
    anchors.verticalCenter: parent.verticalCenter
    anchors.right: parent.right
    anchors.rightMargin: 10
    spacing: 20

    // Volume
    Item {
      width: volInner.implicitWidth; height: 48
      Row {
        id: volInner; spacing: 8
        anchors.verticalCenter: parent.verticalCenter

        Text { text: root.volumeIcon; font.pixelSize: 13; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }

        Item {
          width: 60; height: 48
          Rectangle {
            width: parent.width; height: 4; radius: 2; color: Theme.surface1
            anchors.verticalCenter: parent.verticalCenter
            Rectangle { width: parent.width * (root.volumeLevel / 100); height: parent.height; radius: 2; color: Theme.accent }
          }
        }

        Text { text: root.volumeLevel + "%"; font.pixelSize: 10; color: Theme.text; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
      }
    }

    Item { width: 1; height: 48; Rectangle { anchors.centerIn: parent; width: 1; height: 18; color: Theme.surface1 } }

    // RAM
    Item {
      width: ramInner.implicitWidth; height: 48
      Row {
        id: ramInner; spacing: 4
        anchors.verticalCenter: parent.verticalCenter
        Text { text: "RAM"; font.pixelSize: 10; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
        Text { text: root.ramUsage + "%"; font.pixelSize: 10; color: Theme.text; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
      }
    }

    Item { width: 1; height: 48; Rectangle { anchors.centerIn: parent; width: 1; height: 18; color: Theme.surface1 } }

    // WiFi
    Item {
      width: wifiInner.implicitWidth; height: 48
      Row {
        id: wifiInner; spacing: 5
        anchors.verticalCenter: parent.verticalCenter

        Text { text: "󰤨"; font.pixelSize: 13; color: root.networkMenuOpen ? Theme.accent : Theme.text; anchors.verticalCenter: parent.verticalCenter }
        Text { text: root.wifiName; font.pixelSize: 10; color: root.networkMenuOpen ? Theme.accent : Theme.text; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: Math.min(implicitWidth, 90) }
      }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.networkMenuOpen = !root.networkMenuOpen }
    }
  }
}
