<div align="center">

<img src="docs/images/icon.png" width="128" alt="Tuuli icon">

# Tuuli

**Temperatures in the menu bar and fan control for your Mac. Free and open source.**

[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black?logo=apple)](#requirements)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)](Package.swift)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue)](https://www.gnu.org/licenses/gpl-3.0.html)
[![Latest release](https://img.shields.io/github/v/release/gabry-ts/tuuli)](https://github.com/gabry-ts/tuuli/releases)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/overview-dark.png">
  <img src="docs/screenshots/overview-light.png" alt="Tuuli overview with temperatures, fans and history" width="720">
</picture>

</div>

## Features

- Sensors found automatically on any Apple Silicon Mac
- Fan modes: System, Auto Boost rules, a draggable Curve, Manual and your own
- Menu bar readings and a popover with a mode picker and speed slider
- History, alerts and CSV logging
- Fail-safe: fans return to macOS if Tuuli quits, crashes or the Mac sleeps
- Automatic updates via Sparkle

## Install

```sh
brew install --cask gabry-ts/tap/tuuli
```

Or download the latest `.dmg` from [Releases](https://github.com/gabry-ts/tuuli/releases). Tuuli keeps itself up to date after that.

## Requirements

macOS 26 or later, built and tested on Apple Silicon (Intel support is experimental); an admin password once, to install the fan control helper.

## Build from source

```sh
./scripts/build.sh   # build/Tuuli.app
open build/Tuuli.app
```

## Privacy

Settings and logs stay on your Mac; the only network access is the update check, which you can turn off in Settings.

## Support

Tuuli is free. If it keeps your Mac cool, you can [buy me a coffee](https://buymeacoffee.com/gabrielepartiti).

## License

GNU General Public License v3.0. Copyright (C) 2026 Gabriele Partiti.
