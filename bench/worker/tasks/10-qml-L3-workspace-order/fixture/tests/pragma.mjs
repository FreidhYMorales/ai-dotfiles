// Load a QML `.pragma library` JS file in node: drop the pragma line and run
// it in a fresh context; its top-level functions become properties.
import { readFileSync } from "node:fs";
import vm from "node:vm";

export function loadLibrary(path) {
  const src = readFileSync(new URL(path, import.meta.url), "utf8").replace(/^\s*\.pragma\b.*$/m, "");
  const ctx = vm.createContext({});
  vm.runInContext(src, ctx);
  return ctx;
}

// plain: copy a value out of the vm context so deepStrictEqual compares data.
export const plain = (v) => JSON.parse(JSON.stringify(v));
