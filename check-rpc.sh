#!/usr/bin/env bash
set -euo pipefail
RPC_URL="${RPC_URL:-https://mainnetproetech-production.up.railway.app/rpc}"
call_rpc() {
  local method="$1"
  curl -fsS -X POST "$RPC_URL" \
    -H 'Content-Type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"method\":\"${method}\",\"params\":[],\"id\":1}"
  printf '\n'
}
echo "RPC URL: $RPC_URL"
echo '--- eth_chainId ---'
call_rpc eth_chainId
echo '--- eth_blockNumber ---'
call_rpc eth_blockNumber
echo '--- anvil_nodeInfo (optional; may be blocked) ---'
call_rpc anvil_nodeInfo || true
