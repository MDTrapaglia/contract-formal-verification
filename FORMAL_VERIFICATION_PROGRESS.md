# Formal verification continuation log

## 2026-10-11 UTC — ETH liquidation with accrued fees

- Strengthened `thirdPartyCannotLiquidateSolventETH` to initialize operator and
  protocol snapshots at a symbolic earlier block and to use symbolic operator
  and network fees.
- Bounded elapsed accrual and the liquidation period to 1,000,000 blocks, fees
  to 1,000,000,000 packed units, and explicit vUnits to 100,000,000. The index
  headroom assumptions keep modeled `uint64` additions in range; the vUnits
  bound also keeps accrued operator/DAO balances within their packed range.
- The independent liquidation helper already skips inactive snapshots as the
  execution path does. This rule initializes all four operators active, so
  mixed active/inactive operator sets remain a separate domain extension.
- Added a `satisfy` witness requiring positive operator and network fees plus at
  least one elapsed block. Certora found a solvent witness with those
  conditions and found the universal rule non-vacuous.
- CVL formatting and direct local Certora compilation passed. The existing
  `SSVViews.getOperatorFee` warning remains unchanged.
- Cloud verification completed with exit code 0 and `No errors found by
  Prover!`; view equivalence, third-party revert, and stored-hash preservation
  all passed:
  <https://prover.certora.com/output/10390566/7e7ac39862a74b6fb1def7749be41181>.

## 2026-10-11 UTC — Certora legacy SSV liquidation

- Continued with view-versus-liquidation equivalence for both accounting modes.
- The first ETH attempt exposed a reference-helper mismatch: it checked the
  input balance without accruing operator/network fees, unlike the view. The
  corrected ETH helper now reconstructs current indices and settles balance.
- The first ETH and SSV runs with dynamic `new SSVViews` + `delegatecall` both
  failed the view equality assertion. Certora's scene contained only the
  harness and precompiles, not the dynamically deployed `SSVViews` instance.
  Replaced that adapter with direct inherited `SSVViews` code in the harness;
  no production contract was changed.
- Formatter and local Certora compilation passed after the inheritance change.
  Cloud proof passed for ETH:
  <https://prover.certora.com/output/10390566/2e4be3096085456dba076982a58a55df>.
  The universal third-party rule passed, the owner reachability witness passed,
  and the basic sanity run found a reachable solvent state.
- Cloud proof passed for SSV:
  <https://prover.certora.com/output/10390566/9df9c62b7d44466487645cfacbec06c3>.
  The universal third-party rule passed, the owner witness passed, and the
  sanity run found a reachable solvent state.
- Both final cloud runs completed with exit code 0 and `No errors found by
  Prover!`. Earlier failed adapter runs are retained in Certora history but
  were modeling artifacts, not evidence of protocol defects.
- The existing Solidity warning in `SSVViews.getOperatorFee` remains and is
  ignored by the formal configurations; this unrelated production code was not
  changed.

- Read `PLAN_VALIDACION_Y_BUSQUEDA_VULNERABILIDADES_SSV.md` and selected the
  first recommended backlog item: formalize
  `thirdPartyCannotLiquidateSolventSSV`.
- Preserved the existing dirty worktree, including all HEVM/Kontrol changes.
  Certora work is isolated to `certora/`, `package.json`, and this log.
- Extended `SSVClustersCertoraHarness` with legacy SSV state constructors and
  observation helpers. The harness initializes the legacy cluster hash,
  operator SSV snapshots/counts, protocol and DAO indices/counts, liquidation
  parameters, and reentrancy guard consistently at the symbolic block.
- Added `certora/specs/clusters_ssv.spec` with:
  - `thirdPartyCannotLiquidateSolventSSV`: a non-owner call against an active,
    solvent legacy cluster must revert and preserve its stored hash;
  - `ownerMayAttemptSelfLiquidationSSV`: a concrete reachability witness for
    the intentional owner exception.
- Added `certora/conf/clusters-ssv.conf`,
  `certora/scripts/run-clusters-ssv.sh`, and the npm commands
  `certora:ssv:check` / `certora:ssv:verify`.
- CVL formatting/syntax validation passed with Certora CLI 8.19.2.
- The normal local wrapper stopped during `npm run build` because the existing
  untracked `test/kontrol/KontrolPrankSmoke.t.sol` imports `forge-std/Test.sol`,
  while `forge-std` is not installed for Hardhat. No Kontrol file was changed.
- Direct Certora local compilation (`--compilation_steps_only`) passed with
  Solidity 0.8.24 and the Cancun EVM target.
- Cloud verification completed successfully with exit code 0 and
  `No errors found by Prover!`:
  <https://prover.certora.com/output/10390566/57f266b01d0147ca983c8cd10df96431>.
