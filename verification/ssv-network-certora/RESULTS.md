# Cluster liquidation verification

## Result

Certora Cloud completed the verification with exit code 0 and reported
`No errors found by Prover!`:

- Job: <https://prover.certora.com/output/10390566/7b51830ff7634f2aa133f162ee0d4baf>
- Certora CLI: 8.19.2
- Solidity: 0.8.24
- EVM target: Cancun
- Date: 2026-10-08

The strengthened legacy SSV suite completed with the same successful result:

- Job: <https://prover.certora.com/output/10390566/5a3c66d9b2a141fd87a36f44b7de8cd8>
- Certora CLI: 8.19.2
- Solidity: 0.8.24
- EVM target: Cancun
- Date: 2026-10-11

The initial ETH withdrawal-solvency suite completed successfully:

- Job: <https://prover.certora.com/output/10390566/a4f63447e4044b29ae74e150d7871012>
- Certora CLI: 8.19.2
- Solidity: 0.8.24
- EVM target: Cancun
- Date: 2026-10-11

The accrued-fee ETH withdrawal suite completed successfully:

- Job: <https://prover.certora.com/output/10390566/adda14406f9a4e20860b0db293eb0434>
- Certora CLI: 8.19.2
- Solidity: 0.8.24
- EVM target: Cancun
- Date: 2026-10-11

The ETH liquidation suite with accrued fees completed successfully:

- Job: <https://prover.certora.com/output/10390566/7e7ac39862a74b6fb1def7749be41181>
- Certora CLI: 8.19.2
- Solidity: 0.8.24
- EVM target: Cancun
- Date: 2026-10-11

## Verified properties

### `thirdPartyCannotLiquidateSolventETH`

For an active, solvent ETH cluster in the modeled state, a caller different
from the cluster owner cannot liquidate it. The call must revert and the stored
cluster hash must remain unchanged.

The strengthened rule includes up to 1,000,000 elapsed blocks and symbolic
operator/network fees up to 1,000,000,000 packed units. Its reachability
witness has both fees positive and at least one elapsed block.

The basic rule-sanity check found a reachable execution, so the proof is not a
consequence of contradictory preconditions.

### `ownerMayAttemptSelfLiquidationETH`

Certora found a valid witness in which the cluster owner executes
self-liquidation without reverting. This captures the intentional owner
exception and prevents the main property from being stated too broadly.

### `thirdPartyCannotLiquidateSolventSSV`

For an active, solvent legacy SSV cluster in the modeled state, a caller
different from the cluster owner cannot liquidate it. The call must revert and
the stored legacy cluster hash must remain unchanged.

The basic rule-sanity check produced a reachable execution, so the result is
not caused by contradictory preconditions.

### `ownerMayAttemptSelfLiquidationSSV`

Certora found a concrete witness in which the cluster owner self-liquidates
without reverting. The witness uses a zero cluster balance so it checks the
authorization/state transition without introducing an external ERC-20 model.

### `successfulWithdrawPreservesETHSolvency`

For an active ETH cluster with validators, every successful owner withdrawal
leaves the resulting cluster non-liquidatable and stores the exact expected
post-withdrawal hash. The rule covers symbolic withdrawal amounts, implicit or
explicit vUnits, and symbolic network fee and liquidation parameters.

### `solventETHWithdrawCanSucceed`

Certora found a concrete witness for a successful nonzero ETH withdrawal. This
checks that the universal withdrawal rule is paired with an executable success
path rather than relying only on reverting calls.

### `successfulAccruedETHWithdrawPreservesSolvency`

This extends the withdrawal invariant across up to 1,000,000 blocks of operator
and network fee accrual. Fees are symbolic up to 1,000,000,000 packed units;
the rule settles the live indices before the withdrawal, then checks solvency
and the resulting stored hash against an independent harness calculation.

### `accruedETHWithdrawCanSucceedWithNonzeroFees`

Certora produced a successful nonzero withdrawal witness with both operator and
network fees positive and at least one block elapsed. This confirms that the
accrued-fee branch is reachable under the model.

## Scope

The current model covers:

- active ETH clusters;
- exactly four distinct, sorted operator IDs;
- nonzero validator count, capped at 100 in the third-party rule;
- block numbers representable by the protocol's `uint32` snapshots;
- sufficient native protocol balance for the modeled cluster balance;
- initialized network/DAO accounting, operator snapshots, vUnits, and
  reentrancy-guard state;
- up to 1,000,000 elapsed blocks, operator/network fees up to 1,000,000,000
  packed units, and explicit vUnits up to 100,000,000 in the strengthened ETH
  liquidation rule.

The SSV rule uses the analogous legacy state:

- exactly four distinct, sorted operator IDs;
- an active cluster with 1 to 100 validators;
- up to 1,000,000 blocks of elapsed fee accrual;
- symbolic operator and network fees up to 1,000,000,000 packed units;
- symbolic liquidation parameters, with the liquidation period capped at
  1,000,000 blocks;
- initialized DAO validator count and reentrancy-guard state.

The original ETH withdrawal rule starts operator and protocol snapshots at the
verification block. The accrued-fee rule separately covers elapsed settlement,
with same-fee snapshots for the four operators and up to 1,000,000 blocks. Both
rules support baseline vUnits and explicit vUnits at or above the baseline.

These are focused liquidation verifications, not a whole-contract or
whole-protocol proof. In particular, the SSV property proves the call reverts
before any token transfer, so no ERC-20 balance or return-value assumptions are
needed for the universal rule.

During strengthening, one cloud run declared a block-dependent helper as
`envfree`. Certora rejected that declaration and produced an apparent
counterexample because the helper and target call used different block
environments. Passing the same `env` to both removed the artifact; the corrected
strengthened rule is the successful SSV job linked above.

## View equivalence

The ETH and SSV specs compare the actual inherited `SSVViews` functions against
independent calculations of current index accrual and liquidation thresholds.
The ETH proof passed:
[Certora report](https://prover.certora.com/output/10390566/2e4be3096085456dba076982a58a55df).
The SSV proof passed:
[Certora report](https://prover.certora.com/output/10390566/9df9c62b7d44466487645cfacbec06c3).

Both jobs completed with exit code 0 and `No errors found by Prover!`; their
universal third-party liquidation rules and owner reachability witnesses
passed. Basic rule-sanity checks also found reachable solvent states. Earlier
attempts through a dynamically deployed `SSVViews` implementation failed the
comparison because that deployed instance was absent from Certora's scene; the
harness now inherits the view code directly. An earlier ETH reference also
omitted accrued fees and was corrected. Those were modeling artifacts, not
protocol findings.

## Modeling history

An earlier counterexample came from arbitrary initial diamond storage: the
network fee index used by the precondition differed from the state used by the
real liquidation path. The harness now initializes all relevant storage
consistently. That counterexample was a harness/model artifact, not evidence of
a contract vulnerability.
