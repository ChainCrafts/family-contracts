SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eo pipefail -c

.DEFAULT_GOAL := help

ANVIL_HOST ?= 127.0.0.1
ANVIL_PORT ?= 8545
ANVIL_RPC_URL ?= http://$(ANVIL_HOST):$(ANVIL_PORT)
ANVIL_CHAIN_ID ?= 31337
ANVIL_MNEMONIC ?= test test test test test test test test test test test junk
ANVIL_PRIVATE_KEY ?= 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
ANVIL_BOB_PRIVATE_KEY ?= 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
ANVIL_CAROL_PRIVATE_KEY ?= 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a

INITIAL_REWARD_POOL ?= 0
MONAD_RPC_URL ?=
E2E_ACTOR_FUNDING ?= 0
E2E_SALE_PRICE ?= 1000000000000000000
E2E_CHILD_NAME ?= Nova
E2E_CHILD_CID ?= ipfs://nova

LOCAL_DEMO_OWNER_ALICE ?= 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
LOCAL_DEMO_OWNER_BOB ?= 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
LOCAL_DEMO_OWNER_CAROL ?= 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC

FORGE_BUILD_OPTS ?=
FORGE_TEST_OPTS ?= -vvv
FORGE_SCRIPT_OPTS ?= --broadcast -vvv
LOAD_ENV = set -a; if [ -f .env ]; then source <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' .env); fi; \
	for key_var in PRIVATE_KEY ALICE_PRIVATE_KEY BOB_PRIVATE_KEY CAROL_PRIVATE_KEY; do \
		key_val="$${!key_var-}"; \
		if [ -n "$$key_val" ] && [[ "$$key_val" != 0x* ]]; then \
			printf -v "$$key_var" '0x%s' "$$key_val"; \
			export "$$key_var"; \
		fi; \
	done; \
	set +a

.PHONY: help install build clean fmt fmt-check snapshot coverage test test-unit test-integration test-invariant test-match test-monad-fork anvil deploy-local dry-run-local seed-local rpc-local rpc-monad
.PHONY: deploy-monad dry-run-monad seed-monad e2e-local e2e-monad dry-run-e2e-local dry-run-e2e-monad

help:
	@printf "%s\n" \
	"Foundry workflow" \
	"" \
	"Core:" \
	"  make build               Compile contracts" \
	"  make test                Run the full test suite" \
	"  make test-unit           Run unit tests only" \
	"  make test-integration    Run integration tests only" \
	"  make test-invariant      Run invariant tests only" \
	"  make test-match MATCH=X  Run tests matching a name" \
	"  make fmt                 Format Solidity" \
	"  make fmt-check           Check formatting" \
	"  make coverage            Generate coverage report" \
	"  make snapshot            Generate gas snapshot" \
	"  make clean               Clear build artifacts" \
	"" \
	"Local Anvil:" \
	"  make anvil               Start a local Anvil node" \
	"  make dry-run-local       Simulate deployment against Anvil RPC" \
	"  make deploy-local        Broadcast deployment to Anvil" \
	"  make seed-local AGENT_NFT=0x...   Mint demo agents on Anvil" \
	"  make e2e-local           Deploy and run full lifecycle flow on Anvil" \
	"  make rpc-local           Print Anvil chain id and latest block" \
	"" \
	"Monad testnet:" \
	"  make test-monad-fork     Run tests against a Monad fork" \
	"  make dry-run-monad       Simulate deployment against Monad RPC" \
	"  make deploy-monad        Broadcast deployment to Monad testnet" \
	"  make seed-monad AGENT_NFT=0x...   Mint demo agents on Monad" \
	"  make e2e-monad           Deploy and run full lifecycle flow on Monad" \
	"  make rpc-monad           Print Monad chain id and latest block" \
	"" \
	"Required env vars for Monad targets:" \
	"  MONAD_RPC_URL, PRIVATE_KEY" \
	"  DEMO_OWNER_ALICE, DEMO_OWNER_BOB, DEMO_OWNER_CAROL for seed-monad" \
	"  ALICE_PRIVATE_KEY, BOB_PRIVATE_KEY, CAROL_PRIVATE_KEY for e2e-monad"

