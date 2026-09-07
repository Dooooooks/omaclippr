import QtQuick
import Quickshell
import Quickshell.Io

// The buffer's owner, mounted once for the shell.
//
// The Omarchy shell builds a bar per monitor. If the gpu-screen-recorder
// daemon and its state lived on each widget, every screen would run its own
// capture process and the toggle would race itself. This service is the
// single QML owner of the control-script processes; widgets read state
// through it and call its commands.
Item {
  id: root
  width: 0
  height: 0
  visible: false

  property var shell: null
  property var manifest: null
  property var pluginRegistry: null
  property var barWidgetRegistry: null
  property string omarchyPath: ""

  readonly property string script:
    Qt.resolvedUrl("bin/omaclippr").toString().replace(/^file:\/\//, "")

  // ------------------------------------------------------------- state
  property bool active: false
  property int duration: 60
  property string quality: "balanced"
  property var clips: []

  signal clipped(string title, string path)

  // ------------------------------------------------------------- commands
  function start(dur, qual) {
    if (dur === undefined) dur = root.duration
    if (qual === undefined) qual = root.quality
    var d = String(dur || root.duration)
    var q = String(qual || root.quality)
    call(["start", d, q], "start")
  }
  function stop() {
    call(["stop"], "stop")
  }
  function toggle() {
    if (active) stop()
    else start(root.duration, root.quality)
  }
  function clip(seconds) {
    var args = ["clip"]
    if (seconds) args.push(String(seconds))
    call(args, "clip")
  }
  function deleteClip(path) {
    if (!path) return
    call(["delete", String(path)], "delete")
  }

  // Preferences are the service's source of truth and are persisted through
  // the `config` command so the poll loop (which reads them back out of the
  // config file) never reverts a change the user just made.
  function setDuration(sec) {
    root.duration = sec
    call(["config", String(sec), root.quality], "config")
  }
  function setQuality(q) {
    root.quality = q
    call(["config", String(root.duration), q], "config")
  }

  // ------------------------------------------------------------- low-level
  property var pendingOp: ""

  function call(args, op) {
    // One at a time; commands are fast (~10ms latency for a spawn here).
    if (runProc.running) return
    pendingOp = op
    runProc.command = [root.script].concat(args)
    runProc.running = true
  }

  Process {
    id: runProc
    stdout: StdioCollector {
      onStreamFinished: {
        var out = String(text)
        if (root.pendingOp === "clip") {
          try {
            var r = JSON.parse(out)
            if (r && r.ok) root.clipped("Clip saved", r.path || "")
          } catch (e) {}
        }
        root.pendingOp = ""
        root.refresh()
      }
    }
  }

  function refresh() {
    if (statusProc.running) return
    statusProc.command = [root.script, "status"]
    statusProc.running = true
  }

  // True once the prefs have been read back from disk at least once. Before
  // that, the poll is allowed to seed duration/quality; afterwards the
  // service's own properties (which are persisted via `config`) are
  // authoritative and the poll must not clobber a change the user just made.
  property bool prefsLoaded: false

  Process {
    id: statusProc
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(String(text))
          root.active = data.active === true
          if (!root.prefsLoaded) {
            root.duration = Number(data.duration) || 60
            root.quality = String(data.quality || "balanced")
            root.prefsLoaded = true
          }
          var list = []
          if (Array.isArray(data.clips)) {
            for (var i = 0; i < data.clips.length; i++) {
              var c = data.clips[i]
              list.push({ path: String(c.path || ""), ts: Number(c.ts || 0) })
            }
          }
          root.clips = list
        } catch (e) {}
      }
    }
  }

  Timer {
    interval: 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refresh()

  // -------------------------------------------------------------- IPC test
  IpcHandler {
    target: "dooooooks.omaclippr.test"

    function toggle(): string {
      root.toggle(root.duration, root.quality)
      return "toggle"
    }
    function start(): string {
      root.start(root.duration, root.quality)
      return "start"
    }
    function stop(): string {
      root.stop()
      return "stop"
    }
    function clip(): string {
      root.clip("")
      return "clip"
    }
    function status(): string {
      return JSON.stringify({
        active: root.active,
        duration: root.duration,
        quality: root.quality,
        clips: root.clips.length
      })
    }
  }
}
