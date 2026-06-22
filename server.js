/**
 * opencode-ppm-service — PM2 entry point
 *
 * Spawns `opencode web` as a managed child process.
 * PM2 manages this process; opencode serves the web UI.
 *
 * Access: http://algonaoffice:6969  (or http://100.96.201.41:6969)
 *
 * Config: this repo's opencode.jsonc is the single source of truth.
 * On startup it's synced to ~/.config/opencode/ so opencode web sessions pick it up.
 */

import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import path from 'path';
import os from 'os';
import { createHash } from 'crypto';

const PORT = process.env.OPENCODE_WEB_PORT || 6969;
const HOST = process.env.OPENCODE_WEB_HOST || '0.0.0.0';
const __dirname = path.dirname(fileURLToPath(import.meta.url));

// --- Sync config to ~/.config/opencode/ ---
// opencode web sessions read config from the user's .config directory.
// We keep the canonical opencode.jsonc here in the wrapper repo and sync it on startup.
const sourceConfig = path.join(__dirname, 'opencode.jsonc');
const targetDir = path.join(os.homedir(), '.config', 'opencode');
const targetConfig = path.join(targetDir, 'opencode.jsonc');

if (existsSync(sourceConfig)) {
  mkdirSync(targetDir, { recursive: true });
  const srcContent = readFileSync(sourceConfig, 'utf-8');
  const srcHash = createHash('sha256').update(srcContent).digest('hex');

  let needsSync = true;
  if (existsSync(targetConfig)) {
    const tgtContent = readFileSync(targetConfig, 'utf-8');
    const tgtHash = createHash('sha256').update(tgtContent).digest('hex');
    if (srcHash === tgtHash) {
      needsSync = false;
    }
  }

  if (needsSync) {
    writeFileSync(targetConfig, srcContent, 'utf-8');
    console.log(`[opencode-web] Synced opencode.jsonc → ${targetConfig}`);
  } else {
    console.log(`[opencode-web] opencode.jsonc already up to date in ~/.config/opencode/`);
  }
}

console.log(`[opencode-web] Starting opencode web on ${HOST}:${PORT}`);
console.log(`[opencode-web] Working directory: ${__dirname}`);

const proc = spawn('opencode', ['web', '--port', String(PORT), '--hostname', HOST], {
  stdio: 'inherit',
  shell: true,
  cwd: __dirname,
  env: { ...process.env }
});

proc.on('error', (err) => {
  console.error('[opencode-web] Failed to spawn opencode:', err.message);
  process.exit(1);
});

proc.on('exit', (code, signal) => {
  console.log(`[opencode-web] opencode exited (code=${code} signal=${signal})`);
  process.exit(code ?? 1);
});

// Forward termination signals to the child process
process.on('SIGINT', () => { proc.kill('SIGINT'); });
process.on('SIGTERM', () => { proc.kill('SIGTERM'); });
