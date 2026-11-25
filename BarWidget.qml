import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Two thin bars per agent: the session window on top, the weekly window
// below (side by side on a vertical bar). The numbers come from the usage
// records the built-in Agents plugin keeps in
// ~/.local/state/omarchy/agents/usage/, so this widget never fetches
// anything itself. Left click opens the Agents panel, middle click asks it
// to refresh.
BarWidget {
  id: root
  moduleName: "io.github.t3rr0or.usage-bars"

  readonly property string usageDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/agents/usage"
  readonly property var providers: {
    var list = root.setting("providers", ["claude", "codex", "agy"])
    return Array.isArray(list) ? list.filter(function(id) { return /^[a-z0-9-]+$/.test(String(id)) }) : []
  }
  readonly property var colorOverrides: root.setting("colors", ({}))
  // Sized to the bar's icons: two bars plus the gap are one icon tall, and
  // a bar is a little wider than an icon so a few percent still shows.
  readonly property int barLength: Math.max(8, Math.min(Style.bar.iconSlot - 4, Number(root.setting("barLength", Style.bar.iconSize + 4)) || Style.bar.iconSize + 4))
  readonly property int thickness: Math.max(3, Math.round((Style.bar.iconSize - 2) / 2) - 1)
  readonly property int gap: Math.max(2, Style.bar.iconSize - 2 * thickness)
  readonly property color foreground: root.bar ? root.bar.barForeground : Color.foreground
  property double nowMs: Date.now()

  // Mirrors WidgetButton so the bar's own press handling and tooltip find us.
  readonly property bool interactive: true
  readonly property bool pressable: true
  readonly property bool tooltipHovered: visible && mouseArea.containsMouse

  readonly property string tooltipText: {
    var lines = []
    for (var i = 0; i < groups.count; i++) {
      var g = groups.itemAt(i)
      if (g && g.hasData) lines.push(Model.tooltipLine(g.providerId, g.windows, g.stale))
    }
    return lines.join("\n")
  }

  function triggerPress(button) {
    if (root.bar) root.bar.hideTooltip(root)
    if (!root.bar) return
    if (button === Qt.MiddleButton) root.bar.run("omarchy-shell omarchy.agents refresh")
    else root.bar.run("omarchy-shell omarchy.agents toggle")
  }

  property var registeredBar: null
  function syncClickRegistration() {
    if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(root)
    registeredBar = root.bar
    if (registeredBar && registeredBar.registerClickTarget) registeredBar.registerClickTarget(root)
  }
  onBarChanged: syncClickRegistration()
  Component.onCompleted: syncClickRegistration()
  Component.onDestruction: if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(root)

  visible: content.visibleCount > 0
  implicitWidth: content.implicitWidth
  implicitHeight: content.implicitHeight

  // Reset times pass without the file changing; re-check them each minute.
  Timer {
    interval: 60000
    running: true
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  // One icon slot per provider, the same size as the icons next to it, so
  // the bars keep the bar's rhythm instead of forming one long strip.
  Grid {
    id: content
    columns: root.vertical ? 1 : Math.max(1, groups.count)
    rowSpacing: 0
    columnSpacing: 0

    property int visibleCount: {
      var n = 0
      for (var i = 0; i < groups.count; i++) {
        var g = groups.itemAt(i)
        if (g && g.hasData) n++
      }
      return n
    }

    Repeater {
      id: groups
      model: root.providers

      Item {
        id: group
        required property string modelData
        readonly property string providerId: modelData
        property var record: null
        readonly property var windows: Model.windows(group.record, root.nowMs)
        readonly property var present: ["session", "weekly"].filter(function(k) { return !!group.windows[k] })
        readonly property bool stale: !!group.record && group.record.limitsStale === true
        readonly property color tint: {
          var c = Model.colorFor(group.providerId, root.colorOverrides)
          return c !== "" ? c : root.foreground
        }

        readonly property bool hasData: present.length > 0
        visible: hasData
        width: root.vertical ? root.barSize : Style.bar.iconSlot
        height: root.vertical ? Style.bar.iconSlot : root.barSize
        opacity: stale ? 0.55 : 1

        FileView {
          path: root.usageDir + "/" + group.providerId + ".json"
          watchChanges: true
          printErrors: false
          onFileChanged: reload()
          onLoaded: {
            try {
              var parsed = JSON.parse(text())
              group.record = parsed && typeof parsed === "object" ? parsed : null
            } catch (e) {
              group.record = null
            }
          }
          onLoadFailed: group.record = null
        }

        Grid {
          anchors.centerIn: parent
          columns: root.vertical ? group.present.length : 1
          rowSpacing: root.gap
          columnSpacing: root.gap

          Repeater {
            model: group.present

            Rectangle {
              id: track
              required property string modelData
              readonly property var win: group.windows[modelData]
              width: root.vertical ? root.thickness : root.barLength
              height: root.vertical ? root.barLength : root.thickness
              radius: root.thickness / 2
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)

              Rectangle {
                // Full while there is room left, empty when the limit is used up.
                readonly property real fill: track.win ? 1 - track.win.percent : 0
                x: 0
                y: root.vertical ? parent.height - height : 0
                width: root.vertical ? parent.width : Math.max(fill > 0 ? root.thickness : 0, Math.round(parent.width * fill))
                height: root.vertical ? Math.max(fill > 0 ? root.thickness : 0, Math.round(parent.height * fill)) : parent.height
                radius: parent.radius
                color: group.tint
                Behavior on width { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
              }
            }
          }
        }
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltipText)
    onExited: if (root.bar) root.bar.hideTooltip(root)
    onClicked: function(mouse) { root.triggerPress(mouse.button) }
  }
}
