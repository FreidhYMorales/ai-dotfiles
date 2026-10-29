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

type Call = { tool: string; input?: { command?: unknown } };

// Unlike the Claude hook, fails closed: a shell call it cannot read is blocked.
async function preferModernCli(call: Call): Promise<void> {
  if (call.tool !== "shell") return;
  const command = call.input?.command;
  if (typeof command !== "string") throw new Error("toolkit: malformed shell call");
  const payload = JSON.stringify({ tool_name: "Bash", tool_input: { command } });
  const result = spawnSync("bash", [join(HOOKS, "prefer-modern-cli.sh")], { input: payload, encoding: "utf8" });
  if (result.status === 2) throw new Error(result.stderr.trim());
}

type SystemPart = { type: string; text: string };
type ContextRequest = { sessionID: string; system: SystemPart[] };

// Session start: OpenCode V2 has no session-start event that adds context, so
// the Claude session-start hooks run here and their text joins the system as
// one block (context and messages alike: OpenCode has no user-only channel).
function sessionStart(directory: string): string {
  const payload = JSON.stringify({ source: "startup", cwd: directory });
  const parts: string[] = [];
  for (const hook of ["host-info", "pack-hint", "backup-status"]) {
    const result = spawnSync("bash", [join(HOOKS, `${hook}.sh`)], { input: payload, encoding: "utf8" });
    if (!result.stdout.trim()) continue;
    const out = JSON.parse(result.stdout);
    parts.push(out.hookSpecificOutput?.additionalContext ?? out.systemMessage);
  }
  return parts.join("\n\n");
}

export default {
  id: "toolkit",
  async setup(ctx: any) {
    // The hooks run on a session's first model call; later calls reuse the block.
    const blocks = new Map<string, string>();
    const registrations = [
      await ctx.tool.hook("execute.before", preferModernCli),
      await ctx.session.hook("context", async (request: ContextRequest) => {
        if (!blocks.has(request.sessionID)) blocks.set(request.sessionID, sessionStart(ctx.location.directory));
        request.system.push({ type: "text", text: blocks.get(request.sessionID)! });
      }),
    ];
    return async () => {
      await Promise.all(registrations.map((registration) => registration.dispose()));
    };
  },
};
