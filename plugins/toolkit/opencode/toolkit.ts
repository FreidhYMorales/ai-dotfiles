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
type Message = { id?: string; role: string; content?: { type: string; text?: string }[] };
type ContextRequest = { sessionID: string; system: SystemPart[]; messages?: Message[] };

// Pause: the Claude pause hook reads the user's latest message, as the prompt
// of a UserPromptSubmit; `opencode run` wraps it in double quotes.
function pause(directory: string, user: Message): string {
  let prompt = (user.content ?? []).map((part) => (part.type === "text" ? part.text ?? "" : "")).join("");
  const quoted = prompt.trim().match(/^"(.*)"$/s);
  if (quoted) prompt = quoted[1];
  const payload = JSON.stringify({ hook_event_name: "UserPromptSubmit", prompt, cwd: directory, target: "opencode" });
  // A hook that cannot start, fails or prints something unreadable says nothing.
  try {
    const result = spawnSync("bash", [join(HOOKS, "pause.sh")], { input: payload, encoding: "utf8" });
    if (!result.stdout?.trim()) return "";
    const text = JSON.parse(result.stdout).hookSpecificOutput?.additionalContext;
    return typeof text === "string" ? text : "";
  } catch {
    return "";
  }
}

// Session start: OpenCode V2 has no session-start event that adds context, so
// the Claude session-start hooks run here and their text joins the system as
// one block (context and messages alike: OpenCode has no user-only channel).
function sessionStart(directory: string): string {
  const payload = JSON.stringify({ source: "startup", cwd: directory });
  const parts: string[] = [];
  for (const hook of ["host-info", "pack-hint", "backup-status"]) {
    // A hook that cannot start, fails or prints something unreadable says nothing.
    try {
      const result = spawnSync("bash", [join(HOOKS, `${hook}.sh`)], { input: payload, encoding: "utf8" });
      if (!result.stdout?.trim()) continue;
      const out = JSON.parse(result.stdout);
      const text = out.hookSpecificOutput?.additionalContext ?? out.systemMessage;
      if (typeof text === "string" && text.trim()) parts.push(text);
    } catch {
      continue;
    }
  }
  return parts.join("\n\n");
}

export default {
  id: "toolkit",
  async setup(ctx: any) {
    // The hooks run on a session's first model call; later calls reuse the block.
    const blocks = new Map<string, string>();
    const pauses = new Map<string, { messageID?: string; protocol: string }>();
    const registrations = [
      await ctx.tool.hook("execute.before", preferModernCli),
      await ctx.session.hook("context", async (request: ContextRequest) => {
        if (!blocks.has(request.sessionID)) blocks.set(request.sessionID, sessionStart(ctx.location.directory));
        const block = blocks.get(request.sessionID);
        if (block) request.system.push({ type: "text", text: block });
        // The pause hook runs once per user message; a tool loop reuses its answer.
        const user = (request.messages ?? []).filter((message) => message.role === "user").at(-1);
        if (!user) return;
        let paused = pauses.get(request.sessionID);
        if (paused?.messageID !== user.id) {
          paused = { messageID: user.id, protocol: pause(ctx.location.directory, user) };
          pauses.set(request.sessionID, paused);
        }
        if (paused.protocol) request.system.push({ type: "text", text: paused.protocol });
      }),
    ];
    return async () => {
      await Promise.all(registrations.map((registration) => registration.dispose()));
    };
  },
};
