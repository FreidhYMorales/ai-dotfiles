import { expect, test } from 'claude-code/testing'

import { isFresh, normalizeRollup, parseGh, summarize } from '../hooks/lib/ci'

const run = (exitCode: number, stdout = '', stderr = '') => ({ exitCode, stdout, stderr })
const body = (extra: object = {}) =>
  JSON.stringify({ number: 17, state: 'OPEN', headRefOid: 'abc', statusCheckRollup: [{ __typename: 'CheckRun', name: 'lint', status: 'COMPLETED', conclusion: 'FAILURE' }], ...extra })

test('normalizeRollup maps CheckRun status/conclusion and StatusContext state', () => {
  const run = (name: string, status: string, conclusion = '') => ({ __typename: 'CheckRun', name, status, conclusion })
  const ctx = (context: string, state: string) => ({ __typename: 'StatusContext', context, state })
  const rollup = [
    run('a', 'COMPLETED', 'SUCCESS'), run('b', 'COMPLETED', 'SKIPPED'), run('c', 'COMPLETED', 'FAILURE'),
    run('d', 'COMPLETED', 'CANCELLED'), run('e', 'IN_PROGRESS'), run('f', 'QUEUED'),
    ctx('g', 'SUCCESS'), ctx('h', 'PENDING'), ctx('i', 'FAILURE'), ctx('j', 'ERROR'), { weird: true },
  ]
  const states = normalizeRollup(rollup).map(c => `${c.name}:${c.state}`)
  expect(states).toEqual(['a:ok', 'b:ok', 'c:failed', 'd:failed', 'e:pending', 'f:pending', 'g:ok', 'h:pending', 'i:failed', 'j:failed'])
  expect(normalizeRollup(null)).toEqual([])
})

test('parseGh reads an open PR, treats a missing or closed PR as none and anything else as an error', () => {
  expect(parseGh(run(0, body()), 5)).toEqual({ at: 5, pr: 17, headSha: 'abc', checks: [{ name: 'lint', state: 'failed' }] })
  expect(parseGh(run(1, '', 'no pull requests found for branch "b"'), 5)).toEqual({ at: 5, pr: 0, headSha: '', checks: [] })
  expect(parseGh(run(0, body({ state: 'MERGED' })), 5)?.pr).toBe(0)
  for (const bad of [run(1, '', 'HTTP 401'), run(0, 'not json'), run(0, '{}')]) expect(parseGh(bad, 5)).toBeUndefined()
})

test('summarize picks failed over pending over ok and lists the failing names', () => {
  const c = (name: string, state: 'ok' | 'failed' | 'pending') => ({ name, state })
  expect(summarize([c('a', 'ok'), c('b', 'pending')])).toEqual({ state: 'pending', failing: [] })
  expect(summarize([c('a', 'failed'), c('b', 'pending'), c('c', 'failed')])).toEqual({ state: 'failed', failing: ['a', 'c'] })
  expect(summarize([c('a', 'ok')]).state).toBe('ok')
})

test('a cache entry is fresh for 60 s while checks are pending and 5 min otherwise', () => {
  const entry = (state: 'ok' | 'pending') => ({ at: 0, pr: 17, headSha: 'a', checks: [{ name: 'x', state }] })
  expect(isFresh(entry('pending'), 59_999)).toBe(true)
  expect(isFresh(entry('pending'), 60_000)).toBe(false)
  expect(isFresh(entry('ok'), 299_999)).toBe(true)
  expect(isFresh(entry('ok'), 300_000)).toBe(false)
})

test('a "no open PR" entry is fresh for 60 s, so a new PR shows within a minute', () => {
  const none = { at: 0, pr: 0, headSha: '', checks: [] }
  expect(isFresh(none, 59_999)).toBe(true)
  expect(isFresh(none, 60_000)).toBe(false)
})
