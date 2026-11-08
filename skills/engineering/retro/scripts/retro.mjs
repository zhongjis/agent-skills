#!/usr/bin/env node
// Interactive retro helper. Node standard library only.
//
//   retro.mjs render <dir>             validate <dir>/findings.json, write <dir>/retro.html
//   retro.mjs serve <dir>              start the localhost helper (detached); print {url, port, pid}
//   retro.mjs poll <dir> [--timeout S] wait for the next decision batch; print it as JSON
//   retro.mjs stop <dir>               stop the helper
//
// The page POSTs a batch to /decisions; the helper appends it to <dir>/decisions.jsonl.
// poll prints the oldest batch after <dir>/decisions.ack and advances the ack, so a
// helper or agent restart replays unhandled batches. render triggers a live reload.

import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { appendFileSync, existsSync, readFileSync, statSync, unlinkSync, watch, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const TEMPLATE = join(here, '..', 'assets', 'template.html');
const MARK = '__RETRO_DATA__';

const [cmd, dirArg, ...rest] = process.argv.slice(2);
const fail = (msg, code = 1) => { process.stderr.write(`retro: ${msg}\n`); process.exit(code); };
if (!cmd || !dirArg) fail('usage: retro.mjs <render|serve|poll|stop> <dir> [--timeout S]');
const dir = resolve(dirArg);
const file = (name) => join(dir, name);
const out = (value) => process.stdout.write(`${JSON.stringify(value)}\n`);

// ---------- validation (mirrors schemas/findings.schema.json) ----------
function validate(data) {
  const errors = [];
  const str = (v, path, required = true) => {
    if (v === undefined) { if (required) errors.push(`${path} is required`); return; }
    if (typeof v !== 'string' || (required && !v.trim())) errors.push(`${path} must be a non-empty string`);
  };
  const oneOf = (v, path, values, required = true) => {
    if (v === undefined && !required) return;
    if (!values.includes(v)) errors.push(`${path} must be one of ${values.join(', ')}`);
  };
  const strArray = (v, path) => {
    if (v === undefined) return;
    if (!Array.isArray(v) || v.some((x) => typeof x !== 'string')) errors.push(`${path} must be an array of strings`);
  };
  const onlyKeys = (obj, path, keys) => {
    for (const k of Object.keys(obj)) if (!keys.includes(k)) errors.push(`${path}.${k} is not allowed`);
  };
  if (!data || typeof data !== 'object' || Array.isArray(data)) return ['root must be an object'];
  onlyKeys(data, 'root', ['$schema', 'title', 'intro', 'steering', 'handoff', 'findings']);
  str(data.title, 'title'); str(data.intro, 'intro'); str(data.handoff, 'handoff', false);
  strArray(data.steering, 'steering');
  if (!Array.isArray(data.findings) || !data.findings.length) { errors.push('findings must be a non-empty array'); return errors; }
  const ids = new Set();
  data.findings.forEach((f, i) => {
    const p = `findings[${i}]`;
    if (!f || typeof f !== 'object') { errors.push(`${p} must be an object`); return; }
    onlyKeys(f, p, ['id', 'title', 'severity', 'category', 'scope', 'status', 'cost', 'happened', 'why', 'fix', 'visuals', 'owner', 'stage', 'evidence', 'rec', 'thread', 'rev', 'outcome']);
    if (typeof f.id !== 'string' || !/^[a-z0-9-]+$/.test(f.id)) errors.push(`${p}.id must match ^[a-z0-9-]+$`);
    else if (ids.has(f.id)) errors.push(`${p}.id "${f.id}" is duplicated`);
    else ids.add(f.id);
    for (const k of ['title', 'category', 'happened', 'why', 'fix', 'owner']) str(f[k], `${p}.${k}`);
    for (const k of ['cost', 'stage', 'rec', 'outcome']) str(f[k], `${p}.${k}`, false);
    if (f.visuals !== undefined) {
      if (!f.visuals || typeof f.visuals !== 'object' || Array.isArray(f.visuals)) errors.push(`${p}.visuals must be an object`);
      else {
        onlyKeys(f.visuals, `${p}.visuals`, ['happened', 'why', 'fix']);
        for (const [section, v] of Object.entries(f.visuals)) {
          const vp = `${p}.visuals.${section}`;
          if (!v || typeof v !== 'object') { errors.push(`${vp} must be an object`); continue; }
          onlyKeys(v, vp, ['kind', 'body', 'caption']);
          oneOf(v.kind, `${vp}.kind`, ['diff', 'tree', 'code', 'log']);
          str(v.body, `${vp}.body`); str(v.caption, `${vp}.caption`, false);
        }
      }
    }
    oneOf(f.severity, `${p}.severity`, ['high', 'med', 'low']);
    oneOf(f.scope, `${p}.scope`, ['Repo proposal', 'Personal edit', 'Owner decision']);
    oneOf(f.status, `${p}.status`, ['gap', 'proposal', 'mostly', 'covered']);
    if (!Number.isInteger(f.rev) || f.rev < 1) errors.push(`${p}.rev must be an integer >= 1`);
    strArray(f.evidence, `${p}.evidence`);
    if (f.thread !== undefined) {
      if (!Array.isArray(f.thread)) errors.push(`${p}.thread must be an array`);
      else f.thread.forEach((m, j) => {
        if (!m || typeof m !== 'object') { errors.push(`${p}.thread[${j}] must be an object`); return; }
        onlyKeys(m, `${p}.thread[${j}]`, ['who', 'text']);
        oneOf(m.who, `${p}.thread[${j}].who`, ['agent', 'user']);
        str(m.text, `${p}.thread[${j}].text`);
      });
    }
  });
  return errors;
}

function render() {
  let data;
  try { data = JSON.parse(readFileSync(file('findings.json'), 'utf8')); }
  catch (e) { fail(`cannot read ${file('findings.json')}: ${e.message}`); }
  const errors = validate(data);
  if (errors.length) fail(`findings.json is invalid:\n  - ${errors.join('\n  - ')}`);
  // High, then medium, then low. Stable: the author's order within a severity is kept.
  const rank = { high: 0, med: 1, low: 2 };
  data.findings.sort((a, b) => rank[a.severity] - rank[b.severity]);
  const json = JSON.stringify(data).replace(/</g, '\\u003c')
    .split(String.fromCharCode(0x2028)).join('\\u2028').split(String.fromCharCode(0x2029)).join('\\u2029');
  const template = readFileSync(TEMPLATE, 'utf8');
  if (!template.includes(MARK)) fail(`template is missing ${MARK}`);
  writeFileSync(file('retro.html'), template.replace(MARK, () => json));
  out({ ok: true, html: file('retro.html'), findings: data.findings.length });
}

// ---------- helper server ----------
function readServer() {
  try { return JSON.parse(readFileSync(file('server.json'), 'utf8')); } catch { return null; }
}
function alive(pid) { try { process.kill(pid, 0); return true; } catch { return false; } }

function serveDetached() {
  if (!existsSync(file('retro.html'))) fail(`run render first: ${file('retro.html')} is missing`);
  const running = readServer();
  if (running && alive(running.pid)) { out({ ok: true, reused: true, ...running }); return; }
  try { unlinkSync(file('server.json')); } catch {}
  const child = spawn(process.execPath, [fileURLToPath(import.meta.url), 'serve-foreground', dir], { detached: true, stdio: 'ignore' });
  child.unref();
  const started = Date.now();
  const wait = () => {
    const s = readServer();
    if (s) { out({ ok: true, ...s }); return; }
    if (Date.now() - started > 5000) fail('helper did not start within 5 s');
    setTimeout(wait, 100);
  };
  wait();
}

function serveForeground() {
  const clients = new Set();
  const server = createServer((req, res) => {
    const url = new URL(req.url, 'http://localhost');
    if (req.method === 'GET' && (url.pathname === '/' || url.pathname === '/retro.html')) {
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
      res.end(readFileSync(file('retro.html')));
    } else if (req.method === 'GET' && url.pathname === '/health') {
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ ok: true, pending: pendingBatches().length }));
    } else if (req.method === 'GET' && url.pathname === '/events') {
      res.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-store', connection: 'keep-alive' });
      res.write('retry: 2000\n\n');
      clients.add(res);
      req.on('close', () => clients.delete(res));
    } else if (req.method === 'POST' && url.pathname === '/decisions') {
      let body = '';
      req.on('data', (c) => { body += c; if (body.length > 1e6) req.destroy(); });
      req.on('end', () => {
        let batch;
        try { batch = JSON.parse(body); } catch { res.writeHead(400); res.end('invalid JSON'); return; }
        if (!batch || typeof batch.decisions !== 'object') { res.writeHead(400); res.end('missing decisions'); return; }
        const seq = lastSeq() + 1;
        appendFileSync(file('decisions.jsonl'), `${JSON.stringify({ seq, at: new Date().toISOString(), decisions: batch.decisions })}\n`);
        res.writeHead(200, { 'content-type': 'application/json' });
        res.end(JSON.stringify({ ok: true, seq }));
      });
    } else { res.writeHead(404); res.end(); }
  });
  let timer;
  watch(dir, (_event, name) => {
    if (name !== 'retro.html') return;
    clearTimeout(timer);
    timer = setTimeout(() => { for (const c of clients) c.write('event: reload\ndata: {}\n\n'); }, 150);
  });
  setInterval(() => { for (const c of clients) c.write(': ping\n\n'); }, 20000).unref();
  server.listen(0, '127.0.0.1', () => {
    const { port } = server.address();
    writeFileSync(file('server.json'), JSON.stringify({ url: `http://127.0.0.1:${port}/`, port, pid: process.pid }));
  });
  const shutdown = () => { try { unlinkSync(file('server.json')); } catch {} process.exit(0); };
  process.on('SIGTERM', shutdown); process.on('SIGINT', shutdown);
}

