import { expect, test } from 'claude-code/testing'
import { mapStatus } from '../hooks/lib/status'

test('mapStatus maps completed, failed, killed and anything else', async () => {
  expect(mapStatus('completed')).toBe('ok')
  expect(mapStatus('failed')).toBe('failed')
  expect(mapStatus('killed')).toBe('stopped')
  expect(mapStatus('weird')).toBe('stopped')
  expect(mapStatus(undefined)).toBe('stopped')
})
