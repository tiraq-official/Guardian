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
  if (!st) st = { master: 1, ads: 1, gambling: 1, porn: 1, blocked: 503977, active: true, updated: '2026-10-17' };
  var p = action.split(/\s+/);
  if (p[0] === 'set') st[p[1]] = parseInt(p[2], 10);
  if (p[0] === 'update') st.updated = new Date().toISOString().slice(0, 10);
  st.active = st.master === 1;
  st.warn = st.warn || '';
  st.blocked = st.master === 1 ? 503977 : 0;
  localStorage.setItem('guardian', JSON.stringify(st));
  return st;
}

function api(action) {
  if (MOCK) return new Promise(function (r) { setTimeout(function () { r(mockApi(action)); }, 220); });
  return sh('sh ' + MOD + '/scripts/webui.sh ' + action).then(function (out) {
    var lines = (out || '').trim().split('\n').filter(Boolean);
    try { return JSON.parse(lines[lines.length - 1] || ''); } catch (e) { return null; }
  });
}

/* ---------------- rendering ---------------- */
function setSwitch(key, val) {
  var el = document.getElementById('sw-' + key);
  if (el) el.setAttribute('aria-checked', val ? 'true' : 'false');
}

function countUp(target) {
  var el = document.getElementById('blockedCount');
  var from = blockedShown, to = Number(target) || 0;
  var start = null, dur = 650;
  if (from === to) { el.textContent = to.toLocaleString(); return; }
  function step(ts) {
    if (start === null) start = ts;
    var p = Math.min(1, (ts - start) / dur);
    var eased = 1 - Math.pow(1 - p, 3);
    var v = Math.round(from + (to - from) * eased);
    el.textContent = v.toLocaleString();
    if (p < 1) requestAnimationFrame(step); else blockedShown = to;
  }
  requestAnimationFrame(step);
}

function render(st) {
  var warnBox = document.getElementById('warnBox');
  if (!st) {
    document.getElementById('stateText').textContent = 'Module not reachable';
    document.getElementById('stateDot').className = 'dot off';
    warnBox.classList.remove('show');
    return;
  }
  setSwitch('master', st.master);
  CATS.forEach(function (k) { setSwitch(k, st[k]); });

  var paused = st.master !== 1;
  var broken = !paused && st.active === false;
  document.body.classList.toggle('paused', paused);
  document.querySelector('.hero').classList.toggle('off', paused);

  var dot = document.getElementById('stateDot');
  dot.className = 'dot ' + (paused || broken ? 'off' : 'on');

  var text = 'Protection is on';
  if (paused) text = 'Protection is off';
  else if (broken) text = 'Not blocking';
  document.getElementById('stateText').textContent = text;

  if (broken && st.warn) {
    document.getElementById('warnText').textContent = st.warn;
    warnBox.classList.add('show');
  } else {
    warnBox.classList.remove('show');
  }

  countUp(st.blocked);

  var info = document.getElementById('updatedInfo');
  info.textContent = st.updated && st.updated !== '-' ? 'lists · ' + st.updated : '';
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

/* ---------------- progress ---------------- */
var busy = 0;
function progress(on) {
  busy += on ? 1 : -1;
  if (busy < 0) busy = 0;
  document.getElementById('progress').classList.toggle('on', busy > 0);
}

/* ---------------- actions ---------------- */
function onToggle(key, el) {
  if (el.classList.contains('busy')) return;
  var next = el.getAttribute('aria-checked') === 'true' ? 0 : 1;
  el.setAttribute('aria-checked', next ? 'true' : 'false'); // optimistic
  el.classList.add('busy');
  progress(true);

  api('set ' + key + ' ' + next).then(function (st) {
    el.classList.remove('busy');
    progress(false);
    if (st) {
      render(st);
    } else {
      el.setAttribute('aria-checked', next ? 'false' : 'true'); // revert
      toast("Couldn't update — is the module installed?");
    }
  });
}

function onUpdate(btn) {
  if (btn.disabled) return;
  btn.disabled = true;
  progress(true);
  toast('Updating blocklists…');
  api('update').then(function (st) {
    btn.disabled = false;
    progress(false);
    if (st) { render(st); toast('Blocklists updated'); }
    else { toast('Update failed — check your connection'); }
  });
}

/* ---------------- boot ---------------- */
function boot() {
  // dark mode hint from the host, if available
  try {
    if (typeof webui !== 'undefined' && typeof webui.isDarkMode === 'boolean') {
      document.documentElement.classList.toggle('host-dark', webui.isDarkMode);
    }
  } catch (e) {}

  // staggered entrance
  var reveal = document.querySelectorAll('.reveal');
  Array.prototype.forEach.call(reveal, function (el, i) { el.style.setProperty('--i', i); });
  requestAnimationFrame(function () {
    Array.prototype.forEach.call(reveal, function (el) { el.classList.add('in'); });
  });

  document.getElementById('sw-master').addEventListener('click', function () { onToggle('master', this); });
  CATS.forEach(function (k) {
    document.getElementById('sw-' + k).addEventListener('click', function () { onToggle(k, this); });
  });
  document.getElementById('btnUpdate').addEventListener('click', function () { onUpdate(this); });

  api('status').then(render);
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', boot);
} else {
  boot();
}
