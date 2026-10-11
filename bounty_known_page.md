Known Issues
Description / Link	
Smart Contract	
Liquidations between root commitments. EB drift between root commitments.
Background: EB roots are committed periodically (~8 hours in production). A committed root is a point-in-time snapshot; it is not updated synchronously with every validator addition or removal. `updateClusterBalance` is permissionless for any caller holding a valid proof against the latest committed root.

Risk: remove validators, then withdraw aggressively.
Validator removals reduce the on-chain `validatorCount` immediately, but the latest committed root still reflects EB from before the removal. Any above-baseline EB is not proportionally reduced by validator removal. If an owner removes many validators and then withdraws down near the liquidation threshold based only on the new lower validator count, any caller can submit `updateClusterBalance` with the stale-but-valid high-EB root. That raises the effective fees and liquidation threshold. If the cluster becomes underfunded, the protocol auto-liquidation fires and the caller receives the remaining cluster balance.

Example sequence:
- T0: Oracle snapshots cluster at 10,000 ETH EB, 100 validators
- T1: Root committed (latestCommittedBlock set)
- T2: Owner removes many validators; on-chain count drops immediately
- T3: Owner withdraws based on lower count; cluster left near liquidation threshold
- T4: Any caller submits proof from the T1 root (still valid, still reflects high EB)
- T5: Auto-liquidation triggers; caller receives remaining cluster balance

Mitigations:
- Before large removals, check whether the latest committed root has already been consumed by the cluster.
- After large removals, do not withdraw near the liquidation threshold until a fresh post-removal root has been committed and consumed.
- Size withdrawals using the latest unconsumed root EB, not the new validator count alone or the value from `SSVNetworkViews.getEffectiveBalance`.
- High-EB clusters should maintain a conservative buffer through at least the next oracle round.

Accepted trade-off: add validators before the next oracle round.
The opposite direction temporarily favors the cluster owner. After consuming a root, newly registered validators are accounted at the 32 ETH baseline EB only. Any above-baseline EB they carry on the beacon chain is not yet reflected on-chain until the next root is committed and consumed. This latency is accepted by design, but owners should fund for the EB that the next root will apply, not only the current baseline.
https://bugs.immunefi...cts/923/reports/76267
11 May 2026
Smart Contract	
Extracting fees from a cluster when an operator is removed.
When an operator is removed, `removeOperator()` first settles the operator's accrued SSV and ETH earnings, then resets active state via `_resetOperatorState()`. That reset clears block, balances, fees, and validator counts, but intentionally does not clear `snapshot.index` or `ethSnapshot.index`. See [SSVOperators.sol](https://github.com/ssvlabs/ssv-network/tree/v2.0.0/contracts/modules/SSVOperators.sol) (removeOperator line 81, _resetOperatorState line 349).

