// Load a QML `.pragma library` JS file in node: strip the pragma/.import
// lines and run it in a fresh context; top-level functions and vars become
// properties of the returned object.
import { readFileSync } from "node:fs";
import vm from "node:vm";

export function loadLibrary(path, globals = {}) {
  const src = readFileSync(path, "utf8")
    .split("\n")
    .map((l) => (/^\s*\.(pragma|import)\b/.test(l) ? "" : l))
    .join("\n");
  const ctx = vm.createContext({ console, Math, ...globals });
  vm.runInContext(src, ctx, { filename: path });
  return ctx;
}
