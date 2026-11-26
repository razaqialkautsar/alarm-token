#!/usr/bin/env bash
# Testnet wallet helper for nothief (PRD.md section 10, funding helpers). Tooling only, not part of the protection loop.
#
# Usage (from the repo root, in your own terminal):
#   bash scripts/wallet.sh            guided setup: .env, key, RPC check, balances, faucet steps
#   bash scripts/wallet.sh balance    show balances on Ethereum Sepolia, Base Sepolia, and Reactive Lasna
#   bash scripts/wallet.sh lreact     swap Sepolia ETH for lREACT through the Reactive faucet (asks before sending)
#
# Safety rules (CLAUDE.md sections 2.4 and 7):
# - Testnet only. Every RPC is checked against its expected chain ID before use.
# - The private key is written to .env (git-ignored) and never printed.
# - The lREACT faucet loses anything above 5 ETH per tx, so larger amounts are refused.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env}"
EXAMPLE_FILE="$ROOT/.env.example"

ETH_SEPOLIA_ID=11155111
BASE_SEPOLIA_ID=84532
LASNA_ID=5318007

# Reactive lREACT faucets (PRD.md section 20.1). 1 ETH = 100 lREACT. Max 5 ETH per tx; anything above is lost.
FAUCET_ETH_SEPOLIA=0x9b9BB25f1A81078C544C829c5EB7822d747Cf434
FAUCET_BASE_SEPOLIA=0x2afaFD298b23b62760711756088F75B7409f5967
FAUCET_MAX_ETH=5

bold() { printf '\n\033[1m%s\033[0m\n' "$*"; }
ok() { printf '  \033[32mOK\033[0m  %s\n' "$*"; }
warn() { printf '  \033[33m!!\033[0m  %s\n' "$*"; }
die() { printf '  \033[31mERROR\033[0m  %s\n' "$*" >&2; exit 1; }

require_cast() {
  command -v cast >/dev/null 2>&1 || die "Foundry 'cast' not found. Install Foundry: https://getfoundry.sh"
}

# Reads KEY from .env without sourcing the whole file. Strips CR (Windows line endings) and surrounding quotes.
env_get() {
  [ -f "$ENV_FILE" ] || return 0
  grep -E "^$1=" "$ENV_FILE" | tail -n1 | cut -d= -f2- | tr -d '\r' | sed -e 's/^"//' -e 's/"$//' || true
}

# Sets KEY=VALUE in .env, replacing an existing line or appending one.
env_set() {
  local key="$1" value="$2" tmp
  tmp="$(mktemp)"
  if grep -qE "^$key=" "$ENV_FILE"; then
    awk -v k="$key" -v v="$value" 'BEGIN{FS=OFS="="} $1==k {print k "=" v; next} {print}' "$ENV_FILE" >"$tmp"
  else
    cat "$ENV_FILE" >"$tmp"
    printf '%s=%s\n' "$key" "$value" >>"$tmp"
  fi
  mv "$tmp" "$ENV_FILE"
}

# Returns 0 when the RPC answers with the expected chain ID.
check_rpc() {
  local name="$1" url="$2" expected="$3" actual
  if [ -z "$url" ]; then
    warn "$name: no RPC URL set"
    return 1
  fi
  actual="$(cast chain-id --rpc-url "$url" 2>/dev/null || true)"
  if [ "$actual" = "$expected" ]; then
    ok "$name: chain ID $actual"
    return 0
  fi
  warn "$name: expected chain ID $expected, got '${actual:-no answer}'"
  return 1
}

address_from_env() {
  local key
  key="$(env_get PRIVATE_KEY)"
  [ -n "$key" ] || die "PRIVATE_KEY is empty in $ENV_FILE. Run: bash scripts/wallet.sh"
  cast wallet address --private-key "$key" 2>/dev/null || die "PRIVATE_KEY in $ENV_FILE is not a valid key"
}

show_balance() {
  local name="$1" url="$2" expected="$3" unit="$4" addr="$5" bal
  if [ -z "$url" ] || [ "$(cast chain-id --rpc-url "$url" 2>/dev/null || true)" != "$expected" ]; then
    warn "$name: RPC missing or wrong chain, skipped"
    return
  fi
  bal="$(cast balance "$addr" --ether --rpc-url "$url" 2>/dev/null || echo '?')"
  printf '  %-18s %s %s\n' "$name" "$bal" "$unit"
}

cmd_balance() {
  require_cast
  local addr
  addr="$(address_from_env)"
  bold "Balances for $addr"
  show_balance "Ethereum Sepolia" "$(env_get ETH_SEPOLIA_RPC_URL)" "$ETH_SEPOLIA_ID" "ETH" "$addr"
  show_balance "Base Sepolia" "$(env_get BASE_SEPOLIA_RPC_URL)" "$BASE_SEPOLIA_ID" "ETH" "$addr"
  show_balance "Reactive Lasna" "$(env_get LASNA_RPC_URL)" "$LASNA_ID" "lREACT" "$addr"
}

