export type FinalState = 'ok' | 'failed' | 'stopped'

/** Maps a task-notification status; anything unknown counts as stopped. */
export function mapStatus(status: unknown): FinalState {
  if (status === 'completed') return 'ok'
  if (status === 'failed') return 'failed'
  return 'stopped'
}
