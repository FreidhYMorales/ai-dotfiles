import { expect, test } from 'claude-code/testing'
import { normalizeCommand, shellLabel } from '../hooks/lib/label'

test('normalizeCommand strips cd and VAR= prefixes and keeps three words', async () => {
  expect(normalizeCommand('make check')).toBe('make check')
  expect(normalizeCommand('cd /tmp/x && make check')).toBe('make check')
  expect(normalizeCommand('cd "/my dir" && cd sub && make check')).toBe('make check')
  expect(normalizeCommand('CI=1 NODE_ENV=test npm run build --watch')).toBe('npm run build')
  expect(normalizeCommand('  npm   test  ')).toBe('npm test')
})

test('normalizeCommand masks =value in the kept words', async () => {
  expect(normalizeCommand('curl --token=abc123 https://x')).toBe('curl --token=* https://x')
  expect(normalizeCommand('API_KEY=secret deploy --env=prod')).toBe('deploy --env=*')
})

test('normalizeCommand tells different commands apart by words 2-3', async () => {
  expect(normalizeCommand('npm run build')).not.toBe(normalizeCommand('npm run test'))
})

test('shellLabel prefers the truncated description, else the normalized command', async () => {
  expect(shellLabel('Run the suite', 'make check', 30)).toBe('Run the suite')
  expect(shellLabel('Run the full suite now', 'make check', 10)).toBe('Run the f…')
  expect(shellLabel(undefined, 'make check', 30)).toBe('make check')
  expect(shellLabel('  ', 'make check', 30)).toBe('make check')
})
