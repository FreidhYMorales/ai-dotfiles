// OpenCode plugin for the toolkit hooks (plugin API V2, OpenCode 2.1.4).
// prefer-modern-cli: runs the Claude hook on each shell call and blocks the
// call by throwing the hook's message.
import { spawnSync } from "node:child_process";
import { realpathSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

// The plugin is linked into ~/.config/opencode/plugins/; the hooks live next
// to its real path in the repo.
const HOOKS = join(dirname(realpathSync(fileURLToPath(import.meta.url))), "..", "hooks");

type Call = { tool: string; input: { command: string } };

async function preferModernCli(call: Call): Promise<void> {
  if (call.tool !== "shell") return;
  const payload = JSON.stringify({ tool_name: "Bash", tool_input: { command: call.input.command } });
  const result = spawnSync("bash", [join(HOOKS, "prefer-modern-cli.sh")], { input: payload, encoding: "utf8" });
  if (result.status === 2) throw new Error(result.stderr.trim());
}

export default {
  id: "toolkit",
  async setup(ctx: any) {
    const registration = await ctx.tool.hook("execute.before", preferModernCli);
    return async () => registration.dispose();
  },
};
