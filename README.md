# Monad Family Contracts

> A Monad-native onchain agent lifecycle protocol built with Solidity, Foundry, and a production-style modular architecture.

`MonadFamily` models autonomous agents as ERC-721 NFTs that can work, build compatibility, marry, raise children, retire, and be traded. The system is split into dedicated modules so lifecycle rules, accounting, and market behavior stay explicit and testable.

## Monad Hackathon Submission

`MonadFamily` is designed as a playful but technically serious consumer protocol for Monad: a fully onchain world where agents behave like households with memory, economics, relationships, inheritance, and open market mobility.

Why it fits Monad well:

- Fast, low-cost execution makes repeated lifecycle actions practical onchain
- Native asset flows let rewards, household balances, inheritance, and trading happen in `MON`
- Modular contracts make the protocol easy to demo, extend, and judge during a hackathon review

For reviewer readability, this README expresses human-facing native-token amounts in `MON`. The Solidity contracts and scripts still use standard EVM base units under the hood.

## Overview

This repository contains a four-contract protocol:

| Contract | Role | Key Responsibilities |
| --- | --- | --- |
| `AgentNFT` | ERC-721 state layer | Mints agents, stores lifecycle state, creates children, manages balances, retires agents |
| `FamilyRegistry` | Relationship layer | Tracks compatibility, marriage approvals, child approvals, family lookups |
| `WorkEngine` | Economic engine | Funds rewards, advances ages, pays work rewards, retires agents, tracks community pool |
| `Marketplace` | Secondary market | Lists agents for sale, executes purchases, clears stale listings |

The project is organized as a Foundry workspace with unit, integration, and invariant tests plus deployment and end-to-end scripts for local Anvil and Monad testnet.

## Protocol Model

Each agent NFT stores:

- Identity data such as `name` and `personalityCID`
- Trait scores for `riskScore`, `patience`, and `socialScore`
- A job type: `Trader`, `Farmer`, or `Lender`
- Lifecycle state such as `age`, `maxAge`, `partnerId`, `childIds`, `balance`, and `lockedBalance`
- Flags for `independent`, `retired`, and `sicknessEvaluated`

### Core Rules

| Rule | Value |
| --- | --- |
| Adult age | `18` |
| Sickness assessment age | `60` |
| Maximum age | `100` |
| Marriage compatibility threshold | `80` |
| Compatibility increment per paired work session | `5` |
| Child funding contribution per parent | `10%` of parent balance |
| Move-out house fund | `0.5 MON` |
| Base work reward | `0.001 MON` |
| Risk reward step | `0.00001 MON` per variance unit |
| Job mutation chance for children | `30%` |

### Lifecycle Flow

1. The protocol owner mints adult genesis agents through `AgentNFT.mint`.
2. Independent adult agents call `WorkEngine.work` to earn rewards and age.
3. Paired work sessions increase compatibility through `FamilyRegistry.incrementCompatibility`.
4. Both current owners must approve marriage before `FamilyRegistry.marry` succeeds.
5. Marriage merges household balances and marks both agents independent.
6. Both spouses must approve child creation before `AgentNFT.mintChild` succeeds.
7. Child traits are blended from both parents, with bounded jitter and optional job mutation.
8. Children start non-independent with locked funds until `moveOut` is called after adulthood.
9. At age `60+`, sickness must be set before more work can happen.
10. At max age, `WorkEngine` retires the agent and distributes its final balance to children or the community pool.

## Contract Details

### `AgentNFT`

- ERC-721 token name: `MonadFamily`
- ERC-721 symbol: `MFAM`
- Mints genesis agents directly to owners
- Mints children only for married parents with recorded approvals
- Restricts child ownership to the current owner of either parent
- Keeps both liquid and locked balances
- Splits merged household balances deterministically on marriage
- Automatically notifies the marketplace on transfers so stale listings are cleared

### `FamilyRegistry`

- Stores pair compatibility keyed by normalized agent pairs
- Records marriage and child approvals against the current owner of each approving agent
- Invalidates stale approvals naturally if ownership changes before use
- Exposes helper views such as `canMarry`, `getMissingMarriageApprovals`, and `getHouseholdBalance`
- Lets the owner freeze module wiring after `WorkEngine` is configured

