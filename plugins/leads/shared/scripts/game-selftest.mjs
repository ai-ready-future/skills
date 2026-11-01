// Runs the self-test of a practice game without a browser.
// Usage: node scripts/game-selftest.mjs <path/to/call-game.html>
// Pass: best path 100%, worst path under 20%, no dashes in the game data, and no problems
// from the page self-test (empty text, 4 options per scene, one option with 10 points).
import { readFileSync } from "node:fs";
import vm from "node:vm";

const file = process.argv[2];
if (!file) { console.error("usage: node game-selftest.mjs <call-game.html>"); process.exit(2); }

const html = readFileSync(file, "utf8");
const data = html.match(/\/\*GAME_DATA_START\*\/([\s\S]*?)\/\*GAME_DATA_END\*\//);
if (!data) { console.error("no GAME_DATA_START ... GAME_DATA_END block found"); process.exit(2); }
const scripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].map((m) => m[1]);
if (!scripts.length) { console.error("no <script> block found"); process.exit(2); }

const el = () => ({ style: {}, innerHTML: "", textContent: "", onclick: null, focus() {} });
const nodes = {};
const document = {
  title: "",
  getElementById: (id) => (nodes[id] ??= el()),
  querySelector: () => null,
  querySelectorAll: () => [],
  addEventListener: () => {},
};
const ctx = vm.createContext({ document, location: { hash: "#selftest" }, Math, JSON, String, Object });
for (const code of scripts) vm.runInContext(code, ctx, { filename: file });

const m = document.title.match(/^SELFTEST (.*)$/);
if (!m) { console.error("self-test did not run"); process.exit(1); }
const out = JSON.parse(m[1]);
console.log(JSON.stringify(out, null, 2));

const fails = [];
if (out.best !== 100) fails.push(`best path is ${out.best}%, must be 100%`);
if (!(out.worst < 20)) fails.push(`worst path is ${out.worst}%, must be under 20%`);
if (/[\u2013\u2014]/.test(data[1])) fails.push("em dash or en dash in the game data");
if (out.problems.length) fails.push(`${out.problems.length} problem(s): ${out.problems.join("; ")}`);
if (fails.length) { console.error("FAIL\n- " + fails.join("\n- ")); process.exit(1); }
console.log("PASS");
