# Certora verification

This directory contains the complete, reproducible Certora verification for
the ETH and legacy SSV cluster liquidation properties.

## Layout

```text
certora/
├── conf/       Certora Prover configuration
├── harness/    Solidity verification harnesses
├── scripts/    Environment setup and verification entry points
├── specs/      CVL properties
└── RESULTS.md  Verified scope and latest successful cloud run
```

Generated `.certora_internal/` job data, Python environments, credentials, and
compiler caches are intentionally excluded from Git.

## Setup

From the repository root:

```bash
bash certora/scripts/setup.sh
```

Set `SETUP_SYSTEM_DEPS=1` on Ubuntu or Debian if the required OS packages are
not installed. The script creates `.venv-certora/`, installs Certora CLI and
`solc-select` at the versions pinned in `requirements.txt`, selects Solidity
0.8.24, installs npm dependencies, and compiles the contracts.

## Local validation

```bash
npm run certora:check
```

This formats/checks the CVL, builds the Hardhat project, and executes Certora's
local compilation steps without submitting a cloud job.

## Cloud verification

Expose either `CERTORAKEY` or `CERTORA` in the environment and run the desired
suite:

```bash
npm run certora:verify
npm run certora:ssv:verify
npm run certora:withdraw:verify
```

For a key stored as `CERTORA` in `~/.env`:

```bash
set -a
source ~/.env
set +a
npm run certora:verify
```

The corresponding local-only SSV command is:

```bash
npm run certora:ssv:check
npm run certora:withdraw:check
```

The scripts never print or write the key. See [RESULTS.md](RESULTS.md) for the
property scope and the last verified result.

## Next step: independent open-source validation

The next phase ports the same obligations to Halmos and compares the domain,
bounds, witnesses, and conclusions rather than treating a green run as enough.
See the Spanish
[open-source validation plan](../docs/formal-verification/OPEN_SOURCE_VALIDATION_PLAN.md).
