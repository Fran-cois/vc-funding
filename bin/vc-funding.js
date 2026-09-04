#!/usr/bin/env node

import { cpSync, existsSync, mkdirSync, rmSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const builtApp = join(root, ".build", "vc-funding.app");
const args = new Set(process.argv.slice(2));

if (args.has("--help") || args.has("-h")) {
  console.log(`vc-funding

Build and launch the private coding-agent usage monitor.

Usage:
  npx vc-funding             Build and launch
  npx vc-funding --install   Install to ~/Applications and launch
  npx vc-funding --build-only
  npx vc-funding --print-path`);
  process.exit(0);
}

if (process.platform !== "darwin") {
  console.error("vc-funding requires macOS 13 or newer.");
  process.exit(1);
}

const build = spawnSync("/bin/zsh", [join(root, "scripts", "build-app.sh")], {
  cwd: root,
  stdio: "inherit"
});
if (build.status !== 0) process.exit(build.status ?? 1);

let appToOpen = builtApp;
if (args.has("--install")) {
  const applications = join(homedir(), "Applications");
  appToOpen = join(applications, "vc-funding.app");
  mkdirSync(applications, { recursive: true });
  if (existsSync(appToOpen)) rmSync(appToOpen, { recursive: true });
  cpSync(builtApp, appToOpen, { recursive: true });
}

if (args.has("--print-path")) console.log(appToOpen);
if (args.has("--build-only") || args.has("--print-path")) process.exit(0);

const opened = spawnSync("/usr/bin/open", [appToOpen], { stdio: "inherit" });
process.exit(opened.status ?? 0);
