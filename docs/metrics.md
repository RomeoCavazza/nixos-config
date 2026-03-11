# Metrics

## Why metrics help

Metrics are useful for:

- understanding repository size and language distribution
- tracking growth over time
- spotting documentation drift between code and docs

They should support the documentation, not replace it.

## Recommended metric categories

- lines of code by language
- number of modules
- number of configuration entry points
- number of scripts in `config/bin/`
- optional screenshots or diagram coverage for major subsystems

## Using cloc

[`cloc`](https://github.com/AlDanial/cloc) is a practical choice to count blank lines, comment lines, and source lines across many languages.

Example commands:

```bash
cloc .
cloc . --exclude-dir=.git,result,node_modules
cloc modules config home
cloc . --md --report-file docs/cloc-report.md
```

## Suggested reporting workflow

1. Run `cloc` at important milestones.
2. Save the output in a generated report file, not by hand.
3. Keep only stable, decision-useful summaries in the docs.

## Suggested future automation

- generate `docs/cloc-report.md` from `scripts/update-metrics.sh`
- add a pre-release checklist that refreshes metrics
- compare metrics between tagged versions when the repository evolves significantly

## Included helper script

The repository now includes:

```bash
./scripts/update-metrics.sh
```

This script:

- checks that `cloc` is available
- generates `docs/cloc-report.md`
- adds a few repository counters alongside the `cloc` output

## Important caveat

Line counts are descriptive, not proof of quality. They are useful for scale, not for correctness, maintainability, or architecture quality.