cmd_lreact() {
  require_cast
  local key addr choice url expected faucet chain amount answer
  key="$(env_get PRIVATE_KEY)"
  addr="$(address_from_env)"

  bold "Swap testnet ETH for lREACT (1 ETH = 100 lREACT, max $FAUCET_MAX_ETH ETH per tx)"
  echo "  Pay from which chain?"
  echo "    1) Ethereum Sepolia"
  echo "    2) Base Sepolia"
  read -r -p "  Choice [1]: " choice
  case "${choice:-1}" in
    1) url="$(env_get ETH_SEPOLIA_RPC_URL)"; expected=$ETH_SEPOLIA_ID; faucet=$FAUCET_ETH_SEPOLIA; chain="Ethereum Sepolia" ;;
    2) url="$(env_get BASE_SEPOLIA_RPC_URL)"; expected=$BASE_SEPOLIA_ID; faucet=$FAUCET_BASE_SEPOLIA; chain="Base Sepolia" ;;
    *) die "Unknown choice '$choice'" ;;
  esac
  check_rpc "$chain" "$url" "$expected" || die "Fix the $chain RPC URL in $ENV_FILE first"

  read -r -p "  Amount of ETH to send (for example 0.5): " amount
  [[ "$amount" =~ ^[0-9]+(\.[0-9]+)?$ ]] || die "Not a number: '$amount'"
  awk -v a="$amount" -v m="$FAUCET_MAX_ETH" 'BEGIN{exit !(a > 0 && a <= m)}' \
    || die "Amount must be above 0 and at most $FAUCET_MAX_ETH ETH (anything above is lost)"

  echo
  echo "  From:    $addr"
  echo "  To:      $faucet (Reactive lREACT faucet on $chain)"
  echo "  Amount:  $amount ETH  ->  about $(awk -v a="$amount" 'BEGIN{print a*100}') lREACT on Lasna"
  read -r -p "  Send now? Type 'yes' to confirm: " answer
  [ "$answer" = "yes" ] || { echo "  Cancelled. Nothing was sent."; return; }

  local out tx
  out="$(cast send "$faucet" --value "${amount}ether" --rpc-url "$url" --private-key "$key" --json)" \
    || die "Transaction failed"
  tx="$(printf '%s' "$out" | sed -n 's/.*"transactionHash":"\(0x[0-9a-fA-F]*\)".*/\1/p')"
  ok "Sent on $chain (chain ID $expected). Tx hash: ${tx:-see output above}"
  echo "  lREACT can take a few minutes to arrive. Check with: bash scripts/wallet.sh balance"
}

cmd_setup() {
  require_cast
  bold "Step 1/5: .env file"
  if [ -f "$ENV_FILE" ]; then
    ok "Found $ENV_FILE"
  else
    cp "$EXAMPLE_FILE" "$ENV_FILE"
    ok "Created $ENV_FILE from .env.example (git-ignored, never commit it)"
  fi

  bold "Step 2/5: testnet-only wallet"
  if [ -n "$(env_get PRIVATE_KEY)" ]; then
    ok "PRIVATE_KEY already set. Address: $(address_from_env)"
  else
    echo "  Use a NEW wallet that never holds mainnet funds."
    echo "    1) Create a new wallet now (recommended)"
    echo "    2) Paste a key from a testnet-only wallet I already have"
    local choice key
    read -r -p "  Choice [1]: " choice
    case "${choice:-1}" in
      1)
        key="$(cast wallet new | awk -F': *' '/[Pp]rivate [Kk]ey/ {print $2}' | tr -d '\r')"
        [ -n "$key" ] || die "Could not create a wallet with 'cast wallet new'"
        ;;
      2)
        read -r -s -p "  Private key (input hidden): " key
        echo
        ;;
      *) die "Unknown choice '$choice'" ;;
    esac
    cast wallet address --private-key "$key" >/dev/null 2>&1 || die "That is not a valid private key"
    env_set PRIVATE_KEY "$key"
    ok "Key saved to $ENV_FILE (not shown). Address: $(address_from_env)"
    warn "Back up $ENV_FILE somewhere private. If you lose it, the testnet funds are gone."
  fi

  bold "Step 3/5: RPC URLs"
  local url
  if [ -z "$(env_get ETH_SEPOLIA_RPC_URL)" ]; then
    echo "  Ethereum Sepolia has no RPC URL yet. Get a free one from Alchemy or Infura, or pick one on chainlist.org."
    read -r -p "  Ethereum Sepolia RPC URL (Enter to skip): " url
    [ -n "$url" ] && env_set ETH_SEPOLIA_RPC_URL "$url"
  fi
  check_rpc "Ethereum Sepolia" "$(env_get ETH_SEPOLIA_RPC_URL)" "$ETH_SEPOLIA_ID" || true
  check_rpc "Base Sepolia" "$(env_get BASE_SEPOLIA_RPC_URL)" "$BASE_SEPOLIA_ID" || true
  check_rpc "Reactive Lasna" "$(env_get LASNA_RPC_URL)" "$LASNA_ID" || true

  bold "Step 4/5: get testnet ETH"
  local addr
  addr="$(address_from_env)"
  echo "  Your address:  $addr"
  echo "  Paste it into a faucet for each chain:"
  echo "    - Ethereum Sepolia ETH: Google Cloud Web3 faucet, Alchemy faucet, or a PoW faucet"
  echo "    - Base Sepolia ETH:     Coinbase Developer Platform faucet or Alchemy faucet"
  echo "  Faucets change often and may ask for a login. Any working Sepolia / Base Sepolia faucet is fine."

  bold "Step 5/5: balances"
  cmd_balance
  echo
  echo "  When you have Sepolia ETH, get lREACT with:  bash scripts/wallet.sh lreact"
  echo "  Then check again with:                     bash scripts/wallet.sh balance"
}

case "${1:-setup}" in
  setup) cmd_setup ;;
  balance) cmd_balance ;;
  lreact) cmd_lreact ;;
  -h | --help | help) sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
  *) die "Unknown command '$1'. Use: setup, balance, lreact, help" ;;
esac