Cluster accounting continues to include the removed operator's frozen index. In `OperatorLib.updateClusterData`, removed operators are skipped for future fee accrual (block and fee are zero, so no new earnings accumulate), but their preserved index is still added to `clusterIndex` when computing the cluster's outstanding balance. See [OperatorLib.sol](https://github.com/ssvlabs/ssv-network/tree/v2.0.0/contracts/libraries/OperatorLib.sol) (skip condition line 245, index addition line 260). The same logic applies in withdraw and view paths: with `ethSnapshot.block == 0` and `ethFee == 0`, future accrual is zero, but the frozen `ethSnapshot.index` remains part of the cluster's running index.

This is by design. The frozen index represents fees the operator earned up to the point of removal but that the cluster has not yet settled. Clusters holding multiple operators can still operate with reduced coverage after a removal; they are not force-liquidated. Settled or not, the amount owed to the removed operator is preserved in the index until the cluster next interacts with the protocol and settles the delta.

This behavior is documented in [FLOWS.md](https://github.com/ssvlabs/ssv-network/tree/v2.0.0/docs/FLOWS.md) and [SPEC.md](https://github.com/ssvlabs/ssv-network/tree/v2.0.0/docs/SPEC.md).
https://bugs.immunefi....ects/923/reports/75571
11 May 2026
Smart Contract	
Depositing to the cluster can prevent legit cluster operations.
Every cluster-related function takes the current cluster object as a caller-supplied input parameter. The caller must pass the exact state that was emitted by the last executed cluster function; if the on-chain cluster state has changed since that emission, the call reverts. This is by design: the pattern avoids extra gas costs by letting the caller supply and prove the current state.

Because `deposit` is permissionless, any actor can deposit even 1 wei to a cluster. That mutates the cluster object. A transaction that front-runs a legitimate cluster owner call (withdraw, liquidation, validator registration, etc.) with a 1-wei deposit will cause the owner's transaction to revert, since the cluster hash it carries is now stale.

This is a design trade-off, not a bug, and it is accepted for the following reasons:

- No sustained economic incentive. Repeatedly front-running a cluster requires running competitive block-inclusion infrastructure. The cost of maintaining that consistently outweighs any benefit, since the attacker gains nothing from the deposit itself and only delays the target operation by one transaction.
- Liquidations are self-correcting. Liquidators are off-chain services operating continuously to preserve cluster solvency. A single front-run delays one liquidation attempt by one block; the liquidator retries with the updated cluster state. The liquidation threshold and minimum collateral parameters are sized to absorb short delays without creating insolvency windows that make front-running economically attractive.
- Affected operations are retriable. Withdraw, register validators, and similar calls are owner-initiated and can simply be resubmitted with the updated cluster state. There is no permanent loss or irreversible failure from a single front-run.
https://bugs.immunefi....ects/923/reports/67215
11 May 2026
Smart Contract	
Overflows in operator/cluster accounting.
Operator and cluster fee accounting uses `uint64` arithmetic throughout. An example is the cluster balance update in `ClusterLib.updateBalanceSSV`:

```solidity
PackedSSV usage = PackedSSV.wrap((newIndex - cluster.index) * cluster.validatorCount + networkFee);
```

Intermediate products like `(newIndex - cluster.index) * cluster.validatorCount` are computed in `uint64`, so sufficiently large index deltas or validator counts could in principle overflow.

We ran simulations across the full range of current protocol parameters — maximum validators per operator (3,000), current SSV and ETH network fees, and the configured min/max operator fee bounds — and found no overflow under realistic operating conditions. An operator managing 3,000 validators and never withdrawing accumulated earnings for more than 10 years stays within `uint64` range. That scenario is already extreme well beyond any expected operational pattern.

This is accepted as a residual theoretical risk under the following rationale:

- Current protocol parameters (validator cap, fee bounds, network fee levels) keep all intermediate values comfortably within `uint64` for the foreseeable operational lifetime of the protocol.
- Operators and cluster owners have strong economic incentives to withdraw earnings and settle balances regularly, which resets the relevant accumulators and keeps deltas small in practice.
- Any future parameter changes (e.g., raising the validator cap or fees significantly) would need to re-evaluate this headroom before deployment.
https://bugs.immunefi...cts/923/reports/66362
11 May 2026
Smart Contract	
Cluster insolvency depends on liquidator liveness.

ETH cluster accounting settles operator and network fees before storing the updated cluster balance. In the effective-balance path, `ClusterLib.updateBalanceWithEB` computes pending usage and floors the balance at zero:

```solidity
cluster.balance = usage > cluster.balance ? 0 : cluster.balance - usage;
```

The same behavior exists in the state-mutating `updateClusterBalance` flow: operator and network fee deltas are applied first, and if the accrued usage exceeds the cluster balance, the in-memory balance is set to `0`. After that, active ETH clusters are checked against the liquidation rules and can be auto-liquidated in the same transaction.

This is an accepted liveness dependency, not a missing arithmetic check. The protocol has two liquidation signals:

- `minimumLiquidationCollateral`: an absolute collateral floor.
- `minimumBlocksBeforeLiquidation`: the burn-rate-based liquidation threshold, scaled by operator fees, network fee, and cluster vUnits.

These signals only protect the system when an actor actually calls `liquidate` or a path such as `updateClusterBalance` that performs the auto-liquidation check. Liquidators are therefore a core off-chain service for the protocol. If no liquidator or updater acts while a cluster moves below the minimum collateral or liquidation threshold, the contract does not autonomously stop time or liquidate the cluster.

Operational assumptions and mitigations:

- Liquidator services must continuously monitor both signals, not only zero balances.
- Liquidators should use view-computed balances that include pending operator and network fees, because stored cluster balances can be stale between interactions.
- Cluster owners should maintain a buffer above the larger of the minimum collateral floor and the burn-rate threshold, especially around EB updates, fee changes, and long periods without cluster interaction.
- Protocol parameter changes to fees, `minimumLiquidationCollateral`, or `minimumBlocksBeforeLiquidation` must preserve enough time and bounty for liquidators to act under normal network conditions.
https://bugs.immunefi...cts/923/reports/77910
13 May 2026
Smart Contract	
Per-operator validator capacity is a shared, first-come resource.

`validatorsPerOperatorLimit` (3,000) bounds the number of ETH validators an operator can run. The ETH counter `operator.ethValidatorCount` is checked on registration, on reactivation and on migration of a legacy cluster to ETH. See [OperatorLib.sol](https://github.com/ssvlabs/ssv-network/tree/v2.0.0/contracts/libraries/OperatorLib.sol) (registration line 213, reactivation line 322, migration line 375). The limit is set at initialization only ([SSVNetwork.sol](https://github.com/ssvlabs/ssv-network/tree/v2.0.0/contracts/SSVNetwork.sol) line 81) and has no governance setter.

Registration against a public operator is permissionless: the caller check only runs when `operator.whitelisted` is true (OperatorLib.sol line 183). Any actor can therefore fill a public operator's remaining capacity. Capacity is allocated first-come, with no per-owner share and no reservation.

This has two consequences, both accepted:

- New registrations can be blocked. Once an operator's `ethValidatorCount` reaches the limit, nobody else can register validators with it.
- Migration and reactivation can be blocked. Registration does not count the legacy validators an operator still carries in `operator.validatorCount`, so the ETH counter can reach the limit while legacy validators are waiting to migrate. `migrateClusterToETH` then reverts with `ExceedValidatorLimitWithData(operatorId)` for a legacy cluster that uses that operator, although migrating an active cluster only moves its validators from one counter to the other. `reactivate` has the same check.

Rationale for accepting:

- The attacker pays for as long as the slots are held. The occupying cluster must stay funded above the liquidation threshold and pays the operator's ETH fee and the network fee every block. The attacker gains nothing from it.
- It corrects itself. If the occupying cluster stops being funded, any liquidator can liquidate it, which decrements `ethValidatorCount` (OperatorLib.sol line 255) and frees the capacity.
- Operators can stop a refill. An operator owner can make the operator private, so only whitelisted addresses can register against it.
- No funds are at risk. A blocked legacy cluster keeps running on its legacy SSV balance. Its owner can liquidate it themselves at any time (`liquidateSSV` skips the liquidation test when the caller is the cluster owner) and recover the full SSV balance, or can remove the validators and register them with another operator set.
- The exposure shrinks over time. Legacy SSV clusters can no longer be created, so the migration leg ends when the transition completes. At block 25,907,586 there were 151 active legacy clusters with 418 validators, no operator carrying legacy validators was within 900 registrations of the limit, and the closest target needed 2,562 registrations, about 0.57 ETH of standing collateral and about 0.095 ETH per day to hold.

Operational guidance:

- Owners of legacy SSV clusters should migrate early. Before migrating, check each operator's `ethValidatorCount` (`SSVNetworkViews.getOperatorById`) against the cluster's validator count.
- Operators still serving legacy clusters close to the limit can go private until those clusters have migrated.
https://bugs.immunefi...cts/923/reports/88326
30 September 2026
Smart Contract	
Operator fee increase limit rounds up by one fee unit.

Operator ETH fees are stored in raw units of 100,000 wei per block. `declareOperatorFee` computes the highest allowed new fee with ceiling division:

```solidity
uint64 maxAllowedFee = (operatorFee.raw() * (BPS_DENOMINATOR + sp.operatorMaxFeeIncrease) + BPS_DENOMINATOR - 1) / BPS_DENOMINATOR;
```

See [SSVOperators.sol](https://github.com/ssvlabs/ssv-network/tree/v2.0.0/contracts/modules/SSVOperators.sol) (declareOperatorFee line 109, limit line 131). When `oldRaw × (10,000 + operatorMaxFeeIncrease)` is not a multiple of 10,000, the accepted maximum is one raw unit (100,000 wei per block) above the exact percentage limit.

Bounds:

- One declaration can exceed the exact limit by at most one raw unit. At the default fee (raw 17,788) and a 10% limit, the ceiling allows 19,567 instead of 19,566, an increase of 10.0011% instead of 10%. Near the minimum fee (raw 100 on mainnet) the relative error is largest: raw 101 can move to 112 instead of 111, an increase of 10.89%.
- In absolute terms the extra unit costs a cluster 100,000 wei per block per 32 ETH of effective balance for each affected operator: about 0.00000026 ETH per year for a 32 ETH validator, and about 0.0000168 ETH per year for a 2,048 ETH validator.
- The rounding can compound across successive increases, because each rounded fee becomes the base of the next one. Both paths remain capped by `operatorMaxFee`, which is checked at declaration and at execution. Starting from raw 101 at a 10% limit, the ceiling path reaches the cap one 14-day declaration cycle before the floor path.

Rationale for accepting:

- The difference is negligible compared with the fee itself.
- Every increase is public before it applies. `declareOperatorFee` emits `OperatorFeeDeclared`, and the new fee can only be executed after the declaration period (14 days on mainnet). Cluster owners see the exact new fee during that period and can decide whether to stay with the operator or move to another one.
- The limit on the size of a single increase is a rate control, not a price guarantee. The absolute ceiling, `operatorMaxFee`, is enforced exactly.
https://bugs.immunefi...cts/923/reports/83904

