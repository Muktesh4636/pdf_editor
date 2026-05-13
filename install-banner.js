/**
 * Suggest installing PDF Forge as an app (PWA). Install name comes from /manifest.json ("PDF Forge").
 * Home page (index): set window.PDF_FORGE_INSTALL_IMMEDIATE=1 before this script to show the bar immediately on load/reload.
 */
(function () {
  'use strict';

  var STORAGE_KEY = 'pdfForgeInstallDismissedUntil';
  var DISMISS_DAYS = 14;
  var APP_NAME = 'PDF Forge';
  var HOME_IMMEDIATE = !!window.PDF_FORGE_INSTALL_IMMEDIATE;

  function dismissed() {
    try {
      var t = parseInt(localStorage.getItem(STORAGE_KEY) || '0', 10);
      return t > Date.now();
    } catch (e) {
      return false;
    }
  }

  function dismiss() {
    try {
      localStorage.setItem(STORAGE_KEY, String(Date.now() + DISMISS_DAYS * 864e5));
    } catch (e) {}
    var el = document.getElementById('pdf-forge-install-banner');
    if (el) el.remove();
  }

  function isStandalone() {
    return (
      window.matchMedia('(display-mode: standalone)').matches ||
      window.navigator.standalone === true
    );
  }

  function isIosSafari() {
    var ua = navigator.userAgent || '';
    return /iPad|iPhone|iPod/.test(ua) && /WebKit/.test(ua) && !/CriOS|FxiOS|OPiOS/.test(ua);
  }

  var deferredPrompt = null;

  function mountBanner(opts) {
    if (document.getElementById('pdf-forge-install-banner')) return;
    if (dismissed() || isStandalone()) return;

    var bar = document.createElement('div');
    bar.id = 'pdf-forge-install-banner';
    bar.setAttribute('role', 'region');
    bar.setAttribute('aria-label', 'Install app');
    bar.style.cssText =
      'position:fixed;bottom:0;left:0;right:0;z-index:99999;' +
      'display:flex;flex-wrap:wrap;align-items:center;justify-content:center;gap:10px;padding:12px 16px;' +
      'background:linear-gradient(135deg,#1a1a2e 0%,#2d2d44 100%);color:#fff;font-family:system-ui,sans-serif;' +
      'font-size:14px;line-height:1.4;box-shadow:0 -4px 24px rgba(0,0,0,.25);border-top:3px solid #e84040;';

    var text = document.createElement('p');
    text.style.cssText = 'margin:0;flex:1;min-width:200px;max-width:520px;text-align:center;';
    text.textContent = opts.message;

    var btnInstall = document.createElement('button');
    btnInstall.type = 'button';
    btnInstall.textContent = opts.installLabel || 'Install';
    btnInstall.style.cssText =
      'background:#e84040;color:#fff;border:none;border-radius:8px;padding:10px 18px;font-weight:700;cursor:pointer;font-size:14px;';

    var btnLater = document.createElement('button');
    btnLater.type = 'button';
    btnLater.textContent = 'Not now';
    btnLater.style.cssText =
      'background:transparent;color:#cbd5e1;border:1px solid #64748b;border-radius:8px;padding:10px 14px;font-weight:600;cursor:pointer;font-size:13px;';

    btnLater.addEventListener('click', dismiss);

    if (opts.onInstallClick) {
      btnInstall.addEventListener('click', opts.onInstallClick);
    } else {
      btnInstall.style.display = 'none';
    }

    bar.appendChild(text);
    bar.appendChild(btnInstall);
    bar.appendChild(btnLater);
    document.body.appendChild(bar);
  }

  function registerSw() {
    if (!('serviceWorker' in navigator)) return Promise.resolve();
    return navigator.serviceWorker.register('/sw.js').catch(function () {});
  }

  function tryInstallOrHint() {
    if (deferredPrompt) {
      deferredPrompt.prompt();
      deferredPrompt.userChoice.finally(function () {
        deferredPrompt = null;
        dismiss();
      });
      return;
    }
    var t = document.querySelector('#pdf-forge-install-banner p');
    if (t) {
      t.textContent =
        'Use your browser menu: look for “Install app”, “Add to Home screen”, or “Install PDF Forge”. ' +
        'That pins this site — it is not a separate APK from an app store.';
    }
  }

  function mountHomeImmediate() {
    if (isIosSafari()) {
      mountBanner({
        message:
          'Add ' +
          APP_NAME +
          ' to your Home Screen: tap Share, then “Add to Home Screen”. Opens like an app.',
        installLabel: 'OK',
        onInstallClick: dismiss
      });
      return;
    }
    mountBanner({
      message:
        'Install ' +
        APP_NAME +
        ' for quick access — use the button below when your browser is ready, or the ⋮ menu → “Install app” / “Add to Home screen”. (Web install; not a Play Store APK.)',
      installLabel: 'Install ' + APP_NAME,
      onInstallClick: tryInstallOrHint
    });
  }

  if (isStandalone()) return;

  var softNudgeTimer = null;
  if (!HOME_IMMEDIATE) {
    softNudgeTimer = setTimeout(function () {
      if (dismissed() || isStandalone() || document.getElementById('pdf-forge-install-banner')) return;
      if (deferredPrompt) return;
      mountBanner({
        message:
          'Pin ' +
          APP_NAME +
          ' on your device: open the browser menu and choose “Install app” or “Add to Home screen” when your browser offers it.',
        installLabel: 'Got it',
        onInstallClick: dismiss
      });
    }, 10000);
  }

  window.addEventListener('beforeinstallprompt', function (e) {
    if (softNudgeTimer) clearTimeout(softNudgeTimer);
    e.preventDefault();
    deferredPrompt = e;
    var old = document.getElementById('pdf-forge-install-banner');
    if (old) old.remove();
    mountBanner({
      message:
        'Install ' +
        APP_NAME +
        ' for quick access from your home screen — opens like an app (from the browser; not a Play Store APK).',
      installLabel: 'Install ' + APP_NAME,
      onInstallClick: function () {
        if (!deferredPrompt) return;
        deferredPrompt.prompt();
        deferredPrompt.userChoice.finally(function () {
          deferredPrompt = null;
          dismiss();
        });
      }
    });
  });

  if (HOME_IMMEDIATE && !dismissed() && !isStandalone()) {
    mountHomeImmediate();
  }

  registerSw().then(function () {
    if (dismissed() || isStandalone()) return;
    if (HOME_IMMEDIATE) return;
    if (isIosSafari()) {
      if (softNudgeTimer) clearTimeout(softNudgeTimer);
      mountBanner({
        message:
          'Add ' +
          APP_NAME +
          ' to your Home Screen: tap the Share button, then “Add to Home Screen”.',
        installLabel: 'OK',
        onInstallClick: dismiss
      });
    }
  });
})();
