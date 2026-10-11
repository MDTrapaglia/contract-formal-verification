using SSVClustersCertoraHarness as ssv;

methods {
    function certoraSetClusterVUnits(bytes32,uint64[],uint32,uint64) external envfree;
    function certoraStoredETHClusterHash(bytes32) external returns(bytes32) envfree;
    function certoraExpectedLiquidatedETHClusterHash(ISSVNetworkCore.Cluster) external returns(bytes32) envfree;
    function certoraETHDaoValidatorCount() external returns(uint32) envfree;
    function certoraDAOTotalETHVUnits() external returns(uint64) envfree;
    function certoraOperatorETHValidatorCount(uint64) external returns(uint32) envfree;
    function certoraOperatorETHVUnits(uint64) external returns(uint64) envfree;
    function certoraBaselineVUnits(uint32) external returns(uint64) envfree;
}

rule successfulInsolventETHLiquidationSettlesAccounting(
    env e,
    address owner,
    address liquidator,
    uint64[] operatorIds,
    ISSVNetworkCore.Cluster cluster,
    uint64 minCollateral,
    uint64 explicitVUnits
) {
    require owner != 0;
    require liquidator != 0;
    require liquidator != owner;
    require liquidator != currentContract;
    require e.msg.sender == liquidator;
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
    require minCollateral > 0;
    require nativeBalances[currentContract] >= cluster.balance;
    require nativeBalances[liquidator] <= max_uint256 - cluster.balance;

    ssv.certoraSetETHProtocol(e, 0, cluster.networkFeeIndex, 1, minCollateral);
    bytes32 clusterId = ssv.certoraSetETHCluster(e, owner, operatorIds, cluster);

    uint64 baseline = ssv.certoraBaselineVUnits(cluster.validatorCount);
    require explicitVUnits == 0 || explicitVUnits >= baseline;
    if (explicitVUnits != 0) {
        ssv.certoraSetClusterVUnits(clusterId, operatorIds, cluster.validatorCount, explicitVUnits);
    }

    require ssv.certoraIsCurrentETHClusterLiquidatable(e, cluster, clusterId, operatorIds);

    mathint protocolBalanceBefore = nativeBalances[currentContract];
    mathint liquidatorBalanceBefore = nativeBalances[liquidator];
    liquidate@withrevert(e, owner, operatorIds, cluster);
    bool liquidationReverted = lastReverted;

    if (!liquidationReverted) {
        assert ssv.certoraStoredETHClusterHash(clusterId) ==
            ssv.certoraExpectedLiquidatedETHClusterHash(cluster);
        assert ssv.certoraETHDaoValidatorCount() == 0;
        assert ssv.certoraDAOTotalETHVUnits() == 0;
        assert ssv.certoraOperatorETHValidatorCount(operatorIds[0]) == 0;
        assert ssv.certoraOperatorETHValidatorCount(operatorIds[1]) == 0;
        assert ssv.certoraOperatorETHValidatorCount(operatorIds[2]) == 0;
        assert ssv.certoraOperatorETHValidatorCount(operatorIds[3]) == 0;
        assert ssv.certoraOperatorETHVUnits(operatorIds[0]) == 0;
        assert ssv.certoraOperatorETHVUnits(operatorIds[1]) == 0;
        assert ssv.certoraOperatorETHVUnits(operatorIds[2]) == 0;
        assert ssv.certoraOperatorETHVUnits(operatorIds[3]) == 0;
        assert nativeBalances[currentContract] == protocolBalanceBefore - cluster.balance;
        assert nativeBalances[liquidator] == liquidatorBalanceBefore + cluster.balance;
    }

    satisfy !liquidationReverted && cluster.balance > 0,
        "a third party can liquidate an insolvent ETH cluster and receive its positive balance";
}
