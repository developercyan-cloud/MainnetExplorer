# MainNet Explorer — Blockscout + Railway deployment pack

This pack prepares the configuration and verification steps for a **separate Blockscout explorer** that reads the ProEshop Anvil fork. It does not modify ProEshop, its database, the fork service, or MainNet Lab.

## Important deployment constraint

Blockscout is a multi-service stack (backend/indexer, frontend/proxy, PostgreSQL, Redis and optional microservices). Railway does not deploy a Docker Compose stack as a single service in the same way a Docker host does. Deploying on Railway therefore means creating and wiring multiple Railway services and persistent database services. This pack is a configuration/verification starter, not a one-click installer.

Official references:
- Blockscout Docker Compose: https://github.com/blockscout/blockscout/tree/master/docker-compose
- Official Anvil configuration: https://github.com/blockscout/blockscout/blob/master/docker-compose/anvil.yml
- Backend env reference: https://github.com/blockscout/blockscout/blob/master/docker-compose/envs/common-blockscout.env
- Frontend env reference: https://github.com/blockscout/frontend/blob/main/docs/ENVS.md

## Target network

- Display name: `MainNet Lab Testnet`
- RPC URL: `https://mainnetproetech-production.up.railway.app/rpc`
- Chain ID: `1` (same as Ethereum Mainnet; this is risky/confusing, so show a clear testnet warning in the UI)
- Native currency: `ETH`
- Explorer is read-only with respect to the chain; it indexes data into its own PostgreSQL database.

## Before deploying

1. Confirm that the RPC is the fork, not a real Ethereum Mainnet endpoint.
2. Run `./check-rpc.sh` from a shell with `curl` installed, or paste the JSON requests from `rpc-checks.json` into Hoppscotch.
3. Ensure the RPC permits `eth_blockNumber`, `eth_getBlockByNumber`, `eth_getTransactionReceipt`, `eth_getLogs`, `eth_call` and enough historical reads for indexing.
4. Do not expose administrative endpoints or any RPC methods that mutate state. The explorer only needs read access.

## Railway architecture

Create separate Railway services for:

1. **PostgreSQL** — persistent storage for Blockscout. Do not reuse ProEshop's SQLite or any other app database.
2. **Redis** — Blockscout backend cache/queue.
3. **Blockscout backend/indexer** — use the official Blockscout backend image/version from the official Docker Compose config; set the environment variables below.
4. **Blockscout frontend** — use the official `ghcr.io/blockscout/frontend` image and set the frontend variables below.
5. **Proxy / routing** — route `/api`, `/socket` and backend API paths to the backend, and all other paths to the frontend under one public domain. Follow the current Blockscout frontend migration/proxy docs. Avoid deploying frontend and backend on unrelated origins without proxy configuration.

The exact image tags, service start commands, and environment variables can change between Blockscout releases. Pin compatible versions from the same official release rather than blindly using `latest`.

### Backend environment values to configure

```env
ETHEREUM_JSONRPC_VARIANT=anvil
ETHEREUM_JSONRPC_HTTP_URL=https://mainnetproetech-production.up.railway.app/rpc
CHAIN_ID=1
NETWORK=MainNet Lab Testnet
SUBNETWORK=ProEshop Anvil Fork
COIN=ETH
API_V2_ENABLED=true
INDEXER_DISABLE_INTERNAL_TRANSACTIONS_FETCHER=true
INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER=true
```

Also configure `DATABASE_URL` using the dedicated Railway PostgreSQL service, Redis connection settings required by the selected official release, and the required backend secrets (such as `SECRET_KEY_BASE`) using Railway variables. Do not commit secrets to GitHub or put them in this pack.

### Frontend environment values to configure

```env
NEXT_PUBLIC_NETWORK_NAME=MainNet Lab Testnet
NEXT_PUBLIC_NETWORK_SHORT_NAME=MainNet Lab
NEXT_PUBLIC_NETWORK_ID=1
NEXT_PUBLIC_NETWORK_CURRENCY_NAME=Ether
NEXT_PUBLIC_NETWORK_CURRENCY_SYMBOL=ETH
NEXT_PUBLIC_NETWORK_CURRENCY_DECIMALS=18
NEXT_PUBLIC_IS_TESTNET=true
```

The frontend API host/protocol, stats host, app host/protocol, WebSocket protocol and API base path must match the chosen proxy and public domain. Set these from the current official frontend env reference.

## Validation checklist

- The explorer displays the intended testnet name and warning.
- Latest block matches `eth_blockNumber` from the fork RPC.
- A known transaction hash from the fork can be found and its receipt status matches the RPC.
- A known wallet balance shown by the explorer matches `eth_getBalance` / ERC-20 `balanceOf` from the same RPC.
- USDT contract shown is `0xdAC17F958D2ee523a2206206994597C13D831ec7` (6 decimals) only if confirmed from the fork's contract state.
- Indexer can read historical blocks/logs and does not repeatedly fail due to unsupported trace methods.
- The explorer's database is persistent across redeployments.
- No code or variable changes were made to the ProEshop service, its SQLite database, or the fork service.

## Known limitations

- Chain ID `1` is identical to Ethereum Mainnet. Never rely on Chain ID alone to identify this fork; verify the RPC URL.
- If the fork resets to a snapshot or reorgs, Blockscout's indexed database may become inconsistent and need a documented resync/reindex process.
- Full internal transaction traces may not be available because the public RPC gateway may block debug methods. The config disables the internal-transaction fetcher initially to reduce that dependency.
- Blockscout cannot display complete history that the RPC cannot provide.
- A successful admin funding response is not itself proof of the token balance; verify via `eth_call`/`balanceOf` against the fork.
