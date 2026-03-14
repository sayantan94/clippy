#!/usr/bin/env node
import { existsSync, mkdirSync, readFileSync, writeFileSync, appendFileSync, copyFileSync, chmodSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { createServer } from 'http';
import { exec } from 'child_process';
import { createInterface } from 'readline';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PKG_ROOT = join(__dirname, '..');
const HOME = process.env.HOME || process.env.USERPROFILE;
const CLIPPY_HOME = process.env.CLIPPY_HOME || join(HOME, '.clippy');
const RULES_FILE = join(CLIPPY_HOME, 'rules.yaml');
const LOG_FILE = join(CLIPPY_HOME, 'activity.jsonl');
const HOOK_SCRIPT = join(CLIPPY_HOME, 'check-command.sh');
const PORT = parseInt(process.env.CLIPPY_PORT || '3456');
const PKG = JSON.parse(readFileSync(join(PKG_ROOT, 'package.json'), 'utf-8'));

// ─── Colors ────────────────────────────────────────────
const c = {
  r: '\x1b[31m', g: '\x1b[32m', y: '\x1b[33m', b: '\x1b[34m',
  c: '\x1b[36m', dim: '\x1b[2m', bold: '\x1b[1m', reset: '\x1b[0m',
};

function banner() {
  console.log(`${c.c}
   ╭──────────────────────────╮
   │  📎 clippy-guard         │
   │  terminal guardian        │
   ╰──────────────────────────╯
${c.reset}`);
}

function ask(question) {
  const rl = createInterface({ input: process.stdin, output: process.stdout });
  return new Promise(resolve => {
    rl.question(question, answer => { rl.close(); resolve(answer.trim().toLowerCase()); });
  });
}

async function ensureHome() {
  mkdirSync(CLIPPY_HOME, { recursive: true });

  const defaultRules = join(PKG_ROOT, 'rules', 'default-rules.yaml');

  if (existsSync(RULES_FILE)) {
    const current = readFileSync(RULES_FILE, 'utf-8');
    const incoming = readFileSync(defaultRules, 'utf-8');
    if (current !== incoming) {
      const currentRules = parseRulesFromString(current);
      const incomingRules = parseRulesFromString(incoming);

      const currentNames = new Set(currentRules.map(r => r.name));
      const incomingNames = new Set(incomingRules.map(r => r.name));

      const added = incomingRules.filter(r => !currentNames.has(r.name));
      const removed = currentRules.filter(r => !incomingNames.has(r.name));
      const changed = incomingRules.filter(r => {
        const old = currentRules.find(o => o.name === r.name);
        return old && (old.severity !== r.severity || old.pattern !== r.pattern);
      });

      console.log(`\n  ${c.y}⚠${c.reset}  ${c.bold}Rules will be overwritten${c.reset}`);
      console.log(`  ${c.dim}${RULES_FILE}${c.reset}\n`);

      if (added.length) {
        for (const r of added) console.log(`  ${c.g}+ ${r.name}${c.reset} ${c.dim}(${r.severity})${c.reset}`);
      }
      if (removed.length) {
        for (const r of removed) console.log(`  ${c.r}- ${r.name}${c.reset} ${c.dim}(${r.severity})${c.reset}`);
      }
      if (changed.length) {
        for (const r of changed) {
          const old = currentRules.find(o => o.name === r.name);
          console.log(`  ${c.y}~ ${r.name}${c.reset} ${c.dim}${old.severity} → ${r.severity}${c.reset}`);
        }
      }
      if (!added.length && !removed.length && !changed.length) {
        // Only non-rule content differs (e.g. ai_tools section) — silently update
        copyFileSync(defaultRules, RULES_FILE);
        return;
      }

      console.log('');
      const answer = await ask(`  Overwrite? [y/N] `);
      if (answer !== 'y' && answer !== 'yes') {
        console.log(`  ${c.dim}Skipped — keeping existing rules.${c.reset}\n`);
        return;
      }
    }
  }

  copyFileSync(defaultRules, RULES_FILE);
}

// ─── Hook installation ──────────────────────────────────
function installHookScript() {
  const src = join(PKG_ROOT, 'hooks', 'check-command.sh');
  copyFileSync(src, HOOK_SCRIPT);
  chmodSync(HOOK_SCRIPT, '755');
}

function parseRulesFromString(yaml) {
  const rules = [];
  let current = null;

  for (const line of yaml.split('\n')) {
    const nameMatch = line.match(/^\s+-\s+name:\s+(.+)/);
    if (nameMatch) {
      if (current) rules.push(current);
      current = { name: nameMatch[1].trim() };
      continue;
    }
    if (!current) continue;

    const patternMatch = line.match(/^\s+pattern:\s+"(.+)"/);
    if (patternMatch) { current.pattern = patternMatch[1]; continue; }

    const sevMatch = line.match(/^\s+severity:\s+(\w+)/);
    if (sevMatch) { current.severity = sevMatch[1]; continue; }

    const descMatch = line.match(/^\s+description:\s+"(.+)"/);
    if (descMatch) { current.description = descMatch[1]; continue; }

    // Stop parsing rules when we hit ai_tools section
    if (line.match(/^ai_tools:/)) {
      if (current) rules.push(current);
      current = null;
      break;
    }
  }
  if (current) rules.push(current);
  return rules;
}

function parseRules() {
  if (!existsSync(RULES_FILE)) return [];
  return parseRulesFromString(readFileSync(RULES_FILE, 'utf-8'));
}

// ─── Hook installation ──────────────────────────────────
const CLAUDE_SETTINGS = join(HOME, '.claude', 'settings.json');

function installHook() {
  const hookConfig = {
    hooks: {
      PreToolUse: [{
        matcher: 'Bash',
        hooks: [{ type: 'command', command: HOOK_SCRIPT, timeout: 5 }],
      }],
    },
  };

  mkdirSync(dirname(CLAUDE_SETTINGS), { recursive: true });

  let settings = {};
  if (existsSync(CLAUDE_SETTINGS)) {
    try { settings = JSON.parse(readFileSync(CLAUDE_SETTINGS, 'utf-8')); } catch {}
  }

  settings.hooks = hookConfig.hooks;
  writeFileSync(CLAUDE_SETTINGS, JSON.stringify(settings, null, 2) + '\n');
}

function isHookInstalled() {
  try {
    if (existsSync(CLAUDE_SETTINGS)) {
      return readFileSync(CLAUDE_SETTINGS, 'utf-8').includes('check-command');
    }
  } catch {}
  return false;
}

// ─── Commands ──────────────────────────────────────────
async function cmdInit() {
  banner();
  await ensureHome();
  installHookScript();

  installHook();
  console.log(`  ${c.g}✓${c.reset} Claude Code → hook installed`);

  const rules = parseRules();
  const critical = rules.filter(r => r.severity === 'critical').length;

  console.log(`\n  ${c.bold}Rules:${c.reset} ${rules.length} active (${critical} critical)`);
  console.log(`  ${c.bold}Log:${c.reset}   ${LOG_FILE}`);
  console.log(`  ${c.bold}Hook:${c.reset}  ${HOOK_SCRIPT}\n`);
}

function cmdStatus() {
  banner();
  ensureHome();

  console.log(`  ${c.bold}Hook Status${c.reset}\n`);

  if (isHookInstalled()) {
    console.log(`  ${c.g}●${c.reset} Claude Code    ${c.dim}hook active${c.reset}`);
  } else {
    console.log(`  ${c.r}○${c.reset} Claude Code    ${c.dim}no hook${c.reset}`);
  }

  if (existsSync(LOG_FILE)) {
    const lines = readFileSync(LOG_FILE, 'utf-8').trim().split('\n').filter(Boolean);
    const blocked = lines.filter(l => l.includes('"blocked"')).length;
    const warned = lines.filter(l => l.includes('"warned"')).length;
    console.log(`\n  ${c.bold}Stats${c.reset}\n`);
    console.log(`  Commands scanned: ${c.bold}${lines.length}${c.reset}`);
    console.log(`  Blocked:          ${c.r}${c.bold}${blocked}${c.reset}`);
    console.log(`  Warnings:         ${c.y}${c.bold}${warned}${c.reset}`);
  }

  console.log('');
}

function cmdRules() {
  ensureHome();
  const rules = parseRules();
  console.log(`\n  ${c.bold}Active Rules${c.reset}\n`);

  for (const rule of rules) {
    const color = rule.severity === 'critical' ? c.r : rule.severity === 'warning' ? c.y : c.c;
    console.log(`  ${color}${rule.severity.toUpperCase().padEnd(8)}${c.reset}  ${c.bold}${rule.name.padEnd(24)}${c.reset} ${rule.description || ''}`);
  }
  console.log('');
}

function cmdLog(count = 20) {
  ensureHome();
  if (!existsSync(LOG_FILE)) {
    console.log(`\n  ${c.dim}No activity yet.${c.reset}\n`);
    return;
  }

  const lines = readFileSync(LOG_FILE, 'utf-8').trim().split('\n').filter(Boolean).slice(-count);
  console.log(`\n  ${c.bold}Recent Activity${c.reset}\n`);

  for (const line of lines) {
    try {
      const e = JSON.parse(line);
      const time = (e.ts || '').slice(11, 19);
      const color = e.action === 'blocked' ? c.r : e.action === 'warned' ? c.y : c.dim;
      const icon = e.action === 'blocked' ? '✗' : e.action === 'warned' ? '⚠' : '·';
      const cmd = (e.command || '').slice(0, 50);
      console.log(`  ${c.dim}${time}${c.reset}  ${color}${icon} ${(e.action || '').padEnd(9)}${c.reset}  ${(e.rule || '-').padEnd(20)}  ${c.dim}${cmd}${c.reset}`);
    } catch {}
  }
  console.log('');
}

function cmdDashboard() {
  ensureHome();
  const dashboardFile = join(PKG_ROOT, 'dashboard', 'index.html');
  if (!existsSync(dashboardFile)) {
    console.log(`  ${c.r}✗${c.reset} Dashboard not found.`);
    process.exit(1);
  }

  const dashboardUrl = `http://localhost:${PORT}`;

  const server = createServer((req, res) => {
    const url = new URL(req.url, dashboardUrl);

    if (url.pathname === '/api/log') {
      res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      try {
        const lines = readFileSync(LOG_FILE, 'utf-8').trim().split('\n').filter(Boolean).slice(-200);
        const entries = lines.map(l => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean);
        res.end(JSON.stringify(entries));
      } catch { res.end('[]'); }
    } else if (url.pathname === '/api/rules') {
      res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(JSON.stringify(parseRules()));
    } else if (url.pathname === '/api/hooks') {
      res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      const hooks = { claude: isHookInstalled() ? 'active' : 'not found' };
      res.end(JSON.stringify(hooks));
    } else if (url.pathname === '/api/version') {
      res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(JSON.stringify({ version: PKG.version }));
    } else {
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end(readFileSync(dashboardFile, 'utf-8'));
    }
  });

  server.on('error', (err) => {
    if (err.code === 'EADDRINUSE') {
      console.log(`\n  ${c.bold}📎 Clippy Dashboard${c.reset} ${c.dim}(already running)${c.reset}`);
      console.log(`  ${c.c}${dashboardUrl}${c.reset}\n`);
      exec(`open ${dashboardUrl}`, () => {});
      process.exit(0);
    }
    throw err;
  });

  server.listen(PORT, () => {
    console.log(`\n  ${c.bold}📎 Clippy Dashboard${c.reset}`);
    console.log(`  ${c.c}${dashboardUrl}${c.reset}\n`);
    exec(`open ${dashboardUrl}`, () => {});
  });
}

function cmdCleanup() {
  banner();
  ensureHome();

  console.log(`  ${c.bold}Removing clippy-guard hooks...${c.reset}\n`);

  if (!existsSync(CLAUDE_SETTINGS)) {
    console.log(`  ${c.dim}○${c.reset} Claude Code    ${c.dim}not installed${c.reset}`);
  } else {
    try {
      const settings = JSON.parse(readFileSync(CLAUDE_SETTINGS, 'utf-8'));
      if (settings.hooks) {
        delete settings.hooks;
        writeFileSync(CLAUDE_SETTINGS, JSON.stringify(settings, null, 2) + '\n');
        console.log(`  ${c.g}✓${c.reset} Claude Code    hook removed`);
      } else {
        console.log(`  ${c.dim}○${c.reset} Claude Code    ${c.dim}no hook found${c.reset}`);
      }
    } catch {
      console.log(`  ${c.r}✗${c.reset} Claude Code    ${c.dim}failed to read settings${c.reset}`);
    }
  }

  // Clear log
  if (existsSync(LOG_FILE)) {
    const lines = readFileSync(LOG_FILE, 'utf-8').trim().split('\n').filter(Boolean).length;
    writeFileSync(LOG_FILE, '');
    console.log(`\n  ${c.g}✓${c.reset} Cleared activity log (${lines} entries)`);
  }

  console.log(`\n  ${c.bold}Cleanup complete.${c.reset}`);
  console.log(`  ${c.dim}Rules and config kept at ${CLIPPY_HOME}${c.reset}`);
  console.log(`  ${c.dim}To remove everything: rm -rf ${CLIPPY_HOME}${c.reset}\n`);
}

// ─── Main ──────────────────────────────────────────────
const [cmd, ...args] = process.argv.slice(2);

switch (cmd) {
  case 'init':      await cmdInit(); break;
  case 'status':    cmdStatus(); break;
  case 'rules':     cmdRules(); break;
  case 'log':       cmdLog(parseInt(args[0]) || 20); break;
  case 'dashboard': cmdDashboard(); break;
  case 'cleanup':   cmdCleanup(); break;
  default:
    banner();
    console.log(`  ${c.bold}Usage:${c.reset} clippy-guard <command>\n`);
    console.log(`  ${c.bold}Commands:${c.reset}`);
    console.log(`    init            Detect AI tools and install hooks`);
    console.log(`    status          Show hook status and stats`);
    console.log(`    rules           List active rules`);
    console.log(`    log [count]     Show recent activity`);
    console.log(`    dashboard       Open web dashboard`);
    console.log(`    cleanup         Remove hooks and clear activity log`);
    console.log('');
}
