.pragma library

// Picks the two windows the widget draws from one agents usage record:
// the short "session" window on top and the "weekly" one below. A
// model-scoped allowance (a limit with a `title`, such as "Fable Weekly")
// is left out, since it would crowd out the account-wide window.

var DEFAULT_COLORS = {
  claude: "#D97757",
  codex: "#FFFFFF",
  agy: "#4285F4",
  gemini: "#4285F4"
}

var NAMES = {
  claude: "Claude",
  codex: "Codex",
  agy: "Gemini",
  gemini: "Gemini"
}

function clampPercent(value) {
  var n = Number(value)
  if (!isFinite(n) || n < 0) return 0
  return n > 1 ? 1 : n
}

function kindOf(label) {
  var text = String(label || "").toLowerCase()
  if (text.indexOf("session") >= 0 || text.indexOf("5-hour") >= 0 || text.indexOf("daily") >= 0) return "session"
  if (text.indexOf("week") >= 0 || text.indexOf("7-day") >= 0 || text.indexOf("month") >= 0) return "weekly"
  return ""
}

// Returns { session, weekly }, each null or { percent, resetsAt }.
// A window whose reset time has passed counts as empty, as the agents
// panel does.
function windows(record, nowMs) {
  var out = { session: null, weekly: null }
  if (!record || !Array.isArray(record.limits)) return out
  for (var i = 0; i < record.limits.length; i++) {
    var entry = record.limits[i] || {}
    if (String(entry.title || "") !== "") continue
    var kind = kindOf(entry.label)
    if (kind === "" || out[kind]) continue
    var reset = new Date(String(entry.resetsAt || "")).getTime()
    var expired = isFinite(reset) && reset <= nowMs
    out[kind] = {
      percent: expired ? 0 : clampPercent(entry.percent),
      resetsAt: expired ? "" : String(entry.resetsAt || "")
    }
  }
  return out
}

function colorFor(id, overrides) {
  if (overrides && typeof overrides[id] === "string" && /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(overrides[id]))
    return overrides[id]
  return DEFAULT_COLORS[id] || ""
}

function nameFor(id) {
  return NAMES[id] || String(id || "").replace(/[^a-z0-9-]/gi, "")
}

// Remaining share of a window, matching the bars, which drain as it is used.
function pct(w) {
  return w ? Math.round((1 - w.percent) * 100) + "% left" : "-"
}

// One tooltip line per provider, built only from numbers and the fixed
// names above, so no text from the record reaches the tooltip.
function tooltipLine(id, w, stale) {
  return nameFor(id) + "  5h " + pct(w.session) + "  week " + pct(w.weekly) + (stale ? "  (stale)" : "")
}

if (typeof module !== "undefined") module.exports = { windows: windows, colorFor: colorFor, nameFor: nameFor, tooltipLine: tooltipLine, kindOf: kindOf }
