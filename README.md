<div align="center">

<img src="docs/images/icon.png" width="128" alt="Tuuli icon">

# Tuuli

**Temperatures in the menu bar and fan control for Apple Silicon Macs. Free and open source.**

[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black?logo=apple)](#install)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)](Package.swift)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue)](https://www.gnu.org/licenses/gpl-3.0.html)
[![Latest release](https://img.shields.io/github/v/release/gabry-ts/tuuli)](https://github.com/gabry-ts/tuuli/releases)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/overview-dark.png">
  <img src="docs/screenshots/overview-light.png" alt="Tuuli overview with temperatures, fans and history" width="720">
</picture>

</div>

## Features

- **Sensors**: found automatically on any Apple Silicon Mac, with CPU, GPU, SSD and battery summaries.
- **Fan modes**: System, Auto Boost rules, a draggable Curve and Manual, plus your own named modes, with separate settings on battery.
- **Menu bar**: pick and order the readings, and a popover with a mode picker and manual speed slider.
- **History, alerts and CSV logging.**
- **Fail-safe**: fans go back to macOS when Tuuli quits, crashes, stops responding or the Mac sleeps.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/mode-dark.png">
    <img src="docs/screenshots/mode-light.png" alt="Auto Boost mode" width="560">
  </picture>
  &nbsp;
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/popover-dark.png">
    <img src="docs/screenshots/popover-light.png" alt="Menu bar popover" width="220">
  </picture>
</p>

## Requirements

- An Apple Silicon Mac with macOS 26 or later.
- An administrator password, once, to install the fan control helper. Monitoring works without it.

## Install

1. Download the latest `Tuuli-<version>.dmg` from [Releases](https://github.com/gabry-ts/tuuli/releases) and drag the app to Applications.
2. Tuuli is signed with a local Apple Development identity and not notarized, so Gatekeeper blocks the first launch:
   - Open the app once, then go to **System Settings > Privacy & Security** and click **Open Anyway**.
   - Or remove the quarantine flag from Terminal: `xattr -dr com.apple.quarantine /Applications/Tuuli.app`
3. Launch Tuuli. A short welcome walks you through the fan control helper and a starting mode.

## How fan control works

- Writing fan speeds needs root, so **Install Helper…** adds a small daemon under `/Library/PrivilegedHelperTools` and `/Library/LaunchDaemons`.
- It only accepts Tuuli signed by the same team, only sets fan speeds, and hands them back to macOS if the app goes quiet for 10 seconds.
- Settings live in `~/Library/Application Support/Tuuli/settings.json`. No network access, no analytics, no account.

## Build from source

Requires Xcode (or the Command Line Tools) with Swift 6.2.

```sh
./scripts/build.sh      # build/Tuuli.app
open build/Tuuli.app
./scripts/make-dmg.sh   # build/Tuuli-<version>.dmg
swift test              # core tests
```

Set `TUULI_SIGN_IDENTITY` to sign with your own identity.

## Uninstall

In **General**, click **Uninstall Helper…**, then quit Tuuli and remove it from `/Applications`. Delete `~/Library/Application Support/Tuuli` to also clear its settings.

## Privacy

- Settings and logs stay on your Mac.
- No network access, no analytics, no account, no server.

## License

Copyright (C) 2026 Gabriele Partiti

Tuuli is free software, released under the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html).