install:
	forge install

build:
	forge build --sizes $(FORGE_BUILD_OPTS)

clean:
	forge clean

fmt:
	forge fmt

fmt-check:
	forge fmt --check

snapshot:
	forge snapshot

coverage:
	forge coverage

test:
	forge test $(FORGE_TEST_OPTS)

test-unit:
	forge test --match-path "test/unit/**/*.t.sol" $(FORGE_TEST_OPTS)

test-integration:
	forge test --match-path "test/integration/**/*.t.sol" $(FORGE_TEST_OPTS)

test-invariant:
	forge test --match-path "test/invariant/**/*.t.sol" $(FORGE_TEST_OPTS)

test-match:
	: "$${MATCH:?Missing required variable: MATCH}"
	forge test --match-test "$(MATCH)" $(FORGE_TEST_OPTS)

test-monad-fork:
	$(LOAD_ENV)
	: "$${MONAD_RPC_URL:?Missing required variable: MONAD_RPC_URL}"
	forge test --fork-url "$$MONAD_RPC_URL" $(FORGE_TEST_OPTS)

anvil:
	anvil \
		--host "$(ANVIL_HOST)" \
		--port "$(ANVIL_PORT)" \
		--chain-id "$(ANVIL_CHAIN_ID)" \
		--mnemonic "$(ANVIL_MNEMONIC)"

rpc-local:
	cast chain-id --rpc-url "$(ANVIL_RPC_URL)"
	cast block-number --rpc-url "$(ANVIL_RPC_URL)"

rpc-monad:
	$(LOAD_ENV)
	: "$${MONAD_RPC_URL:?Missing required variable: MONAD_RPC_URL}"
	cast chain-id --rpc-url "$$MONAD_RPC_URL"
	cast block-number --rpc-url "$$MONAD_RPC_URL"

dry-run-local:
	PRIVATE_KEY="$(ANVIL_PRIVATE_KEY)" \
	INITIAL_REWARD_POOL="$(INITIAL_REWARD_POOL)" \
	forge script script/DeployMonadFamily.s.sol:DeployMonadFamily \
		--rpc-url "$(ANVIL_RPC_URL)" \
		-vvv

deploy-local:
	PRIVATE_KEY="$(ANVIL_PRIVATE_KEY)" \
	INITIAL_REWARD_POOL="$(INITIAL_REWARD_POOL)" \
	forge script script/DeployMonadFamily.s.sol:DeployMonadFamily \
		--rpc-url "$(ANVIL_RPC_URL)" \
		$(FORGE_SCRIPT_OPTS)

seed-local:
	: "$${AGENT_NFT:?Missing required variable: AGENT_NFT}"
	PRIVATE_KEY="$(ANVIL_PRIVATE_KEY)" \
	AGENT_NFT="$$AGENT_NFT" \
	DEMO_OWNER_ALICE="$(LOCAL_DEMO_OWNER_ALICE)" \
	DEMO_OWNER_BOB="$(LOCAL_DEMO_OWNER_BOB)" \
	DEMO_OWNER_CAROL="$(LOCAL_DEMO_OWNER_CAROL)" \
	forge script script/SeedDemoAgents.s.sol:SeedDemoAgents \
		--rpc-url "$(ANVIL_RPC_URL)" \
		$(FORGE_SCRIPT_OPTS)

