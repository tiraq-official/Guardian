/* ==========================================================================
   Guardian - WebUI logic
   Talks to the module through the KernelSU / APatch / WebUI X `ksu` bridge.
   When opened in a plain browser (no bridge) it runs on a local mock so the
   UI can be previewed without a rooted device.
   ========================================================================== */
'use strict';

var MOD = '/data/adb/modules/saptak_guardian';
var CATS = ['ads', 'gambling', 'porn'];

var MOCK = !(window.ksu && typeof window.ksu.exec === 'function');
var blockedShown = 0;
var busy = false;

/* ---------------- bridge ---------------- */
function sh(cmd) {
  if (window.ksu && typeof window.ksu.exec === 'function') {
    // 1) synchronous form -> returns stdout string
    try {
      var r = window.ksu.exec(cmd);
      if (typeof r === 'string') return Promise.resolve(r);
      if (r && typeof r.then === 'function') {
        return r.then(function (v) { return (v && v.stdout) || (typeof v === 'string' ? v : ''); });
      }
      if (r && typeof r === 'object') return Promise.resolve(r.stdout || '');
    } catch (e) { /* fall through to async form */ }
    // 2) asynchronous form -> ksu.exec(cmd, callbackName)
    return new Promise(function (resolve) {
      var name = '__gcb' + Math.random().toString(36).slice(2);
      window[name] = function (code, stdout) {
        resolve(stdout || '');
        try { delete window[name]; } catch (e) {}
      };
      try { window.ksu.exec(cmd, name); } catch (e) { resolve(''); }
    });
  }
  return Promise.resolve('');
}

/* ---------------- mock (browser preview only) ---------------- */
function mockApi(action) {
  var st;
  try { st = JSON.parse(localStorage.getItem('guardian') || 'null'); } catch (e) { st = null; }
  if (!st) st = { master: 1, ads: 1, gambling: 1, porn: 1, blocked: 502831, active: true, updated: '2026-11-15', warn: '' };

  var p = String(action).trim().split(/\s+/);
  if (p[0] === 'set') {
    for (var i = 1; i + 1 < p.length; i += 2) st[p[i]] = parseInt(p[i + 1], 10);
  } else if (p[0] === 'update') {
    st.updated = new Date().toISOString().slice(0, 10);
  }
  st.master = st.master ? 1 : 0;
  st.ads = st.ads ? 1 : 0;
  st.gambling = st.gambling ? 1 : 0;
  st.porn = st.porn ? 1 : 0;
  st.active = st.master === 1;
  st.blocked = st.master === 1 ? 502831 : 0;
  st.warn = '';
  localStorage.setItem('guardian', JSON.stringify(st));
  return st;
}

function api(action) {
  if (MOCK) return new Promise(function (r) { setTimeout(function () { r(mockApi(action)); }, 200); });
  return sh('sh ' + MOD + '/scripts/webui.sh ' + action).then(function (out) {
    var lines = (out || '').trim().split('\n').filter(Boolean);
    try { return JSON.parse(lines[lines.length - 1] || ''); } catch (e) { return null; }
  });
}

/* ---------------- rendering ---------------- */
function blockEl(key) { return document.querySelector('.block[data-key="' + key + '"]'); }

function setBlock(key, on) {
  var el = blockEl(key);
  if (el) el.classList.toggle('selected', !!on);
}

function countUp(el, target, suffix) {
  var from = blockedShown, to = Number(target) || 0;
  var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (reduce || from === to) {
    blockedShown = to;
    el.textContent = to.toLocaleString() + suffix;
    return;
  }
  var start = null, dur = 600;
  function step(ts) {
    if (start === null) start = ts;
    var p = Math.min(1, (ts - start) / dur);
    var eased = 1 - Math.pow(1 - p, 3);
    var v = Math.round(from + (to - from) * eased);
    el.textContent = v.toLocaleString() + suffix;
    if (p < 1) requestAnimationFrame(step); else blockedShown = to;
  }
  requestAnimationFrame(step);
}

