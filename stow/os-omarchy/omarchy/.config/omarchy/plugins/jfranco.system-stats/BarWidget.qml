import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "jfranco.system-stats"

  property string label: ""
  property string details: ""

  function refresh() {
    statsProcess.running = true
  }

  visible: label !== "" && !vertical
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: statsProcess
    command: [Quickshell.env("HOME") + "/.local/bin/dotfiles-system-stats", "--bar"]
    stdout: StdioCollector {
      id: statsOut
      waitForEnd: true
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      var lines = String(statsOut.text || "").trim().split("\n")
      root.label = lines.length > 0 ? lines[0] : ""
      root.details = lines.length > 1 ? lines.slice(1).join("\n") : root.label
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    horizontalMargin: 7
    tooltipText: root.details
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.MiddleButton) root.refresh()
      else root.bar.run("omarchy-launch-tui btop")
    }
  }
}
