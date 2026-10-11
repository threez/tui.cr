# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Bumped the `ameba` development dependency from `~> 1.6` to `~> 1.7`.
- Restructured CI into separate `lint` (format check, ameba, compile check)
  and `test` (specs on Linux and macOS) jobs, with dependency caching.

### Fixed

- Resolved ameba 1.7 lint findings (`Lint/ElseNil`, `Lint/UnneededDisableDirective`,
  `Style/RedundantNilInControlExpression`, `Style/RedundantBegin`,
  `Style/HeredocIndent`) without changing any public API.
