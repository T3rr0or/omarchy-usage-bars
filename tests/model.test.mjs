// Tests for Model.js. Run with: node tests/model.test.mjs
// Model.js is a QML JavaScript library, so its `.pragma library` line is
// stripped before Node evaluates it.
import { readFileSync } from "node:fs"
import assert from "node:assert/strict"

const source = readFileSync(new URL("../Model.js", import.meta.url), "utf8").replace(".pragma library", "")
const mod = { exports: {} }
new Function("module", source)(mod)
const Model = mod.exports

const now = Date.parse("2026-11-25T12:00:00Z")
const future = "2026-12-01T00:00:00Z"
let failures = 0

function test(name, fn) {
  try {
    fn()
    console.log("  ok   " + name)
  } catch (e) {
    failures++
    console.log("  FAIL " + name + ": " + e.message)
  }
}

test("picks session and weekly windows", () => {
  const w = Model.windows({ limits: [
    { label: "Session (5-hour)", percent: 0.64, resetsAt: future },
    { label: "Weekly (7-day)", percent: 0.13, resetsAt: future },
  ] }, now)
  assert.equal(w.session.percent, 0.64)
  assert.equal(w.weekly.percent, 0.13)
})

test("skips model-scoped limits", () => {
  const w = Model.windows({ limits: [{ label: "Fable Weekly", title: "Fable Weekly", percent: 1, resetsAt: future }] }, now)
  assert.equal(w.weekly, null)
})

test("a weekly-only record has no session window", () => {
  const w = Model.windows({ limits: [{ label: "Weekly (7-day)", percent: 0.26, resetsAt: future }] }, now)
  assert.equal(w.session, null)
  assert.equal(w.weekly.percent, 0.26)
})

test("an expired window counts as unused", () => {
  const w = Model.windows({ limits: [{ label: "Session (5-hour)", percent: 0.9, resetsAt: "2026-11-25T11:00:00Z" }] }, now)
  assert.equal(w.session.percent, 0)
})

test("percent is clamped to 0..1", () => {
  const w = Model.windows({ limits: [
    { label: "Session", percent: 3, resetsAt: future },
    { label: "Weekly", percent: -1, resetsAt: future },
  ] }, now)
  assert.equal(w.session.percent, 1)
  assert.equal(w.weekly.percent, 0)
})

test("missing or malformed records give no windows", () => {
  for (const record of [null, {}, { limits: "x" }, { limits: [null] }]) {
    const w = Model.windows(record, now)
    assert.equal(w.session, null)
    assert.equal(w.weekly, null)
  }
})

test("color overrides must be hex", () => {
  assert.equal(Model.colorFor("claude", {}), "#D97757")
  assert.equal(Model.colorFor("claude", { claude: "#112233" }), "#112233")
  assert.equal(Model.colorFor("claude", { claude: "red; x" }), "#D97757")
  assert.equal(Model.colorFor("unknown", {}), "")
})

test("tooltip shows what is left and no record text", () => {
  const w = Model.windows({ name: "<img src=x>", limits: [
    { label: "Session (5-hour)", percent: 0.64, resetsAt: future },
    { label: "Weekly (7-day)", percent: 0.13, resetsAt: future },
  ] }, now)
  assert.equal(Model.tooltipLine("claude", w, false), "Claude  5h 36% left  week 87% left")
  assert.equal(Model.tooltipLine("<b>x</b>", w, true).includes("<"), false)
})

if (failures) {
  console.log(failures + " failed")
  process.exit(1)
}
console.log("all passed")