// ---------- decision batches ----------
function batches() {
  if (!existsSync(file('decisions.jsonl'))) return [];
  return readFileSync(file('decisions.jsonl'), 'utf8').split('\n').filter(Boolean).map((l) => JSON.parse(l));
}
function lastSeq() { const b = batches(); return b.length ? b[b.length - 1].seq : 0; }
function acked() { try { return Number(readFileSync(file('decisions.ack'), 'utf8')) || 0; } catch { return 0; } }
function pendingBatches() { const a = acked(); return batches().filter((b) => b.seq > a); }

function poll() {
  const i = rest.indexOf('--timeout');
  const timeoutMs = (i >= 0 ? Number(rest[i + 1]) : 600) * 1000;
  const started = Date.now();
  const tick = () => {
    const [next] = pendingBatches();
    if (next) {
      writeFileSync(file('decisions.ack'), String(next.seq));
      out({ type: 'decisions', ...next });
      return;
    }
    if (Date.now() - started >= timeoutMs) { out({ type: 'timeout', waitedSeconds: Math.round(timeoutMs / 1000) }); process.exit(2); }
    setTimeout(tick, 500);
  };
  tick();
}

function stop() {
  const s = readServer();
  if (!s) { out({ ok: true, running: false }); return; }
  if (alive(s.pid)) process.kill(s.pid, 'SIGTERM');
  try { unlinkSync(file('server.json')); } catch {}
  out({ ok: true, stopped: s.pid });
}

if (!existsSync(dir) || !statSync(dir).isDirectory()) fail(`${dir} is not a directory`);
({ render, serve: serveDetached, 'serve-foreground': serveForeground, poll, stop }[cmd] ?? (() => fail(`unknown command ${cmd}`)))();
