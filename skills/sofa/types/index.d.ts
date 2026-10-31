export type Report = { text: string; at: string }

declare module 'claude-code' {
  interface PluginState {
    sofa: { report: Shaped<Report> }
  }
}
