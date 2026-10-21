import type { Register } from 'claude-code'

// Idle scaffold: the band draws nothing yet. Later slices read the `look`
// state (types/index.d.ts) and build the rows here.
export const register: Register = on => {
  on('ui.render', { component: 'AbovePrompt' }, (_$, e, next) => next(e))
}
