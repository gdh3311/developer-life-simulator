import { contextBridge } from 'electron'

// Game services (Git, Code Runner, Save) will be exposed here via IPC.
contextBridge.exposeInMainWorld('workstation', {
  platform: process.platform
})
