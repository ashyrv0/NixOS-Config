import QtQuick
import Quickshell
import Quickshell.Io

pragma Singleton

QtObject {
    id: root

    // ── Raw parsed wal data ───────────────────────────────────────────
    property var _colors:  null
    property var _special: null

    // ── Public color API ──────────────────────────────────────────────
    readonly property color background:  _special ? _special.background : "#0f1525"
    readonly property color foreground:  _special ? _special.foreground  : "#c3c4c8"

    readonly property color accent:      _colors  ? _colors.color4       : "#E0B0A6"
    readonly property color accentMuted: Qt.darker(accent, 1.2)
    readonly property color accentDark:  Qt.darker(accent, 1.5)

    readonly property color surface:     Qt.lighter(background, 1.10)
    readonly property color surface0:    Qt.lighter(background, 1.15)
    readonly property color surface1:    _colors  ? _colors.color8       : Qt.lighter(background, 1.30)
    readonly property color surface2:    Qt.lighter(surface1, 1.10)

    readonly property color text:        foreground
    readonly property color textMuted:   Qt.darker(foreground, 1.3)
    readonly property color textDim:     _colors  ? _colors.color8       : "#5f6374"
    readonly property color textBright:  Qt.lighter(foreground, 1.1)

    readonly property color success:     _colors  ? _colors.color2       : "#73A7C2"
    readonly property color warning:     _colors  ? _colors.color3       : "#ACACAF"
    readonly property color error:       _colors  ? _colors.color1       : "#659FC0"

    readonly property bool  ready:       _colors !== null

    // ── Helper: parse and apply colors.json text ──────────────────────
    function applyWal(jsonText) {
        try {
            var data = JSON.parse(jsonText)
            root._colors  = data.colors  || null
            root._special = data.special || null
            console.log("Theme: wal loaded — bg=" + root.background + " accent=" + root.accent)
        } catch(e) {
            console.warn("Theme: JSON parse error:", e)
        }
    }

    // ── Initial load via Process ──────────────────────────────────────
    property var _loadProc: Process {
        command: ["bash", "-c", "cat \"$HOME/.cache/wal/colors.json\""]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.applyWal(text)
        }
    }

    // ── Watch colors.json for changes (wallpaper changes) ─────────────
    // Poll every 2 seconds — inotify isn't exposed in Quickshell QML directly
    property var _watchTimer: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (_watchProc.running) return
            _watchProc.running = true
        }
    }

    property var _lastJson: ""

    property var _watchProc: Process {
        command: ["bash", "-c", "cat \"$HOME/.cache/wal/colors.json\""]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim()
                if (t !== "" && t !== root._lastJson) {
                    root._lastJson = t
                    root.applyWal(t)
                }
            }
        }
    }
}
