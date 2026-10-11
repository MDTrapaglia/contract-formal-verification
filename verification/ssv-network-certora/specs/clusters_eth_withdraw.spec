using SSVClustersCertoraHarness as ssv;

methods {
    function certoraSetClusterVUnits(bytes32,uint64[],uint32,uint64) external envfree;
    function certoraETHBurnRate(uint64[]) external returns(uint64) envfree;
    function certoraStoredETHClusterHash(bytes32) external returns(bytes32) envfree;
    function certoraWouldETHWithdrawLeaveLiquidatable(ISSVNetworkCore.Cluster,bytes32,uint64,uint256) external returns(bool) envfree;
    function certoraExpectedETHWithdrawHash(ISSVNetworkCore.Cluster,uint256) external returns(bytes32) envfree;
    function certoraBaselineVUnits(uint32) external returns(uint64) envfree;
}

rule successfulWithdrawPreservesETHSolvency(
    env e,
    address owner,
    uint64[] operatorIds,
    ISSVNetworkCore.Cluster cluster,
    uint64 ethNetworkFee,
    uint64 minBlocksBeforeLiquidation,
    uint64 minCollateral,
    uint64 explicitVUnits,
    uint256 amount
) {
    require owner != 0;
    require owner != currentContract;
    require e.msg.sender == owner;
    require e.msg.value == 0;
    require e.block.number > 0;
    require e.block.number <= max_uint32;

    require operatorIds.length == 4;
    require operatorIds[0] != 0;
    require operatorIds[0] < operatorIds[1];
    require operatorIds[1] < operatorIds[2];
    require operatorIds[2] < operatorIds[3];

    require cluster.active;
    require cluster.validatorCount > 0;
    require cluster.validatorCount <= 100;
    require minBlocksBeforeLiquidation > 0;
    require minCollateral > 0;
    require nativeBalances[currentContract] >= cluster.balance;

    ssv.certoraSetETHProtocol(e, ethNetworkFee, cluster.networkFeeIndex, minBlocksBeforeLiquidation, minCollateral);
    bytes32 clusterId = ssv.certoraSetETHCluster(e, owner, operatorIds, cluster);

    uint64 baseline = ssv.certoraBaselineVUnits(cluster.validatorCount);
    require explicitVUnits == 0 || explicitVUnits >= baseline;
    if (explicitVUnits != 0) {
        ssv.certoraSetClusterVUnits(clusterId, operatorIds, cluster.validatorCount, explicitVUnits);
    }

    uint64 burnRate = ssv.certoraETHBurnRate(operatorIds);
    withdraw@withrevert(e, operatorIds, amount, cluster);
    bool withdrawReverted = lastReverted;

    if (!withdrawReverted) {
        assert amount <= cluster.balance;
        assert !ssv.certoraWouldETHWithdrawLeaveLiquidatable(cluster, clusterId, burnRate, amount);
        assert ssv.certoraStoredETHClusterHash(clusterId) == ssv.certoraExpectedETHWithdrawHash(cluster, amount);
    }
    assert withdrawReverted || amount <= cluster.balance;
}

rule solventETHWithdrawCanSucceed(
    env e,
    address owner,
    uint64[] operatorIds,
    ISSVNetworkCore.Cluster cluster
) {
    require owner != 0;
    require owner != currentContract;
    require e.msg.sender == owner;
    require e.msg.value == 0;
    require e.block.number > 0;
    require e.block.number <= max_uint32;
    require operatorIds.length == 4;
    require operatorIds[0] != 0;
    require operatorIds[0] < operatorIds[1];
    require operatorIds[1] < operatorIds[2];
    require operatorIds[2] < operatorIds[3];
    require cluster.active;
    require cluster.validatorCount > 0;
    require nativeBalances[currentContract] >= cluster.balance;

    ssv.certoraSetETHProtocol(e, 0, cluster.networkFeeIndex, 1, 1);
    ssv.certoraSetETHCluster(e, owner, operatorIds, cluster);
    withdraw@withrevert(e, operatorIds, 1, cluster);
    satisfy !lastReverted, "an active solvent ETH cluster can execute a nonzero withdrawal";
}

rule successfulAccruedETHWithdrawPreservesSolvency(
    env e,
    address owner,
    uint64[] operatorIds,
    ISSVNetworkCore.Cluster cluster,
    uint64 ethNetworkFee,
    uint64 operatorFee,
    uint64 minBlocksBeforeLiquidation,
    uint64 minCollateral,
    uint64 explicitVUnits,
    uint32 accrualStartBlock,
    uint256 amount
) {
    require owner != 0;
    require owner != currentContract;
    require e.msg.sender == owner;
    require e.msg.value == 0;
    require e.block.number > 0;
    require e.block.number <= max_uint32;
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
    require nativeBalances[currentContract] >= cluster.balance;

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
    if (explicitVUnits != 0) {
        ssv.certoraSetClusterVUnits(clusterId, operatorIds, cluster.validatorCount, explicitVUnits);
    }

    withdraw@withrevert(e, operatorIds, amount, cluster);
    bool withdrawReverted = lastReverted;
    if (!withdrawReverted) {
        assert !ssv.certoraCurrentETHWithdrawIsLiquidatable(e, cluster, clusterId, operatorIds, amount);
        assert ssv.certoraStoredETHClusterHash(clusterId) ==
            ssv.certoraCurrentETHWithdrawHash(e, cluster, clusterId, operatorIds, amount);
    }
    assert withdrawReverted || amount <= cluster.balance;
}

rule accruedETHWithdrawCanSucceedWithNonzeroFees(
    env e,
    address owner,
    uint64[] operatorIds,
    ISSVNetworkCore.Cluster cluster,
    uint32 accrualStartBlock
) {
    require owner != 0;
    require owner != currentContract;
    require e.msg.sender == owner;
    require e.msg.value == 0;
    require e.block.number > 1;
    require e.block.number <= max_uint32;
    require accrualStartBlock > 0;
    require accrualStartBlock < e.block.number;
    require e.block.number - accrualStartBlock <= 1000000;
    require operatorIds.length == 4;
    require operatorIds[0] != 0;
    require operatorIds[0] < operatorIds[1];
    require operatorIds[1] < operatorIds[2];
    require operatorIds[2] < operatorIds[3];
    require cluster.active;
    require cluster.validatorCount > 0;
    require cluster.validatorCount <= 100;
    require nativeBalances[currentContract] >= cluster.balance;
    require cluster.index <= max_uint64 - 4000000000000000;
    require cluster.networkFeeIndex <= max_uint64 - 1000000000000000;

    ssv.certoraSetETHProtocolWithAccrual(e, 1, cluster.networkFeeIndex, 1, 1, accrualStartBlock);
    ssv.certoraSetETHClusterWithAccrual(e, owner, operatorIds, cluster, 1, accrualStartBlock);
    withdraw@withrevert(e, operatorIds, 1, cluster);
    satisfy !lastReverted, "withdraw can succeed after positive operator and network fees accrue";
}
