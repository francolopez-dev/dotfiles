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
  property int maxUsage: 0

  readonly property color statusColor: {
    if (maxUsage >= 90) return Color.urgent
    if (maxUsage >= 75) return "#d7ba7d"
    return root.bar ? root.bar.barForeground : Color.foreground
  }

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
      var visibleDetails = []
      root.maxUsage = 0
      for (var i = 1; i < lines.length; i++) {
        if (lines[i].indexOf("max\t") === 0) root.maxUsage = Number(lines[i].slice(4)) || 0
        else visibleDetails.push(lines[i])
      }
      root.details = visibleDetails.length > 0 ? visibleDetails.join("\n") : root.label
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    foreground: root.statusColor
    horizontalMargin: 5
    tooltipText: root.details
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.MiddleButton) root.refresh()
      else root.bar.run("omarchy-launch-tui btop")
    }
  }
}