dry-run-e2e-local:
	PRIVATE_KEY="$(ANVIL_PRIVATE_KEY)" \
	ALICE_PRIVATE_KEY="$(ANVIL_PRIVATE_KEY)" \
	BOB_PRIVATE_KEY="$(ANVIL_BOB_PRIVATE_KEY)" \
	CAROL_PRIVATE_KEY="$(ANVIL_CAROL_PRIVATE_KEY)" \
	INITIAL_REWARD_POOL="$${INITIAL_REWARD_POOL:-100000000000000000000}" \
	E2E_ACTOR_FUNDING="$(E2E_ACTOR_FUNDING)" \
	E2E_SALE_PRICE="$(E2E_SALE_PRICE)" \
	E2E_CHILD_NAME="$(E2E_CHILD_NAME)" \
	E2E_CHILD_CID="$(E2E_CHILD_CID)" \
	forge script script/E2EExample.s.sol:E2EExample \
		--rpc-url "$(ANVIL_RPC_URL)" \
		-vvv

e2e-local:
	PRIVATE_KEY="$(ANVIL_PRIVATE_KEY)" \
	ALICE_PRIVATE_KEY="$(ANVIL_PRIVATE_KEY)" \
	BOB_PRIVATE_KEY="$(ANVIL_BOB_PRIVATE_KEY)" \
	CAROL_PRIVATE_KEY="$(ANVIL_CAROL_PRIVATE_KEY)" \
	INITIAL_REWARD_POOL="$${INITIAL_REWARD_POOL:-100000000000000000000}" \
	E2E_ACTOR_FUNDING="$(E2E_ACTOR_FUNDING)" \
	E2E_SALE_PRICE="$(E2E_SALE_PRICE)" \
	E2E_CHILD_NAME="$(E2E_CHILD_NAME)" \
	E2E_CHILD_CID="$(E2E_CHILD_CID)" \
	forge script script/E2EExample.s.sol:E2EExample \
		--rpc-url "$(ANVIL_RPC_URL)" \
		$(FORGE_SCRIPT_OPTS)

dry-run-monad:
	$(LOAD_ENV)
	: "$${MONAD_RPC_URL:?Missing required variable: MONAD_RPC_URL}"
	: "$${PRIVATE_KEY:?Missing required variable: PRIVATE_KEY}"
	PRIVATE_KEY="$$PRIVATE_KEY" \
	INITIAL_REWARD_POOL="$${INITIAL_REWARD_POOL:-$(INITIAL_REWARD_POOL)}" \
	forge script script/DeployMonadFamily.s.sol:DeployMonadFamily \
		--rpc-url "$$MONAD_RPC_URL" \
		-vvv

deploy-monad:
	$(LOAD_ENV)
	: "$${MONAD_RPC_URL:?Missing required variable: MONAD_RPC_URL}"
	: "$${PRIVATE_KEY:?Missing required variable: PRIVATE_KEY}"
	PRIVATE_KEY="$$PRIVATE_KEY" \
	INITIAL_REWARD_POOL="$${INITIAL_REWARD_POOL:-$(INITIAL_REWARD_POOL)}" \
	forge script script/DeployMonadFamily.s.sol:DeployMonadFamily \
		--rpc-url "$$MONAD_RPC_URL" \
		$(FORGE_SCRIPT_OPTS)

seed-monad:
	$(LOAD_ENV)
	: "$${MONAD_RPC_URL:?Missing required variable: MONAD_RPC_URL}"
	: "$${PRIVATE_KEY:?Missing required variable: PRIVATE_KEY}"
	: "$${AGENT_NFT:?Missing required variable: AGENT_NFT}"
	: "$${DEMO_OWNER_ALICE:?Missing required variable: DEMO_OWNER_ALICE}"
	: "$${DEMO_OWNER_BOB:?Missing required variable: DEMO_OWNER_BOB}"
	: "$${DEMO_OWNER_CAROL:?Missing required variable: DEMO_OWNER_CAROL}"
	PRIVATE_KEY="$$PRIVATE_KEY" \
	AGENT_NFT="$$AGENT_NFT" \
	DEMO_OWNER_ALICE="$$DEMO_OWNER_ALICE" \
	DEMO_OWNER_BOB="$$DEMO_OWNER_BOB" \
	DEMO_OWNER_CAROL="$$DEMO_OWNER_CAROL" \
	forge script script/SeedDemoAgents.s.sol:SeedDemoAgents \
		--rpc-url "$$MONAD_RPC_URL" \
		$(FORGE_SCRIPT_OPTS)

