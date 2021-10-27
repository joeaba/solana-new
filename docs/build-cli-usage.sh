#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"
cargo=../cargo

# shellcheck source=ci/rust-version.sh
source ../ci/rust-version.sh stable

: "${rust_stable:=}" # Pacify shellcheck

usage=$("$cargo" stable -q run -p solana-cli -- -C ~/.foo --help | sed -e 's|'"$HOME"'|~|g' -e 's/[[:space:]]\+$//')
pwd
out=${1:-src/cli/usage.md}
pwd
cat src/cli/.usage.md.header > "$out"

section() {
  declare mark=${2:-"###"}
  declare section=$1
  read -r name rest <<<"$section"

  printf '%s %s
' "$mark" "$name"
  printf '```text
%s
```

' "$section"
}

section "$usage" >> "$out"
pwd
usage=$(sed -e '/^ \{5,\}/d' <<<"$usage")
pwd
in_subcommands=0
while read -r subcommand rest; do
  [[ $subcommand == "SUBCOMMANDS:" ]] && in_subcommands=1 && continue
  if ((in_subcommands)); then
      pwd
      section "$("$cargo" stable -q run -p solana-cli -- help "$subcommand" | sed -e 's|'"$HOME"'|~|g' -e 's/[[:space:]]\+$//')" "####" >> "$out"
      pwd
  fi
done <<<"$usage">>"$out"
