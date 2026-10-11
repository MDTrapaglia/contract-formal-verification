using SSVClustersCertoraHarness as ssv;

methods {
    function certoraSetClusterVUnits(bytes32,uint64[],uint32,uint64) external envfree;
    function certoraETHBurnRate(uint64[]) external returns(uint64) envfree;
    function certoraStoredETHClusterHash(bytes32) external returns(bytes32) envfree;
    function certoraHashClusterData(ISSVNetworkCore.Cluster) external returns(bytes32) envfree;
    function certoraBaselineVUnits(uint32) external returns(uint64) envfree;
}

rule thirdPartyCannotLiquidateSolventETH(
    env e,
    address owner,
    address caller,
    uint64[] operatorIds,
    ISSVNetworkCore.Cluster cluster,
    uint64 ethNetworkFee,
    uint64 operatorFee,
    uint64 minBlocksBeforeLiquidation,
    uint64 minCollateral,
    uint64 explicitVUnits,
    uint32 accrualStartBlock
) {
    require owner != 0;
    require caller != 0;
    require caller != owner;
    require e.msg.sender == caller;
    require e.block.number > 0, "operator snapshots use zero as the inactive sentinel";
    require e.block.number <= max_uint32, "the deployed protocol stores snapshot blocks as uint32";
    require accrualStartBlock > 0;
    require accrualStartBlock <= e.block.number;
    require e.block.number - accrualStartBlock <= 1000000;

    require operatorIds.length == 4;
    require operatorIds[0] != 0;
    require operatorIds[0] < operatorIds[1];
    require operatorIds[1] < operatorIds[2];
    require operatorIds[2] < operatorIds[3];

    require cluster.active;
    require cluster.validatorCount > 0;
    require cluster.validatorCount <= 100;
    require minBlocksBeforeLiquidation > 0;
    require minBlocksBeforeLiquidation <= 1000000;
    require minCollateral > 0;
    require ethNetworkFee <= 1000000000;
    require operatorFee <= 1000000000;
    require cluster.index <= max_uint64 - 4000000000000000;
    require cluster.networkFeeIndex <= max_uint64 - 1000000000000000;
    require nativeBalances[currentContract] >= cluster.balance, "protocol ETH covers this cluster balance";

    ssv.certoraSetETHProtocolWithAccrual(
        e,
        ethNetworkFee,
        cluster.networkFeeIndex,
        minBlocksBeforeLiquidation,
        minCollateral,
        accrualStartBlock
    );
    bytes32 clusterId = ssv.certoraSetETHClusterWithAccrual(
        e,
        owner,
        operatorIds,
        cluster,
        operatorFee,
        accrualStartBlock
    );

    uint64 baseline = ssv.certoraBaselineVUnits(cluster.validatorCount);
    require explicitVUnits == 0 || explicitVUnits >= baseline;
    require explicitVUnits <= 100000000;
    if (explicitVUnits != 0) {
        ssv.certoraSetClusterVUnits(clusterId, operatorIds, cluster.validatorCount, explicitVUnits);
    }

    bool liquidatable = ssv.certoraIsCurrentETHClusterLiquidatable(e, cluster, clusterId, operatorIds);
    bool viewLiquidatable = ssv.isLiquidatable(e, owner, operatorIds, cluster);
    assert viewLiquidatable == liquidatable;
    require !liquidatable;
    satisfy operatorFee > 0 && ethNetworkFee > 0 && accrualStartBlock < e.block.number,
        "a solvent ETH cluster is reachable after positive operator and network fees accrue";

    bytes32 beforeHash = ssv.certoraStoredETHClusterHash(clusterId);
    liquidate@withrevert(e, owner, operatorIds, cluster);

    assert lastReverted;
    assert ssv.certoraStoredETHClusterHash(clusterId) == beforeHash;
}

rule ownerMayAttemptSelfLiquidationETH(
    env e,
    address owner,
    uint64[] operatorIds,
    ISSVNetworkCore.Cluster cluster
) {
    require owner != 0;
    require e.msg.sender == owner;
    require e.block.number > 0, "operator snapshots use zero as the inactive sentinel";
    require e.block.number <= max_uint32, "the deployed protocol stores snapshot blocks as uint32";
    require operatorIds.length == 4;
    require operatorIds[0] != 0;
    require operatorIds[0] < operatorIds[1];
    require operatorIds[1] < operatorIds[2];
    require operatorIds[2] < operatorIds[3];
    require cluster.active;
    require cluster.validatorCount > 0;
    require nativeBalances[currentContract] >= cluster.balance, "protocol ETH covers this cluster balance";

    ssv.certoraSetETHProtocol(e, 1, cluster.networkFeeIndex, 1, 1);
    ssv.certoraSetETHCluster(e, owner, operatorIds, cluster);
    liquidate@withrevert(e, owner, operatorIds, cluster);
    satisfy !lastReverted, "an owner can execute self-liquidation in at least one valid state";
}
