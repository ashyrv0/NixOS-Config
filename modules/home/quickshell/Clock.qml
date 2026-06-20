import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
  id: root
  implicitWidth: pillBg.width
  implicitHeight: pillBg.height

  property int cascadeIndex: 3
  property bool calendarOpen: false

  // ── Entrance ────────────────────────────────────────────────────────
  property bool entered: false
  Timer { interval: 200 + root.cascadeIndex * 80; running: true; onTriggered: root.entered = true }
  opacity: entered ? 1 : 0
  transform: Translate { y: root.entered ? 0 : 14; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutBack } } }
  Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  // ── Floating pill (bar widget) ─────────────────────────────────────
  Rectangle {
    id: pillBg
    height: 50
    width: col.implicitWidth + 28
    radius: 14
    color: pillMouse.containsMouse || root.calendarOpen ? Qt.rgba(0.19, 0.19, 0.27, 0.85) : Qt.rgba(0.118, 0.118, 0.180, 0.75)
    border.color: Qt.rgba(1, 1, 1, 0.06)
    border.width: 1
    anchors.verticalCenter: parent.verticalCenter

    scale: pillMouse.containsMouse ? 1.04 : 1.0
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
    Behavior on color { ColorAnimation { duration: 200 } }

    Column {
      id: col
      anchors.centerIn: parent
      spacing: 2

      Text {
        text: Qt.formatDateTime(clock.date, "hh:mm:ss")
        color: "#cdd6f4"
        font.pixelSize: 15
        font.weight: Font.Bold
        font.family: "JetBrainsMono Nerd Font"
        anchors.horizontalCenter: parent.horizontalCenter
      }

      Text {
        text: Qt.formatDateTime(clock.date, "ddd MMM d")
        color: root.calendarOpen ? "#89b4fa" : "#a6adc8"
        font.pixelSize: 10
        font.family: "JetBrainsMono Nerd Font"
        anchors.horizontalCenter: parent.horizontalCenter
        Behavior on color { ColorAnimation { duration: 200 } }
      }
    }

    MouseArea {
      id: pillMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.calendarOpen = !root.calendarOpen
    }
  }

  // ── Calendar popup ──────────────────────────────────────────────────
  PanelWindow {
    id: calPopup
    visible: animOpacity > 0.01
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "qs-calendar-popup"
    anchors { top: true; left: true; right: true; bottom: true }

    property real animOpacity: root.calendarOpen ? 1.0 : 0.0
    Behavior on animOpacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    Connections {
      target: root
      function onCalendarOpenChanged() {
        if (root.calendarOpen) {
          calGrid.viewMonth = clock.date.getMonth()
          calGrid.viewYear  = clock.date.getFullYear()
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.calendarOpen = false
    }

    FocusScope {
      anchors.fill: parent
      focus: root.calendarOpen
      Keys.onEscapePressed: root.calendarOpen = false

      Rectangle {
        id: calCard
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 70
        anchors.rightMargin: 8
        width: 280
        radius: 10
        clip: true
        focus: true
        color: "#1e1e2e"
        border.color: "#585b70"
        border.width: 2

        opacity: calPopup.animOpacity
        scale: 0.94 + 0.06 * calPopup.animOpacity
        transform: Translate { y: (1 - calPopup.animOpacity) * -10 }
        implicitHeight: calColumn.implicitHeight + 32
        height: implicitHeight
        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        Keys.onEscapePressed: root.calendarOpen = false
        MouseArea { anchors.fill: parent }

        Column {
          id: calColumn
          anchors.fill: parent
          anchors.margins: 16
          spacing: 12

          // ── Month header + nav ──────────────────────────────────
          Row {
            width: parent.width
            height: 26

            Rectangle {
              width: 26; height: 26; radius: 6
              color: prevMonthArea.containsMouse ? "#313244" : "transparent"
              Behavior on color { ColorAnimation { duration: 150 } }
              Text {
                anchors.centerIn: parent
                text: "‹"
                color: "#89b4fa"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"
              }
              MouseArea {
                id: prevMonthArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  calGrid.viewMonth -= 1
                  if (calGrid.viewMonth < 0) {
                    calGrid.viewMonth = 11
                    calGrid.viewYear -= 1
                  }
                }
              }
            }

            Text {
              width: parent.width - 52
              horizontalAlignment: Text.AlignHCenter
              text: Qt.locale().standaloneMonthName(calGrid.viewMonth, Locale.LongFormat) + "  " + calGrid.viewYear
              color: "#cdd6f4"; font.pixelSize: 13; font.weight: Font.Bold
              font.family: "JetBrainsMono Nerd Font"
            }

            Rectangle {
              width: 26; height: 26; radius: 6
              color: nextMonthArea.containsMouse ? "#313244" : "transparent"
              Behavior on color { ColorAnimation { duration: 150 } }
              Text {
                anchors.centerIn: parent
                text: "›"
                color: "#89b4fa"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"
              }
              MouseArea {
                id: nextMonthArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  calGrid.viewMonth += 1
                  if (calGrid.viewMonth > 11) {
                    calGrid.viewMonth = 0
                    calGrid.viewYear += 1
                  }
                }
              }
            }
          }

          // ── Day-of-week headers ─────────────────────────────────
          Row {
            id: weekdayRow
            width: parent.width
            spacing: 0

            Repeater {
              model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
              Text {
                width: weekdayRow.width / 7
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: (index === 0 || index === 6) ? "#45475a" : "#6c7086"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.family: "JetBrainsMono Nerd Font"
              }
            }
          }

          // ── Calendar grid ────────────────────────────────────────
          Item {
            id: calGrid
            width: parent.width

            property int viewMonth: clock.date.getMonth()
            property int viewYear:  clock.date.getFullYear()

            property int todayDay:   clock.date.getDate()
            property int todayMonth: clock.date.getMonth()
            property int todayYear:  clock.date.getFullYear()

            property int firstDow:    new Date(viewYear, viewMonth, 1).getDay()
            property int daysInMonth: new Date(viewYear, viewMonth + 1, 0).getDate()
            property int prevMonthDays: new Date(viewYear, viewMonth, 0).getDate()
            property int rows: Math.ceil((firstDow + daysInMonth) / 7)

            height: rows * 32

            Repeater {
              model: calGrid.rows * 7

              delegate: Item {
                id: cell
                required property int index

                property int dayNum:    index - calGrid.firstDow + 1
                property bool inMonth:  dayNum >= 1 && dayNum <= calGrid.daysInMonth
                property bool isToday:  inMonth
                  && dayNum            === calGrid.todayDay
                  && calGrid.viewMonth === calGrid.todayMonth
                  && calGrid.viewYear  === calGrid.todayYear
                property bool isWeekend: (index % 7 === 0) || (index % 7 === 6)
                property int ghostNum: dayNum < 1
                  ? calGrid.prevMonthDays + dayNum
                  : dayNum - calGrid.daysInMonth

                width:  calGrid.width / 7
                height: 32
                x: (index % 7) * width
                y: Math.floor(index / 7) * height

                Rectangle {
                  anchors.centerIn: parent
                  width: 26; height: 26; radius: 13
                  color: cellArea.containsMouse && cell.inMonth && !cell.isToday
                    ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                  Behavior on color { ColorAnimation { duration: 150 } }
                }

                // today: soft outline, not a loud fill
                Rectangle {
                  anchors.centerIn: parent
                  width: 28; height: 28; radius: 14
                  visible: cell.isToday
                  color: Qt.rgba(0.537, 0.706, 0.980, 0.18)
                  border.width: 1
                  border.color: "#89b4fa"
                  Behavior on color { ColorAnimation { duration: 200 } }
                }

                Text {
                  anchors.centerIn: parent
                  text: cell.inMonth ? cell.dayNum.toString() : cell.ghostNum.toString()
                  font.pixelSize: 12
                  font.family: "JetBrainsMono Nerd Font"
                  font.weight: cell.isToday ? Font.Bold : Font.Normal
                  font.features: ({ "tnum": 1 })
                  color: cell.inMonth
                    ? (cell.isToday ? "#89b4fa" : (cell.isWeekend ? "#a6adc8" : "#cdd6f4"))
                    : "#45475a"
                }

                MouseArea {
                  id: cellArea
                  anchors.fill: parent
                  hoverEnabled: true
                }
              }
            }
          }
        }
      }
    }
  }
}
