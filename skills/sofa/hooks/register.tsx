import type { Register } from 'claude-code'

// The names the built-in /color takes.
const COLOURS = new Set(['red', 'blue', 'green', 'yellow', 'purple', 'orange', 'pink', 'cyan'])

// The team prefix in section 1 of an ADLC file, or null.
export function teamPrefix(adlc: string): string | null {
  return /^\| Team prefix \| `([^`<>]+)`/m.exec(adlc)?.[1] ?? null
}

// The Colour column of the roles table in an ADLC file: role name to colour.
// Empty when the table has no Colour column (a file from before the colours).
export function roleColours(adlc: string): Map<string, string> {
  const colours = new Map<string, string>()
  const lines = adlc.split('\n')
  const header = lines.findIndex(line => line.startsWith('| Role |'))
  if (header === -1) return colours
  const cells = (line: string) => line.split('|').slice(1, -1).map(cell => cell.trim().replaceAll('`', ''))
  const column = cells(lines[header]).indexOf('Colour')
  if (column === -1) return colours
  for (const line of lines.slice(header + 2)) {
    if (!line.startsWith('|')) break
    const row = cells(line)
    if (COLOURS.has(row[column])) colours.set(row[0], row[column])
  }
  return colours
}

// The role of a session named <prefix>-<role> or <prefix>-<role>-<n>, or null.
export function roleOf(name: string, prefix: string): string | null {
  if (!name.startsWith(`${prefix}-`)) return null
  return name.slice(prefix.length + 1).replace(/-\d+$/, '') || null
}

type Fs = { exists: (path: string) => Promise<boolean>; read: (path: string) => Promise<string> }

// The colour of a team session, or null for any other session. A session of
// the team has the name <prefix>-<role>[-n] and starts in the main folder,
// which holds docs/adlc.md.
export async function colourFor(fs: Fs, cwd: string, name: string, pluginRoot: string): Promise<string | null> {
  const path = `${cwd}/docs/adlc.md`
  if (!(await fs.exists(path))) return null
  const adlc = await fs.read(path)
  const prefix = teamPrefix(adlc)
  const role = prefix === null ? null : roleOf(name, prefix)
  if (role === null) return null
  // An older docs/adlc.md has no Colour column: use the colour of the template.
  return roleColours(adlc).get(role) ?? roleColours(await fs.read(`${pluginRoot}/templates/ADLC.md`)).get(role) ?? null
}

export const register: Register = on => {
  on('classic.SessionStart', async ($, e, next) => {
    const result = await next(e)
    if (e.source === 'compact' || e.session_title === undefined) return result
    const log = (error: unknown) =>
      $.ui.log(`sofa: no role colour (${error instanceof Error ? error.message : String(error)})`, { to: 'debug' })
    const fs: Fs = { exists: path => $.fs.exists(path), read: path => $.fs.read(path) }
    const colour = await colourFor(fs, e.cwd, e.session_title, $.plugin.root).catch((error: unknown) => {
      log(error)
      return null
    })
    // Not awaited: the run waits until the session is idle, and this hook must not.
    if (colour !== null) $.command.run({ command: 'color', args: colour }).catch(log)
    return result
  })
}
