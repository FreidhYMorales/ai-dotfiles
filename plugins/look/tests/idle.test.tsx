import { expect, test } from 'claude-code/testing'

const BAND = {
  plugin: 'look',
  component: 'AbovePrompt',
  requestId: 'look-idle',
  props: {
    hasSurvey: false,
    isWorking: false,
    maxRows: 6,
    bodyColumns: 80,
    scroll: { offset: 0, bodyRows: 6 },
    view: {},
  },
} as const

test('an idle session draws nothing above the prompt', { timeoutMs: 30_000 }, async ($, on) => {
  // Nothing draws beneath the plugin: this hook stands for the engine.
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })

  expect((await ui.find({ type: 'Text', text: /engine/ }))?.text).toBe('engine')
  expect(await ui.find({ type: 'Text', text: /failed|running/ })).toBeUndefined()
  await ui.unmount()
})
