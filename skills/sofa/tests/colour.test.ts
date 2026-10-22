import { expect, test } from 'claude-code/testing'
import { colourFor, roleColours, roleOf, teamPrefix } from '../hooks/register.tsx'

const ADLC = [
  '| Team prefix | `acme` (session names are `<prefix>-<role>[-n]`) |',
  '',
  '| Role | Colour | Model |',
  '|---|---|---|',
  '| orchestrator | `purple` | `claude-opus-5-5` |',
  '| implementer | `green` | `claude-sonnet-5-5` |',
  '| odd | `gray` | `claude-sonnet-5-5` |',
  '',
].join('\n')

const OLD_ADLC = ['| Team prefix | `acme` |', '', '| Role | Model |', '|---|---|', '| hitl | `claude-sonnet-5-5` |'].join('\n')
const TEMPLATE = ['| Role | Colour | Model |', '|---|---|---|', '| hitl | `yellow` | `claude-sonnet-5-5` |'].join('\n')

function fakeFs(files: Record<string, string>) {
  return {
    exists: async (path: string) => path in files,
    read: async (path: string) => {
      if (!(path in files)) throw new Error(`missing ${path}`)
      return files[path]
    },
  }
}

test('reads the team prefix', () => {
  expect(teamPrefix(ADLC)).toBe('acme')
  expect(teamPrefix('| Team prefix | `<prefix>` |')).toBe(null)
})

test('reads the Colour column and skips names /color does not take', () => {
  expect([...roleColours(ADLC)]).toEqual([['orchestrator', 'purple'], ['implementer', 'green']])
  expect(roleColours(OLD_ADLC).size).toBe(0)
})

test('finds the role in a session name', () => {
  expect(roleOf('acme-implementer-2', 'acme')).toBe('implementer')
  expect(roleOf('acme-orchestrator', 'acme')).toBe('orchestrator')
  expect(roleOf('other-implementer', 'acme')).toBe(null)
})

test('gives a team session its colour, and no colour to other sessions', async () => {
  const fs = fakeFs({ '/repo/docs/adlc.md': ADLC })
  expect(await colourFor(fs, '/repo', 'acme-implementer-3', '/skill')).toBe('green')
  expect(await colourFor(fs, '/repo', 'my-session', '/skill')).toBe(null)
  expect(await colourFor(fs, '/elsewhere', 'acme-implementer', '/skill')).toBe(null)
})

test('uses the template colour when docs/adlc.md has no Colour column', async () => {
  const fs = fakeFs({ '/repo/docs/adlc.md': OLD_ADLC, '/skill/templates/ADLC.md': TEMPLATE })
  expect(await colourFor(fs, '/repo', 'acme-hitl', '/skill')).toBe('yellow')
})
