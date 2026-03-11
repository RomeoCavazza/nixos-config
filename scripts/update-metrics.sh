#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
report_path="${1:-${repo_root}/docs/cloc-report.md}"

if ! command -v cloc >/dev/null 2>&1; then
  echo "Error: cloc is required to generate metrics." >&2
  echo "Install it from https://github.com/AlDanial/cloc or your package manager." >&2
  exit 1
fi

tmp_report="$(mktemp)"
trap 'rm -f "${tmp_report}"' EXIT

count_files() {
  local target="$1"
  local glob="$2"

  if [ ! -d "${target}" ]; then
    echo 0
    return
  fi

  rg --files "${target}" -g "${glob}" | wc -l | tr -d ' '
}

module_count="$(count_files "${repo_root}/modules" "*.nix")"
script_count="$(count_files "${repo_root}/config/bin" "*")"
doc_count="$(count_files "${repo_root}/docs" "*.md")"
generated_at="$(date -u '+%Y-%m-%d %H:%M:%SZ')"

cloc "${repo_root}" \
  --exclude-dir=.git,node_modules,result,.direnv \
  --md \
  --report-file "${tmp_report}" \
  >/dev/null

cat > "${report_path}" <<EOF
# Code Metrics

Generated at: \`${generated_at}\`

## Repository counters

- Nix modules in \`modules/\`: ${module_count}
- Helper scripts in \`config/bin/\`: ${script_count}
- Markdown documents in \`docs/\`: ${doc_count}

## cloc report

$(<"${tmp_report}")
EOF

echo "Metrics report written to ${report_path}"
