import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { Report } from '../types'

// The names the built-in /color takes.
const COLOURS = new Set(['red', 'blue', 'green', 'yellow', 'purple', 'orange', 'pink', 'cyan'])
const PANE = 'sofa-dashboard'
// Change the tag when Report changes: it declines what an earlier version stored.
const report = atom({ plugin: 'sofa', key: 'report' } as const, { text: '', at: '' }, { shape: 'report-1' })

// The team prefix in section 1 of an ADLC file, or null.
export function teamPrefix(adlc: string): string | null {
  return /^\| Team prefix \| `([^`<>]+)`/m.exec(adlc)?.[1] ?? null
}

// One column of the roles table in an ADLC file: role name to cell value.
// Empty when the table has no such column (a file from an older template).
export function roleColumn(adlc: string, name: string): Map<string, string> {
  const values = new Map<string, string>()
  const lines = adlc.split('\n')
  const cells = (line: string) => line.split('|').slice(1, -1).map(cell => cell.trim().replaceAll('`', ''))
  // The roles table is the first table whose first column is Role and that has the column.
  const header = lines.findIndex(line => line.startsWith('| Role |') && cells(line).includes(name))
  if (header === -1) return values
  const column = cells(lines[header]).indexOf(name)
  if (column === -1) return values
  for (const line of lines.slice(header + 2)) {
    if (!line.startsWith('|')) break
    const row = cells(line)
    values.set(row[0], row[column])
  }
  return values
}

// The Colour column of the roles table: role name to colour, known colours only.
export function roleColours(adlc: string): Map<string, string> {
  return new Map([...roleColumn(adlc, 'Colour')].filter(([, colour]) => COLOURS.has(colour)))
}

// The role of a session named <prefix>-<role> or <prefix>-<role>-<n>, or null.
export function roleOf(name: string, prefix: string): string | null {
  if (!name.startsWith(`${prefix}-`)) return null
  return name.slice(prefix.length + 1).replace(/-\d+$/, '') || null
}

type Fs = { exists: (path: string) => Promise<boolean>; read: (path: string) => Promise<string> }
export type Member = { role: string; colour: string | null; model: string | null }

// The team role of a session, or null for any other session. A session of
// the team has the name <prefix>-<role>[-n] and starts in the main folder,
// which holds docs/adlc.md.
export async function memberOf(fs: Fs, cwd: string, name: string, pluginRoot: string): Promise<Member | null> {
  const path = `${cwd}/docs/adlc.md`
  if (!(await fs.exists(path))) return null
  const adlc = await fs.read(path)
  const prefix = teamPrefix(adlc)
  const role = prefix === null ? null : roleOf(name, prefix)
  if (role === null) return null
  // An older docs/adlc.md has no Colour column: use the colour of the template.
  const colour =
    roleColours(adlc).get(role) ?? roleColours(await fs.read(`${pluginRoot}/templates/ADLC.md`)).get(role) ?? null
  return { role, colour, model: roleColumn(adlc, 'Model').get(role) ?? null }
}

// The colour of a team session, or null for any other session.
export async function colourFor(fs: Fs, cwd: string, name: string, pluginRoot: string): Promise<string | null> {
  return (await memberOf(fs, cwd, name, pluginRoot))?.colour ?? null
}

// The sofa-state arguments that record a session start.
export function upsertArgs(name: string, id: string, member: Member): string[] {
  const args = ['session', 'upsert', '--name', name, '--id', id, '--role', member.role, '--state', 'live']
  return member.model === null ? args : [...args, '--model', member.model]
}

export const register: Register = on => {
  let timer: { cancel: () => void } | undefined
  on('session.start', async ($, e, next) => {
    await $.command.register({ name: PANE, description: 'Show the sofa team dashboard in a pane' })
    return next(e)
  })

  on('classic.SessionStart', async ($, e, next) => {
    const result = await next(e)
    if (e.source === 'compact' || e.session_title === undefined) return result
    const log = (error: unknown) =>
      $.ui.log(`sofa: ${error instanceof Error ? error.message : String(error)}`, { to: 'debug' })
    const fs: Fs = { exists: path => $.fs.exists(path), read: path => $.fs.read(path) }
    const member = await memberOf(fs, e.cwd, e.session_title, $.plugin.root).catch((error: unknown) => {
      log(error)
      return null
    })
    if (member === null) return result
    // Not awaited: the run waits until the session is idle, and this hook must not.
    if (member.colour !== null) $.command.run({ command: 'color', args: member.colour }).catch(log)
    $.process
      .run([`${$.plugin.root}/scripts/sofa-state`, ...upsertArgs(e.session_title, e.session_id, member)], {
        cwd: e.cwd,
        timeoutMs: 10_000,
      })
      .catch(log)
    return result
  })

  // A heartbeat at each turn end, so the dashboard and the orchestrator see a live session.
  on('classic.Stop', async ($, e, next) => {
    const result = await next(e)
    const name = e.session_title
    const store = await $.fs.exists(`${e.cwd}/.sofa/state.db`).catch(() => false)
    if (name === undefined || !store) return result
    $.process
      .run([`${$.plugin.root}/scripts/sofa-state`, 'session', 'heartbeat', '--name', name], { cwd: e.cwd, timeoutMs: 10_000 })
      .catch(() => undefined)
    return result
  })

  on('command.run', { command: PANE }, async ($, e) => {
    const refresh = async () => {
      const run = await $.process.run([`${$.plugin.root}/scripts/sofa-state`, 'report'], { cwd: e.cwd, timeoutMs: 10_000 })
      const text = run.exitCode === 0 ? run.stdout : `sofa-state report failed: ${run.stderr.trim()}`
      await update($, report, () => ({ text, at: new Date().toISOString() }))
    }
    await refresh().catch(async (error: unknown) => {
      await update($, report, () => ({ text: `sofa-state did not run: ${String(error)}`, at: '' }))
    })
    // One timer only: a second /sofa-dashboard replaces the first timer.
    timer?.cancel()
    timer = $.clock.every(30_000, () => void refresh().catch(() => undefined))
    await $.ui.open({ id: PANE, title: 'sofa team' })
    return { text: 'sofa dashboard opened. It refreshes every 30 seconds.' }
  })

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const { text, at } = await read($, report)
    const room = Math.max(1, (e.viewport?.rows ?? 24) - 3)
    const lines = text === '' ? ['No state store yet. Start the team with /sofa:sofa.'] : text.trimEnd().split('\n')
    return (
      <Box flexDirection="column">
        {lines.slice(0, room).map(line => (
          <Text>{line}</Text>
        ))}
        {at !== '' && <Text dimColor>updated {at.slice(11, 19)} UTC</Text>}
      </Box>
    )
  })
}
