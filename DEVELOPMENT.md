# Development Guide

This document describes how to build, test, and contribute to GameEngineLib.

## Prerequisites

- macOS 14.0 or later
- Xcode 16.0 or later with Command Line Tools
- Swift 6.0 or later

## Building and Testing

```bash
# Build library targets
swift build

# Run deterministic test suite and soak tests
swift test

# Build release artifacts
swift build -c release
```

## Determinism and Quality Discipline

All simulations in GameEngineLib must remain 100% deterministic across platforms. Any changes to game physics or simulation state must produce reproducible bit-exact digests.

## Release Workflow

All releases follow semantic versioning incrementing by `0.0.1` per iteration on branch `feat/v<next-version>`.