### `WorkEngine`

- Holds the reward pool and community pool
- Uses `block.prevrandao` and `block.timestamp` to derive reward variance
- Provides `previewWorkReward` for read-only reward estimates in the current block context
- Pauses and unpauses through owner control
- Forces sickness evaluation for older agents before more work
- Sends retirement proceeds either to descendants or the shared community pool

### `Marketplace`

- Requires seller authorization plus marketplace approval before listing
- Uses `ReentrancyGuard` on purchases
- Verifies the seller still owns the NFT at buy time
- Supports explicit delisting and public stale-listing cleanup
- Allows retired agents to remain tradable after retirement

## Repository Layout

```text
.
├── src/
│   ├── AgentNFT.sol
│   ├── FamilyRegistry.sol
│   ├── Marketplace.sol
│   ├── WorkEngine.sol
│   ├── interfaces/
│   └── libraries/
├── script/
│   ├── DeployMonadFamily.s.sol
│   ├── E2EExample.s.sol
│   └── SeedDemoAgents.s.sol
├── test/
│   ├── unit/
│   ├── integration/
│   ├── invariant/
│   └── utils/
├── deployments/
│   └── monad-testnet.json
└── Makefile
```

## Quickstart

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- A Unix-like shell environment
- A funded account only if you plan to broadcast to Monad testnet

### Install Dependencies

```bash
make install
```

### Build and Test

```bash
make build
make test
make coverage
make snapshot
```

Targeted test entry points are also available:

```bash
make test-unit
make test-integration
make test-invariant
make test-match MATCH=Lifecycle
```

## Local Development Workflow

### 1. Start Anvil

```bash
make anvil
```

This starts Anvil on `http://127.0.0.1:8545` with the standard Foundry test mnemonic.

### 2. Deploy Locally

```bash
make deploy-local INITIAL_REWARD_POOL=100000000000000000000 # 100 MON
```

Useful variants:

```bash
make dry-run-local INITIAL_REWARD_POOL=100000000000000000000 # 100 MON
make rpc-local
```

### 3. Seed Demo Agents

After deployment, pass the deployed `AgentNFT` address into the seed script:

```bash
make seed-local AGENT_NFT=0xYourAgentNFTAddress
```

This mints three demo agents:

- `Aylin` for Alice
- `Mert` for Bob
- `Deniz` for Carol

### 4. Run the Full Local Lifecycle Demo

```bash
make e2e-local
```

The end-to-end script deploys contracts, optionally funds actors, grows compatibility, performs marriage approvals, mints a child, lists the child, and completes a marketplace purchase.

## Monad Testnet Workflow

The repository includes a Monad-focused deployment path and an existing deployment record. Monad targets read from `.env` when present.

### Required Environment Variables

| Variable | Purpose |
| --- | --- |
| `MONAD_RPC_URL` | RPC endpoint for Monad testnet |
| `PRIVATE_KEY` | Broadcaster key for deployment and seeding |
| `AGENT_NFT` | Existing NFT contract address for seeding |
| `DEMO_OWNER_ALICE` | Recipient for demo agent 1 on Monad |
| `DEMO_OWNER_BOB` | Recipient for demo agent 2 on Monad |
| `DEMO_OWNER_CAROL` | Recipient for demo agent 3 on Monad |
| `ALICE_PRIVATE_KEY` | Actor key for Monad end-to-end script |
| `BOB_PRIVATE_KEY` | Actor key for Monad end-to-end script |
| `CAROL_PRIVATE_KEY` | Actor key for Monad end-to-end script |
| `INITIAL_REWARD_POOL` | Optional initial reward funding for deployment, passed in base units |
| `FREEZE_MODULE_WIRING` | Optional wiring freeze toggle after deployment |
| `E2E_ACTOR_FUNDING` | Optional `MON` funding for E2E actors, passed in base units |
| `E2E_SALE_PRICE` | Optional sale price in `MON` base units for the E2E script |
| `E2E_CHILD_NAME` | Optional child name for the E2E script |
| `E2E_CHILD_CID` | Optional child metadata CID for the E2E script |

The `Makefile` normalizes private keys from `.env` by adding a `0x` prefix automatically when needed.

