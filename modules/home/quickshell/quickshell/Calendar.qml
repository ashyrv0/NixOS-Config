import QtQuick
import Quickshell
import "."

Item {
  id: root

  implicitWidth: 120
  implicitHeight: 24

  property bool menuOpen: false

  property var now: new Date()

  property int year: now.getFullYear()
  property int month: now.getMonth()
  property int today: now.getDate()

  function buildMonth() {
    var first = new Date(year, month, 1)
    var last = new Date(year, month + 1, 0)

    var days = []
    var start = first.getDay()
    var count = last.getDate()

    for (var i = 0; i < start; i++) {
      days.push(null)
    }

    for (var d = 1; d <= count; d++) {
      days.push(d)
    }

    return days
  }

  property var monthDays: buildMonth()

  Text {
    id: calendarText
    text: now.toLocaleDateString(Qt.locale(), "ddd, MMM d")
    font.pixelSize: 11
    color: root.menuOpen ? Theme.accent : Theme.textMuted

    anchors.centerIn: parent
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.menuOpen = !root.menuOpen
  }

  PanelWindow {
    id: calPopup
    visible: root.menuOpen

    implicitWidth: 240
    implicitHeight: 320

    Quickshell.WlrLayershell.layer: Quickshell.WlrLayer.Overlay
    Quickshell.WlrLayershell.exclusionMode: Quickshell.ExclusionMode.Ignore
    Quickshell.WlrLayershell.namespace: "quickshell-calendar-popup"

    anchors.top: true
    anchors.right: true
    margins.top: 58
    color: "transparent"

    Rectangle {
      anchors.fill: parent
      color: Theme.background
      border.color: Theme.surface1
      radius: 10

      Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
          text: now.toLocaleDateString(Qt.locale(), "MMMM yyyy")
          font.pixelSize: 14
          font.bold: true
          color: Theme.text
          anchors.horizontalCenter: parent.horizontalCenter
        }

        Grid {
          columns: 7
          spacing: 4
          width: parent.width - 8
          anchors.horizontalCenter: parent.horizontalCenter

          Repeater {
            model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

            Text {
              width: (parent.width - 18) / 7
              height: 24
              text: modelData
              font.pixelSize: 9
              color: Theme.textDim
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }

          Repeater {
            model: root.monthDays

            Rectangle {
              width: (parent.width - 18) / 7
              height: 24
              radius: 4

              property bool isToday: modelData === root.today

              color: {
                if (modelData === null) return Theme.background
                return isToday ? Theme.accent : Theme.surface0
              }

              Text {
                anchors.centerIn: parent
                text: modelData !== null ? modelData : ""
                font.pixelSize: 10

                color: {
                  if (modelData === null) return Theme.background
                  return parent.isToday ? Theme.background : Theme.text
                }
              }
            }
          }
        }

        Text {
          text: now.toLocaleDateString(Qt.locale(), "dddd, MMMM d, yyyy")
          font.pixelSize: 10
          color: Theme.textMuted
          anchors.horizontalCenter: parent.horizontalCenter
        }
      }
    }
  }
}