dry-run-e2e-monad:
	$(LOAD_ENV)
	: "$${MONAD_RPC_URL:?Missing required variable: MONAD_RPC_URL}"
	: "$${PRIVATE_KEY:?Missing required variable: PRIVATE_KEY}"
	: "$${ALICE_PRIVATE_KEY:?Missing required variable: ALICE_PRIVATE_KEY}"
	: "$${BOB_PRIVATE_KEY:?Missing required variable: BOB_PRIVATE_KEY}"
	: "$${CAROL_PRIVATE_KEY:?Missing required variable: CAROL_PRIVATE_KEY}"
	PRIVATE_KEY="$$PRIVATE_KEY" \
	ALICE_PRIVATE_KEY="$$ALICE_PRIVATE_KEY" \
	BOB_PRIVATE_KEY="$$BOB_PRIVATE_KEY" \
	CAROL_PRIVATE_KEY="$$CAROL_PRIVATE_KEY" \
	INITIAL_REWARD_POOL="$${INITIAL_REWARD_POOL:-100000000000000000000}" \
	E2E_ACTOR_FUNDING="$${E2E_ACTOR_FUNDING:-$(E2E_ACTOR_FUNDING)}" \
	E2E_SALE_PRICE="$${E2E_SALE_PRICE:-$(E2E_SALE_PRICE)}" \
	E2E_CHILD_NAME="$${E2E_CHILD_NAME:-$(E2E_CHILD_NAME)}" \
	E2E_CHILD_CID="$${E2E_CHILD_CID:-$(E2E_CHILD_CID)}" \
	forge script script/E2EExample.s.sol:E2EExample \
		--rpc-url "$$MONAD_RPC_URL" \
		-vvv

e2e-monad:
	$(LOAD_ENV)
	: "$${MONAD_RPC_URL:?Missing required variable: MONAD_RPC_URL}"
	: "$${PRIVATE_KEY:?Missing required variable: PRIVATE_KEY}"
	: "$${ALICE_PRIVATE_KEY:?Missing required variable: ALICE_PRIVATE_KEY}"
	: "$${BOB_PRIVATE_KEY:?Missing required variable: BOB_PRIVATE_KEY}"
	: "$${CAROL_PRIVATE_KEY:?Missing required variable: CAROL_PRIVATE_KEY}"
	PRIVATE_KEY="$$PRIVATE_KEY" \
	ALICE_PRIVATE_KEY="$$ALICE_PRIVATE_KEY" \
	BOB_PRIVATE_KEY="$$BOB_PRIVATE_KEY" \
	CAROL_PRIVATE_KEY="$$CAROL_PRIVATE_KEY" \
	INITIAL_REWARD_POOL="$${INITIAL_REWARD_POOL:-100000000000000000000}" \
	E2E_ACTOR_FUNDING="$${E2E_ACTOR_FUNDING:-$(E2E_ACTOR_FUNDING)}" \
	E2E_SALE_PRICE="$${E2E_SALE_PRICE:-$(E2E_SALE_PRICE)}" \
	E2E_CHILD_NAME="$${E2E_CHILD_NAME:-$(E2E_CHILD_NAME)}" \
	E2E_CHILD_CID="$${E2E_CHILD_CID:-$(E2E_CHILD_CID)}" \
	forge script script/E2EExample.s.sol:E2EExample \
		--rpc-url "$$MONAD_RPC_URL" \
		$(FORGE_SCRIPT_OPTS)
