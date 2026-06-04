import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

Item {
  id: root
  implicitWidth: col.implicitWidth + 8

  property bool calendarOpen: false

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }

  Column {
    id: col
    anchors.centerIn: parent
    spacing: 2

    Text {
      text: Qt.formatDateTime(clock.date, "hh:mm:ss")
      color: Theme.text
      font.pixelSize: 15
      font.weight: Font.Bold
      font.family: "JetBrainsMono Nerd Font"
      anchors.horizontalCenter: parent.horizontalCenter
    }

    Text {
      text: Qt.formatDateTime(clock.date, "ddd MMM d")
      color: root.calendarOpen ? Theme.accent : Theme.textMuted
      font.pixelSize: 10
      font.family: "JetBrainsMono Nerd Font"
      anchors.horizontalCenter: parent.horizontalCenter
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.calendarOpen = !root.calendarOpen
  }

  PanelWindow {
    id: calPopup
    visible: root.calendarOpen
    implicitWidth: 310
    implicitHeight: 330

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "qs-calendar-popup"

    anchors.top: true
    anchors.right: true
    margins.top: 58

    color: "transparent"

    Rectangle {
      anchors.fill: parent
      color: Theme.background
      border.color: Theme.surface1
      border.width: 2
      radius: 10

      Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Row {
          width: parent.width
          height: 26

          Rectangle {
            width: 26; height: 26; radius: 4
            color: prevMonthArea.containsMouse ? Theme.surface0 : "transparent"
            Text {
              anchors.centerIn: parent
              text: "‹"
              color: Theme.textMuted
              font.pixelSize: 16
              font.family: "JetBrainsMono Nerd Font"
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
            text: Qt.locale().monthName(calGrid.viewMonth) + "  " + calGrid.viewYear
            color: Theme.text
            font.pixelSize: 13
            font.weight: Font.Bold
            font.family: "JetBrainsMono Nerd Font"
          }

          Rectangle {
            width: 26; height: 26; radius: 4
            color: nextMonthArea.containsMouse ? Theme.surface0 : "transparent"
            Text {
              anchors.centerIn: parent
              text: "›"
              color: Theme.textMuted
              font.pixelSize: 16
              font.family: "JetBrainsMono Nerd Font"
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

        Row {
          width: parent.width
          spacing: 0

          Repeater {
            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
            Text {
              width: (parent.width) / 7
              horizontalAlignment: Text.AlignHCenter
              text: modelData
              color: index === 0 || index === 6 ? Theme.textDim : Theme.textMuted
              font.pixelSize: 11
              font.weight: Font.Bold
              font.family: "JetBrainsMono Nerd Font"
            }
          }
        }

        Item {
          id: calGrid
          width: parent.width
          height: 6 * 34

          property int viewMonth: clock.date.getMonth()
          property int viewYear:  clock.date.getFullYear()

          property int todayDay:   clock.date.getDate()
          property int todayMonth: clock.date.getMonth()
          property int todayYear:  clock.date.getFullYear()

          property int firstDow:    new Date(viewYear, viewMonth, 1).getDay()
          property int daysInMonth: new Date(viewYear, viewMonth + 1, 0).getDate()
          property int totalCells:  firstDow + daysInMonth

          Connections {
            target: root
            function onCalendarOpenChanged() {
              if (root.calendarOpen) {
                calGrid.viewMonth = clock.date.getMonth()
                calGrid.viewYear  = clock.date.getFullYear()
              }
            }
          }

          Repeater {
            model: Math.ceil(calGrid.totalCells / 7) * 7

            delegate: Item {
              id: cell
              property int dayNum:    index - calGrid.firstDow + 1
              property bool validDay: dayNum >= 1 && dayNum <= calGrid.daysInMonth
              property bool isToday:  validDay
                && dayNum            === calGrid.todayDay
                && calGrid.viewMonth === calGrid.todayMonth
                && calGrid.viewYear  === calGrid.todayYear
              property bool isWeekend: (index % 7 === 0) || (index % 7 === 6)

              width:  calGrid.width / 7
              height: 34
              x: (index % 7) * width
              y: Math.floor(index / 7) * height

              Rectangle {
                anchors.centerIn: parent
                width: 28; height: 28; radius: 14
                color: cell.isToday ? Theme.accent : "transparent"
                visible: cell.validDay
              }

              Text {
                anchors.centerIn: parent
                text: cell.validDay ? cell.dayNum.toString() : ""
                font.pixelSize: 12
                font.family: "JetBrainsMono Nerd Font"
                color: cell.isToday    ? Theme.background
                     : cell.isWeekend  ? Theme.textDim
                     :                   Theme.text
                font.weight: cell.isToday ? Font.Bold : Font.Normal
              }
            }
          }
        }
      }
    }
  }
}