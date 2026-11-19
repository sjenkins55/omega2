#!/usr/bin/env node
/**
 * ConcertoCare EMR driver — headless Puppeteer smoke tester.
 * Usage:  node driver.mjs [command] [--out /tmp] [--url http://localhost:3000]
 *
 * Commands:
 *   smoke        Login + screenshot dashboard, patients, schedule, engagement (default)
 *   login        Just verify login returns a JWT and /me succeeds
 *   screenshot   Navigate to URL given by --page, save screenshot
 *   patients     Fetch patient list via API, print count
 *   visit        Open first scheduled visit page, screenshot
 *
 * Env / flags:
 *   --url    web base URL     (default: http://localhost:3000)
 *   --api    api base URL     (default: http://localhost:8000/api/v1)
 *   --email  admin email      (default: admin@concertocare.com)
 *   --pass   admin password   (default: ConcertoDemo1!)
 *   --out    screenshot dir   (default: /tmp)
 *   --page   URL for screenshot command
 *   CHROME   env var or auto-detected path to Chrome binary
 */
// puppeteer installed globally at /opt/node22/lib/node_modules/puppeteer
// ESM bare-specifier resolution doesn't follow NODE_PATH, so use the absolute path
import puppeteer from '/opt/node22/lib/node_modules/puppeteer/lib/puppeteer/puppeteer.js';
import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

// ─── Config ──────────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const get = (flag, def) => { const i = args.indexOf(flag); return i >= 0 ? args[i+1] : def; };
const CMD   = args.find(a => !a.startsWith('--')) ?? 'smoke';
const BASE  = get('--url',   'http://localhost:3000');
const API   = get('--api',   'http://localhost:8000/api/v1');
const EMAIL = get('--email', 'admin@concertocare.com');
const PASS  = get('--pass',  'ConcertoDemo1!');
const OUTDIR= get('--out',   '/tmp');
const PAGE  = get('--page',  null);

// Auto-detect Chrome binary
function findChrome() {
  const candidates = [
    process.env.CHROME,
    '/root/.cache/puppeteer/chrome/linux-149.0.7827.22/chrome-linux64/chrome',
    '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
    '/usr/bin/chromium-browser',
    '/usr/bin/chromium',
    '/usr/bin/google-chrome',
  ];
  for (const c of candidates) {
    if (c && fs.existsSync(c)) return c;
  }
  throw new Error('No Chrome binary found. Set CHROME env var or install chromium-browser.');
}

// ─── API helpers (no browser needed) ─────────────────────────────────────────
async function apiLogin() {
  const res = await fetch(`${API}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: EMAIL, password: PASS }),
  });
  if (!res.ok) throw new Error(`Login failed: ${res.status} ${await res.text()}`);
  const { access_token } = await res.json();
  return access_token;
}

async function apiGet(token, path) {
  const res = await fetch(`${API}${path}`, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) throw new Error(`GET ${path} failed: ${res.status}`);
  return res.json();
}

// ─── Browser helpers ──────────────────────────────────────────────────────────
async function launch() {
  const executablePath = findChrome();
  const browser = await puppeteer.launch({
    executablePath,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
    headless: true,
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 800 });
  return { browser, page };
}

async function browserLogin(page) {
  await page.goto(`${BASE}/login`, { waitUntil: 'networkidle2' });
  await page.type('input[type="email"]', EMAIL);
  await page.type('input[type="password"]', PASS);
  await Promise.all([
    page.click('button[type="submit"]'),
    page.waitForNavigation({ waitUntil: 'networkidle2', timeout: 15000 }).catch(() => {}),
  ]);
  await new Promise(r => setTimeout(r, 1500));
  const url = page.url();
  if (!url.includes('/dashboard') && !url.includes('/patients') && !url.includes('/schedule')) {
    throw new Error(`Login did not redirect to app (stayed at ${url})`);
  }
}

async function ss(page, name) {
  const p = path.join(OUTDIR, `${name}.png`);
  await page.screenshot({ path: p, fullPage: false });
  console.log(`  screenshot → ${p}`);
  return p;
}

// ─── Commands ─────────────────────────────────────────────────────────────────
async function cmdLogin() {
  console.log('Testing API login...');
  const token = await apiLogin();
  const me = await apiGet(token, '/auth/me');
  console.log(`  OK: ${me.email} (${me.role})`);
}

async function cmdPatients() {
  const token = await apiLogin();
  const data = await apiGet(token, '/patients?limit=5');
  console.log(`  Patients: ${data.total} total, first: ${data.patients[0]?.last_name}, ${data.patients[0]?.first_name}`);
}

async function cmdSmoke() {
  console.log('Running smoke test...');
  const { browser, page } = await launch();
  try {
    console.log('  Logging in...');
    await browserLogin(page);
    await ss(page, 'dashboard');

    console.log('  Patients page...');
    await page.goto(`${BASE}/patients`, { waitUntil: 'networkidle2' });
    await new Promise(r => setTimeout(r, 1500));
    await ss(page, 'patients');

    console.log('  Schedule page...');
    await page.goto(`${BASE}/schedule`, { waitUntil: 'networkidle2' });
    await new Promise(r => setTimeout(r, 1500));
    await ss(page, 'schedule');

    console.log('  Engagement page...');
    await page.goto(`${BASE}/engagement`, { waitUntil: 'networkidle2' });
    await new Promise(r => setTimeout(r, 1500));
    await ss(page, 'engagement');

    console.log('Smoke test passed.');
  } finally {
    await browser.close();
  }
}

async function cmdScreenshot() {
  if (!PAGE) throw new Error('--page required for screenshot command');
  const { browser, page } = await launch();
  try {
    await browserLogin(page);
    await page.goto(PAGE.startsWith('http') ? PAGE : `${BASE}${PAGE}`, { waitUntil: 'networkidle2' });
    await new Promise(r => setTimeout(r, 1500));
    const name = PAGE.replace(/[^a-z0-9]/gi, '_').replace(/^_+|_+$/g, '') || 'page';
    await ss(page, name);
  } finally {
    await browser.close();
  }
}

async function cmdVisit() {
  const token = await apiLogin();
  const visits = await apiGet(token, '/visits?status=scheduled&limit=1');
  if (!visits.length) { console.log('No scheduled visits found.'); return; }
  const v = visits[0];
  const { browser, page } = await launch();
  try {
    await browserLogin(page);
    await page.goto(`${BASE}/visits/${v.id}`, { waitUntil: 'networkidle2' });
    await new Promise(r => setTimeout(r, 2000));
    await ss(page, 'visit-detail');
    console.log(`  Opened visit ${v.id}`);
  } finally {
    await browser.close();
  }
}

// ─── Dispatch ─────────────────────────────────────────────────────────────────
const CMDS = { smoke: cmdSmoke, login: cmdLogin, patients: cmdPatients, screenshot: cmdScreenshot, visit: cmdVisit };
if (!CMDS[CMD]) { console.error(`Unknown command: ${CMD}\nAvailable: ${Object.keys(CMDS).join(', ')}`); process.exit(1); }
CMDS[CMD]().catch(err => { console.error('Error:', err.message); process.exit(1); });
