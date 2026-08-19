#!/usr/bin/env node
'use strict';

// paperlike-overlay CLI — macOS の紙化オーバーレイを管理する。
//   paper-overlay start | stop | toggle | on | off | status | build | install
// 初回 start でソースから .app をビルドし ~/Applications に配置して起動する。

const { execFileSync, spawnSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PKG_DIR = path.resolve(__dirname, '..');
const SRC_DIR = path.join(PKG_DIR, 'macos', 'PaperOverlay');
const APP_NAME = 'PaperOverlay.app';
const INSTALL_DIR = path.join(os.homedir(), 'Applications');
const INSTALLED_APP = path.join(INSTALL_DIR, APP_NAME);
const INSTALLED_BIN = path.join(INSTALLED_APP, 'Contents', 'MacOS', 'PaperOverlay');

function ensureMac() {
  if (process.platform !== 'darwin') {
    console.error('PaperOverlay は macOS 専用です。');
    process.exit(1);
  }
}
function has(cmd) {
  return spawnSync('which', [cmd], { stdio: 'ignore' }).status === 0;
}
function isRunning() {
  return spawnSync('pgrep', ['-x', 'PaperOverlay'], { stdio: 'ignore' }).status === 0;
}

function build() {
  ensureMac();
  if (!has('swiftc')) {
    console.error(
      'swiftc が見つかりません。Xcode Command Line Tools を入れてください:\n' +
      '  xcode-select --install'
    );
    process.exit(1);
  }
  console.log('▶ ソースからビルド中…（初回のみ）');
  execFileSync('bash', ['build-app.sh'], { cwd: SRC_DIR, stdio: 'inherit' });
}

function install() {
  build();
  fs.mkdirSync(INSTALL_DIR, { recursive: true });
  spawnSync('rm', ['-rf', INSTALLED_APP]);
  execFileSync('cp', ['-R', path.join(SRC_DIR, APP_NAME), INSTALLED_APP]);
  console.log('✅ インストール: ' + INSTALLED_APP);
}

function ensureInstalled() {
  if (!fs.existsSync(INSTALLED_BIN)) install();
}

function start() {
  ensureMac();
  ensureInstalled();
  execFileSync('open', [INSTALLED_APP]);
  console.log('✅ 起動しました（メニューバーに 📄）。⌘⌥P でオン/オフ。');
}

function send(arg) {
  ensureMac();
  if (!fs.existsSync(INSTALLED_BIN)) {
    console.error('未インストールです。先に `paper-overlay start` を実行してください。');
    process.exit(1);
  }
  execFileSync(INSTALLED_BIN, [arg]);
}

function stop() {
  if (isRunning()) { send('--quit'); console.log('■ 終了しました。'); }
  else console.log('（起動していません）');
}

function status() {
  console.log(isRunning() ? '● 稼働中（メニューバーに 📄）' : '○ 停止中');
}

function usage() {
  console.log(`paperlike-overlay — 画面を紙のような質感にして目の疲れを減らす (macOS)

使い方:
  paper-overlay start     起動（初回はビルド＆~/Applicationsへ配置）
  paper-overlay stop      終了
  paper-overlay toggle    オン/オフ切替
  paper-overlay on        オン
  paper-overlay off       オフ
  paper-overlay status    状態表示
  paper-overlay build     ビルドのみ
  paper-overlay install   ビルドして ~/Applications に配置

メニューバーの 📄 から強さ調整・プリセット・ログイン時起動、⌘⌥P で即オン/オフ。`);
}

const cmd = (process.argv[2] || '').toLowerCase();
switch (cmd) {
  case 'start':   start(); break;
  case 'stop':    stop(); break;
  case 'toggle':  send('--toggle'); break;
  case 'on':      send('--on'); break;
  case 'off':     send('--off'); break;
  case 'status':  status(); break;
  case 'build':   build(); break;
  case 'install': install(); break;
  case '':
  case '-h':
  case '--help':  usage(); break;
  default:
    console.error('不明なコマンド: ' + cmd + '\n');
    usage();
    process.exit(1);
}
