// Nerd Font glyph set A (docs/plans/look-and-feel/plan.md). All are private-use
// codepoints that render one column wide in the configured terminal font.
const g = (cp: number): string => String.fromCodePoint(cp)

export const G = {
  running: g(0xf0453), // nf-md-sync
  agent: g(0xf06a9), // nf-md-robot
  shell: g(0xf489), // nf-oct-terminal
  ci: g(0xf407), // nf-oct-git_pull_request
  backup: g(0xf0193), // nf-md-content_save
  ok: g(0xf00c), // nf-fa-check
  fail: g(0xf00d), // nf-fa-times
  dim: g(0xf01d8), // nf-md-dots_horizontal
} as const