function render(st) {
  var warnBox = document.getElementById('warnBox');

  if (!st) {
    document.getElementById('protTitle').textContent = 'Module not reachable';
    document.getElementById('protSub').textContent = 'Open the module in your root manager';
    warnBox.classList.remove('show');
    return;
  }

  var paused = st.master !== 1;

  // protection card
  document.getElementById('sw-master').setAttribute('aria-checked', paused ? 'false' : 'true');
  document.body.classList.toggle('paused', paused);
  document.getElementById('protTitle').textContent = paused ? 'Protection is off' : 'Protection is on';

  var sub = document.getElementById('protSub');
  if (paused) {
    blockedShown = 0;
    sub.textContent = 'Blocking is paused';
  } else {
    countUp(sub, st.blocked, ' domains blocked');
  }

  // selection
  setBlock('ads', st.ads === 1);
  setBlock('gambling', st.gambling === 1);
  setBlock('porn', st.porn === 1);
  setBlock('all', st.ads === 1 && st.gambling === 1 && st.porn === 1);

  // warning (only when blocking should be on but is not)
  var broken = !paused && st.active === false;
  if (broken && st.warn) {
    document.getElementById('warnText').textContent = st.warn;
    warnBox.classList.add('show');
  } else {
    warnBox.classList.remove('show');
  }

  // bottom bar
  document.getElementById('listsInfo').textContent =
    st.updated && st.updated !== '-' ? 'Lists · ' + st.updated : 'Lists · —';
}

/* ---------------- snackbar ---------------- */
var toastTimer = null;
function toast(msg) {
  var s = document.getElementById('snackbar');
  s.textContent = msg;
  s.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(function () { s.classList.remove('show'); }, 2600);
}

/* ---------------- actions ---------------- */
function onMaster() {
  if (busy) return;
  var el = document.getElementById('sw-master');
  var next = el.getAttribute('aria-checked') === 'true' ? 0 : 1;
  el.setAttribute('aria-checked', next ? 'true' : 'false'); // optimistic
  busy = true;

  api('set master ' + next).then(function (st) {
    busy = false;
    if (st) render(st);
    else el.setAttribute('aria-checked', next ? 'false' : 'true');
  });
}

function onBlock(key) {
  if (busy || document.body.classList.contains('paused')) return;

  var cmd;
  if (key === 'all') {
    // "Block all" is derived: on only when all three are on.
    var v = blockEl('all').classList.contains('selected') ? 0 : 1;
    cmd = 'set ads ' + v + ' gambling ' + v + ' porn ' + v;
    setBlock('ads', v); setBlock('gambling', v); setBlock('porn', v); setBlock('all', v);
  } else {
    var next = blockEl(key).classList.contains('selected') ? 0 : 1;
    cmd = 'set ' + key + ' ' + next;
    setBlock(key, next);
    setBlock('all',
      blockEl('ads').classList.contains('selected') &&
      blockEl('gambling').classList.contains('selected') &&
      blockEl('porn').classList.contains('selected'));
  }

  busy = true;
  api(cmd).then(function (st) {
    busy = false;
    if (st) render(st);
  });
}

function runUpdate() {
  var b1 = document.getElementById('btnUpdate');
  var b2 = document.getElementById('btnRefresh');
  if (b1.disabled) return;

  b1.disabled = true;
  b2.disabled = true;
  var label = document.getElementById('updateLabel');
  var old = label.textContent;
  label.textContent = 'Updating…';
  toast('Updating blocklists…');

  api('update').then(function (st) {
    b1.disabled = false;
    b2.disabled = false;
    label.textContent = old;
    if (st) { render(st); toast('Blocklists updated'); }
    else { toast('Update failed — check your connection'); }
  });
}

/* ---------------- about sheet ---------------- */
function openSheet() {
  document.getElementById('scrim').classList.add('show');
  document.getElementById('sheet').classList.add('show');
}
function closeSheet() {
  document.getElementById('scrim').classList.remove('show');
  document.getElementById('sheet').classList.remove('show');
}

/* ---------------- boot ---------------- */
function boot() {
  try {
    if (typeof webui !== 'undefined' && typeof webui.isDarkMode === 'boolean') {
      document.documentElement.classList.toggle('host-dark', webui.isDarkMode);
    }
  } catch (e) {}

  document.getElementById('sw-master').addEventListener('click', onMaster);

  Array.prototype.forEach.call(document.querySelectorAll('.block'), function (el) {
    el.addEventListener('click', function () { onBlock(this.getAttribute('data-key')); });
  });

  document.getElementById('btnUpdate').addEventListener('click', runUpdate);
  document.getElementById('btnRefresh').addEventListener('click', runUpdate);
  document.getElementById('btnInfo').addEventListener('click', openSheet);
  document.getElementById('sheetClose').addEventListener('click', closeSheet);
  document.getElementById('scrim').addEventListener('click', closeSheet);

  api('status').then(render);
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', boot);
} else {
  boot();
}