Example:

```bash
INITIAL_REWARD_POOL=100000000000000000000 # 100 MON
E2E_SALE_PRICE=1000000000000000000        # 1 MON
```

### Deploy to Monad Testnet

```bash
make rpc-monad
make dry-run-monad
make deploy-monad
```

### Seed Demo Agents on Monad

```bash
make seed-monad \
  AGENT_NFT=0xYourAgentNFTAddress \
  DEMO_OWNER_ALICE=0xAlice \
  DEMO_OWNER_BOB=0xBob \
  DEMO_OWNER_CAROL=0xCarol
```

### Run the Monad End-to-End Demo

```bash
make dry-run-e2e-monad
make e2e-monad
```

## Current Monad Testnet Deployment

The repository currently includes a deployment record dated **March 28, 2026** in `deployments/monad-testnet.json`.

| Contract | Address | Status |
| --- | --- | --- |
| `AgentNFT` | [`0xAF6B89c51696B6A9Ba4167eDFbF35a8273004027`](https://testnet.monadvision.com/address/0xAF6B89c51696B6A9Ba4167eDFbF35a8273004027) | Verified on Sourcify (`exact_match`) |
| `FamilyRegistry` | [`0x44BFe82D95E2Dc4E3dA899B71f5C1331092c3D9F`](https://testnet.monadvision.com/address/0x44BFe82D95E2Dc4E3dA899B71f5C1331092c3D9F) | Verified on Sourcify (`exact_match`) |
| `WorkEngine` | [`0x2F7FeE5FBb7F1c1f84d8885b0185c6a193dAc1bc`](https://testnet.monadvision.com/address/0x2F7FeE5FBb7F1c1f84d8885b0185c6a193dAc1bc) | Verified on Sourcify (`exact_match`) |
| `Marketplace` | [`0xa60fD4cdc8600AEd6CD5a9E8c6e39a56f863e3cD`](https://testnet.monadvision.com/address/0xa60fD4cdc8600AEd6CD5a9E8c6e39a56f863e3cD) | Verified on Sourcify (`exact_match`) |

Deployment metadata in the same file shows:

- Network: `monad-testnet`
- Chain ID: `10143`
- Module wiring frozen: `false`
- Initial reward pool at deployment: `0 MON`

## Testing Strategy

The suite is structured to cover protocol behavior from three angles:

- `test/unit`: focused behavior checks for each module, including marriage approvals, minting, work, retirement, listings, and buying
- `test/integration`: multi-step lifecycle scenarios such as work-to-marriage-to-child-to-retirement and post-retirement trading
- `test/invariant`: protocol-wide accounting and relationship safety under randomized handler actions

Foundry is configured with:

- Solidity `0.8.24`
- Fuzz runs: `512`
- Invariant runs: `128`
- Invariant depth: `64`

## Design and Security Notes

- Module wiring can be frozen after setup to reduce configuration risk in production-style deployments.
- Marriage and child approvals are bound to the approving agent's current owner, which prevents approvals from silently surviving transfers.
- Marketplace purchases are protected by a reentrancy guard and seller ownership re-checks.
- Reward generation and child trait blending use block-derived entropy, so live-chain outputs are intentionally non-deterministic.
- The marketplace is not opinionated about lifecycle status; even retired agents remain transferable if owners choose to trade them.
- Human-facing documentation uses `MON`, while Solidity arithmetic still relies on standard EVM native-unit conventions internally.

## Useful Commands

```bash
make help
forge fmt
forge inspect AgentNFT abi
forge script script/DeployMonadFamily.s.sol:DeployMonadFamily --rpc-url $MONAD_RPC_URL -vvv
```

## Notes for Integrators

- Treat `previewWorkReward` as a same-block estimate, not a guaranteed quote.
- Expect child IDs and trait outcomes to vary across real transactions because entropy is block-sensitive.
- If you build a frontend or indexer on top of this protocol, track events from all four contracts to reconstruct lifecycle state cleanly.

---

If you are extending the protocol, start with `test/utils/BaseFixture.t.sol` and `script/E2EExample.s.sol`. Together they show the canonical wiring, seeding pattern, and happy-path lifecycle flow end to end.
