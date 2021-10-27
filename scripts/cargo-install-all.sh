#!/usr/bin/env bash
#
# |cargo install| of the top-level crate will not install binaries for
# other workspace crates or native program crates.
here="$(dirname "$0")"
echo "here is : $here"
readlink_cmd="readlink"
echo "OSTYPE IS: $OSTYPE"

if [[ $OSTYPE == darwin* ]]; then
  # Mac OS X's version of `readlink` does not support the -f option,
  # But `greadlink` does, which you can get with `brew install coreutils`
  readlink_cmd="greadlink"
fi
cargo="$("${readlink_cmd}" -f "${here}/../cargo")"

set -e
echo "1"
usage() {
  exitcode=0
  if [[ -n "$1" ]]; then
    exitcode=1
    echo "Error: $*"
  fi
  cat <<EOF
usage: $0 [+<cargo version>] [--debug] [--validator-only] <install directory>
EOF
  exit $exitcode
}
echo "2"

maybeRustVersion=
installDir=
buildVariant=release
maybeReleaseFlag=--release
validatorOnly=
echo "3"
while [[ -n $1 ]]; do
  if [[ ${1:0:1} = - ]]; then
    if [[ $1 = --debug ]]; then
      maybeReleaseFlag=
      buildVariant=debug
      shift
      echo "4"
    elif [[ $1 = --validator-only ]]; then
      validatorOnly=true
      shift
      echo "5"
    else
      usage "Unknown option: $1"
      echo "6"
    fi
  elif [[ ${1:0:1} = \+ ]]; then
    maybeRustVersion=$1
    shift
    echo "7"
  else
    installDir=$1
    shift
    echo "8"
  fi
done

echo "10"
if [[ -z "$installDir" ]]; then
  usage "Install directory not specified"
  echo "9"
  exit 1
fi

echo "11"
installDir="$(mkdir -p "$installDir"; cd "$installDir"; pwd)"
mkdir -p "$installDir/bin/deps"

echo "12"
echo "Install location: $installDir ($buildVariant)"

echo "13"
cd "$(dirname "$0")"/..

SECONDS=0

export CI_OS_NAME="$(echo "$RUNNER_OS" | tr A-Z a-z)"
echo "CI_OS_NAME: $CI_OS_NAME"

echo "14"
if [[ $CI_OS_NAME = windows ]]; then
  # Limit windows to end-user command-line tools.  Full validator support is not
  # yet available on windows
  echo "14(b)"
  pwd
  ls
  BINS=(
    cargo-build-bpf
    cargo-test-bpf
    solana
    solana-install
    solana-install-init
    solana-keygen
    solana-stake-accounts
    solana-tokens
  )
else
  echo "15"
  pwd
  ls
  ./fetch-perf-libs.sh
  echo "19"
  BINS=(
    solana
    solana-bench-exchange
    solana-bench-tps
    solana-faucet
    solana-gossip
    solana-install
    solana-keygen
    solana-ledger-tool
    solana-log-analyzer
    solana-net-shaper
    solana-sys-tuner
    solana-validator
  )
  echo "20"
  # Speed up net.sh deploys by excluding unused binaries
  if [[ -z "$validatorOnly" ]]; then
    echo "20(b)"
    BINS+=(
      cargo-build-bpf
      cargo-test-bpf
      solana-dos
      solana-install-init
      solana-stake-accounts
      solana-stake-monitor
      solana-test-validator
      solana-tokens
      solana-watchtower
    )
  fi

  #XXX: Ensure `solana-genesis` is built LAST!
  # See https://github.com/solana-labs/solana/issues/5826
  BINS+=(solana-genesis)
fi

echo "17"
binArgs=()
for bin in "${BINS[@]}"; do
  binArgs+=(--bin "$bin")
done

mkdir -p "$installDir/bin"

echo "18"
(
  set -x
  # shellcheck disable=SC2086 # Don't want to double quote $rust_version
  echo "19"
  #cargo install cargo-update
  #"$cargo" $maybeRustVersion build $maybeReleaseFlag "${binArgs[@]}"
  echo "cargo is: $cargo"
  echo "maybeReleaseFlag is : $maybeReleaseFlag"
  "$cargo" build $maybeReleaseFlag "${binArgs[@]}"
  echo "20"
  # Exclude `spl-token` binary for net.sh builds
  if [[ -z "$validatorOnly" ]]; then
    # shellcheck disable=SC2086 # Don't want to double quote $rust_version
    echo "21"
    #"$cargo" $maybeRustVersion install spl-token-cli --root "$installDir"
    "$cargo" install spl-token-cli --root "$installDir"
  fi
)

echo "22"

echo "buildVariant is: $buildVariant"
echo "bin is: $bin"
echo "installDir is: $installDir"

echo "buildVariant/bin is: $buildVariant/$bin"

for bin in "${BINS[@]}"; do
  cp -fv "target/$buildVariant/$bin" "$installDir"/bin
done

echo "installDir is: $installDir"
echo "23"
if [[ -d target/perf-libs ]]; then
  cp -a target/perf-libs "$installDir"/bin/perf-libs
fi

echo "24"
mkdir -p "$installDir"/bin/sdk/bpf
cp -a sdk/bpf/* "$installDir"/bin/sdk/bpf
echo "25"
echo "installDir is: $installDir"

(
  set -x
  # deps dir can be empty
  shopt -s nullglob
  echo "26"
  for dep in target/"$buildVariant"/deps/libsolana*program.*; do
    echo "27"
    cp -fv "$dep" "$installDir/bin/deps"
    echo "28"
  done
)

echo "29"
echo "Done after $SECONDS seconds"
echo
echo "To use these binaries:"
echo "  export PATH=\"$installDir\"/bin:\"\$PATH\""
