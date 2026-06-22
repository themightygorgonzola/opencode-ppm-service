/**
 * opencode-ppm-service - NSSM / PM2 entry point
 *
 * Spawns `opencode web` as a managed child process.
 * When run as a Windows service (SYSTEM), paths are pinned
 * explicitly - SYSTEM has no npm global PATH and no user homedir.
 *
 * Access: http://algonaoffice:6969  (or http://100.96.201.41:6969)
 *
 * Config: this repo's opencode.jsonc is the single source of truth.
 * On startup it's synced to the real user's ~/.config/opencode/.
 */

import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import path from 'path';
import { createHash } from 'crypto';

const PORT = process.env.OPENCODE_WEB_PORT || 6969;
const HOST = process.env.OPENCODE_WEB_HOST || '0.0.0.0';
const __dirname = path.dirname(fileURLToPath(import.meta.url));

// When running as a Windows service (NSSM -> SYSTEM account),
// os.homedir() returns system32\config\systemprofile. Pin the
// real user so opencode finds its config, auth.json, and DB.
const REAL_USER = process.env.OPENCODE_USER || 'BackflowsNW';
const REAL_HOME = path.join('C:', 'Users', REAL_USER);

// opencode CLI location - not on SYSTEM's PATH
const OPENCODE_CMD = path.join(REAL_HOME, 'AppData', 'Roaming', 'npm', 'opencode.cmd');

// --- Sync config to real user's ~/.config/opencode/ ---
const sourceConfig = path.join(__dirname, 'opencode.jsonc');
const targetDir = path.join(REAL_HOME, '.config', 'opencode');
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
    console.log(`[opencode-web] Synced opencode.jsonc -> ${targetConfig}`);
  } else {
    console.log(`[opencode-web] opencode.jsonc already up to date in ~/.config/opencode/`);
  }
}

console.log(`[opencode-web] Starting opencode web on ${HOST}:${PORT}`);
console.log(`[opencode-web] Working directory: ${__dirname}`);

// Build a clean environment for the child process.
// We need HOME/USERPROFILE pinned to the real user so opencode
// resolves config/auth.json/DB correctly regardless of which
// account the service runs under.
const childEnv = {
  ...process.env,
  HOME: REAL_HOME,
  USERPROFILE: REAL_HOME,
  // Prepend npm global bin to PATH so opencode.cmd subprocesses
  // can also find globally-installed tools
  PATH: `${path.join(REAL_HOME, 'AppData', 'Roaming', 'npm')};${process.env.PATH || ''}`
};

const proc = spawn(OPENCODE_CMD, ['web', '--port', String(PORT), '--hostname', HOST], {
  stdio: 'inherit',
  shell: true,
  cwd: __dirname,
  env: childEnv
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