- Certora proved the third-party rule, found a reachable state in its basic
  non-vacuity check, and found a valid owner self-liquidation witness.
- Identified the initial limitation that the SSV model fixed operator fees to
  zero and began all snapshots at the verification block; selected elapsed fee
  accrual and ETH withdraw solvency as the next two tasks.
- Strengthened the SSV rule with symbolic operator/network fees and up to
  1,000,000 elapsed blocks. Explicit bounds keep all modeled `uint64`
  intermediate products within range instead of making overflow reverts prune
  the proof domain implicitly.
- The first strengthened cloud run
  (<https://prover.certora.com/output/10390566/077b949770fb44f8bff78e632cd0504e>)
  failed because `certoraIsCurrentSSVClusterLiquidatable` was incorrectly
  declared `envfree` despite reading `block.number`. The resulting apparent
  counterexample evaluated the helper and `liquidateSSV` in different block
  environments. This was a specification artifact, not a protocol finding.
- Removed `envfree` from that helper and passed the rule's `env e` explicitly.
  The corrected strengthened SSV job completed with exit code 0, proved the
  universal rule, found it non-vacuous, and retained the owner witness:
  <https://prover.certora.com/output/10390566/5a3c66d9b2a141fd87a36f44b7de8cd8>.
- Added `clusters_eth_withdraw.spec`, its configuration and runner, plus the npm
  commands `certora:withdraw:check` and `certora:withdraw:verify`.
- `successfulWithdrawPreservesETHSolvency` proves that any successful withdrawal
  from an active ETH cluster with validators leaves the expected stored hash
  and a non-liquidatable post-state. It covers symbolic amounts, implicit or
  explicit vUnits, and symbolic fee/liquidation parameters.
- Captured `lastReverted` immediately after the target call so later observation
  helpers cannot change the rule's interpretation of withdrawal success.
- `solventETHWithdrawCanSucceed` produced a concrete successful witness for a
  nonzero withdrawal, complementing the universal rule and its basic sanity
  check.
- Final ETH withdrawal cloud job completed with exit code 0 and
  `No errors found by Prover!`:
  <https://prover.certora.com/output/10390566/a4f63447e4044b29ae74e150d7871012>.
- Extended the ETH withdrawal harness to initialize operator and protocol
  snapshots at a symbolic earlier block, with symbolic nonzero operator and
  network fees. Its reference helpers calculate the same live operator index,
  network index, fee settlement, post-withdrawal liquidation state, and cluster
  hash independently from the target call.
- Added `successfulAccruedETHWithdrawPreservesSolvency` with up to 1,000,000
  elapsed blocks, fee bounds of 1,000,000,000 packed units, and the same
  implicit/explicit vUnits coverage.
- Added `accruedETHWithdrawCanSucceedWithNonzeroFees`, requiring positive
  operator and network fees, at least one elapsed block, and a successful
  nonzero withdrawal. Certora found a satisfying witness.
- Final accrued-fee withdrawal job completed with exit code 0 and
  `No errors found by Prover!`:
  <https://prover.certora.com/output/10390566/adda14406f9a4e20860b0db293eb0434>.
- Both universal withdrawal rules passed; the cloud rule-sanity checks found
  reachable states. Non-vacuity witness for the accrued path specifically has
  `accrualStartBlock=1`, `block.number=2`, positive fees and successful
  withdrawal.

## 2026-10-10 UTC

- Resumed work from `repos/ssv-network/FORMAL_VERIFICATION_HANDOFF.md`.
- Created `FORMAL_VERIFICATION_TOOL_OUTPUT.log` for command/tool output.
- Read the handoff and Kontrol chronology completely. The authorized next step is K-1.7: rebuild with `--regen`, verify `KONTROL-FULL`, then run the named proof with `--reinit --max-frontier-parallel 4`.
- Confirmed the repository is ahead of `origin/main` with the expected modified/untracked formal-verification artifacts; no existing work will be discarded.
- K-1.7 build started at 15:21:42 UTC and completed successfully (exit 0) in about 60 seconds. Raw build log: `repos/ssv-network/kontrol/logs/20261010T152142Z-build.log`.
- Verified `out-kontrol/kompiled/foundry.k` imports `KONTROL-FULL`.
- K-1.7 proof version 2 started at 15:23:08 UTC with 15 symbolic arguments and `--reinit --max-frontier-parallel 4`. At 15:31 UTC it was active with 23 nodes, 1 pending, 0 failing, 0 vacuous/stuck/bounded and 2 terminal nodes; the backend was consuming CPU, so execution was allowed to continue.
- K-1.7 was interrupted cleanly at 18:51 UTC after about 3 h 28 min. Final persisted state: PENDING, 54 nodes, 7 pending, 2 terminal, 0 failing/vacuous/stuck/bounded. Peak observed backend RSS was about 5.4 GiB with ~240% CPU. This is inconclusive, not a property failure.
- Inspected all seven K-1.7 frontiers: they are symbolic storage lookups in `ClusterLib.getClusterData` during the real `liquidate` call. Added K-1.8 assumptions separating the derived `clusters`, `ethClusters`, and `clusterEB` slots from each other and from operator words 0/3/4, while retaining symbolic IDs.
- Forge replay/fuzz validation after K-1.8 passed: 3 tests, 0 failures (including 256 fuzz runs). `forge fmt --check` reported existing whole-file formatting differences; no automatic reformat was applied.
- K-1.8 regenerated build succeeded at 18:56 UTC and imports `KONTROL-FULL`; version 3 started at 18:57:18 UTC. First checkpoint at 19:00 UTC: PENDING, 17 nodes, 1 pending, 2 terminal, 0 failing/vacuous/stuck/bounded.
- K-1.8 was interrupted after 44m52s: PENDING at 32 nodes/1 frontier, 0 failures, ~2.7 GiB RSS. The frontier was the successful pre-call `certoraStoredETHClusterHash` return, not `getClusterData`. K-1.9 now computes the known initialized hash purely and retains the post-revert storage assertion.
- K-1.9 Forge validation passed (3 tests, 0 failures), regenerated build succeeded with `KONTROL-FULL`, and proof version 4 started at 19:44:41 UTC. First checkpoint: 17 nodes/1 pending, 2 terminal, 0 failing/vacuous/stuck/bounded.
- K-1.9 was interrupted after 45m21s: PENDING at 31/1, 0 failures, ~2.8 GiB RSS. Its frontier was still processing the solvency `vm.assume`s under the accumulated Keccak/layout constraints. K-1.10 moves those unchanged arithmetic assumptions before storage setup.
- K-1.10 Forge validation passed (3 tests), regenerated `KONTROL-FULL` build succeeded, and proof version 5 started at 20:32:57 UTC. First checkpoint: 15 nodes/1 pending, 2 terminal, 0 failing/vacuous/stuck/bounded.
- K-1.10 was interrupted after 45m10s: PENDING at 32/1, 0 failures, ~2.7 GiB RSS. It reached `_callLiquidate` but stalled at `EXTCODESIZE` for the late `vm.prank` cheatcode call. K-1.11 starts the persistent prank before symbolic storage setup and removes that late cheatcode lookup; setup setters are sender-independent.
- K-1.11's differential replay passed, but the proof created no persisted KCFG after 10 minutes while using ~234% CPU/~1.76 GiB RSS. It was interrupted and its code changes were removed; logs remain. The active source is restored to K-1.10.
- Restored K-1.10 passed 3/3 Forge tests and was rebuilt successfully with `KONTROL-FULL` (`20261010T213220Z-build.log`). No Kontrol process remains active.

## 2026-10-11 UTC

- Preparé `repos/ssv-network/AUXILIARY_INVESTIGATION_PLAN.md` para que otro agente investigue K-1.16: diagnóstico de la frontera `ClusterLib`/storage/Keccak y, en una línea separada, obligación de simetría del caller. Incluye antecedentes, toolchain/rutas, cautelas del KCFG compartido, comandos, límites de afirmaciones y formato de informe por agente para centralización posterior. No se ejecutó otra proof ni se cambió código de producción.

- Iniciado K-1.15 según el handoff: se preparó una variante que fija únicamente `caller = 0xBEEF`, manteniendo simbólicos owner, cuatro IDs, balance, fees, block y demás parámetros. Por el límite Yul descrito abajo, el entrypoint canonical activo terminó reemplazado temporalmente; el KCFG de K-1.13 conserva la corrida general anterior.
- Añadido replay concreto del rechazo de liquidación solvente para `0xBEEF`; se conservará también la comparación preexistente packed-vs-regular. Siguiente: Forge focalizado, build `--regen` y ejecución formal con tope de 20 minutos.
- Forge focalizado pasó: 2/2 (replay del caller fijo y equivalencia packed-vs-regular). El primer build falló por Yul stack-too-deep al duplicar el entrypoint grande; se reemplazó temporalmente el entrypoint canonical activo por su variante `FixedCaller` (sin cuerpo duplicado), preservando el KCFG K-1.13. `kontrol build --regen` pasó y se verificó `KONTROL-FULL` (`kontrol/logs/20261011T192714Z-build.log`).
- K-1.15 versión 0 corrió con tope externo de 20 minutos (`20261011T192803Z-SSVClustersLiquidationKontrolTest.prove_thirdPartyCannotLiquidateSolventETHDefaultVUnitsPackedCanonicalSlotsFixedCaller.log`). Final: PENDING, llegó al nodo 39, con 1 frontera pendiente en `liquidate`/`ClusterLib` (source `contracts/libraries/ClusterLib.sol:339`, PC 20774 de `SSVClustersHEVMHarness.liquidate`), sin failing/counterexample. La frontera avanzó más allá del prank assembly de K-1.13 (nodo 34, PC 8598), pero no completó la proof.
- El límite terminó limpiamente; no quedaron procesos Kontrol/booster/Z3 activos. K-1.15 solo cubre el caller concreto `0xBEEF`; no generalizar a callers arbitrarios sin una obligación de simetría independiente.

- Started K-1.12 to isolate the late symbolic `vm.prank` bottleneck from K-1.10.
- Added the independent `KontrolPrankSmokeTest`, with equivalent high-level and low-level prank obligations and a concrete semantic replay.
- The concrete low-level cheatcode call passed in Forge: 1 test, 0 failures. Next: regenerate the formal build and compare both smoke proofs before changing K-1.
- The regenerated definition imports `KONTROL-FULL`. Both symbolic smoke proofs passed: low-level prank in 1m17s and high-level prank in 1m12s. This establishes semantic equivalence in isolation; the costly behavior is contextual to K-1's accumulated path condition.
- K-1.12 now replaces only K-1's typed prank call with the validated low-level cheatcode call, eliminating its generated `EXTCODESIZE` without changing the shared HEVM harness.
- K-1.12 passed all 4 relevant Forge tests and rebuilt successfully with `KONTROL-FULL` (`20261011T134855Z-build.log`). Formal version 7 started at 13:50 UTC with a hard 45-minute cap.
- Version 7 reached node 34 in about 16 minutes, then entered a long SMT query at `MLOAD`, PC 8583, still in the test contract and before the productive harness call. The persisted checkpoint and diagnostic are in `20261011T1413Z-K1.12-version7-node34-checkpoint.log`; execution remains controlled by the cap.
- K-1.12 hit the 45-minute cap as PENDING at node 34, with 2 terminal nodes and no counterexample/failing node. No process remained active. Final checkpoint: `20261011T1435Z-K1.12-version7-final-checkpoint.log`.
- Source-map decoding tied the expensive continuation after PC 8583 to `abi.encodeWithSelector(PRANK_SELECTOR, caller)`. K-1.13 replaces that encoder with a 36-byte assembly `CALL` using scratch memory.
- The K-1.13 assembly prank passed concrete Forge tests and its symbolic smoke proof passed in 43s (`20261011T143849Z-KontrolPrankSmokeTest.prove_assemblyPrank.log`).
- K-1.13 version 8 reached node 34 in ~16 minutes but remained there until its 20-minute diagnostic cap. Source-map inspection places PC 8598 inside the assembly prank, before its second `MSTORE`; final checkpoint: `20261011T1502Z-K1.13-version8-final-checkpoint.log`.
- A concrete test and a 40s symbolic proof confirmed that a one-shot assembly prank survives a subsequent `vm.assume` cheatcode call (`20261011T150522Z-KontrolPrankSmokeTest.prove_assemblyPrankSurvivesAssume.log`).
- K-1.14 moves the prank to immediately after packed storage initialization and before the expensive cluster/operator slot assumptions. It remains one-shot for `liquidate`, unlike the regressive early `startPrank` experiment.
- K-1.14 version 9 regressed: at the 20-minute cap it remained PENDING at node 22, returning from `hevmSetETHCluster4Packed`, with 2 terminal nodes and no failing/counterexample. Final checkpoint: `20261011T1529Z-K1.14-version9-final-checkpoint.log`.
- The K-1.14 ordering change was removed. The active K-1 source is restored to K-1.13; the successful prank-survives-assume smoke tests remain as diagnostic evidence.
- Restored K-1.13 passed all 6 relevant Forge tests and was rebuilt successfully with `KONTROL-FULL`; active build log: `20261011T153055Z-build.log`.
- Updated `FORMAL_VERIFICATION_HANDOFF.md` through K-1.14. The next bounded experiment is K-1.15: a fixed non-special caller baseline retaining symbolic owner, operator IDs, and economic parameters, explicitly reported as a domain reduction unless accompanied by a caller-symmetry obligation.
- No Kontrol, booster, Z3, Forge, or build process remains active. Raw command/tool output is preserved in `FORMAL_VERIFICATION_TOOL_OUTPUT.log` (about 2.4 MiB); Kontrol logs are about 1.2 MiB and preserved KCFG artifacts about 1.2 GiB.

