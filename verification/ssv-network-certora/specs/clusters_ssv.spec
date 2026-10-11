using SSVClustersCertoraHarness as ssv;

methods {
    function certoraStoredSSVClusterHash(bytes32) external returns(bytes32) envfree;
}

rule thirdPartyCannotLiquidateSolventSSV(
    env e,
    address owner,
    address caller,
    uint64[] operatorIds,
    ISSVNetworkCore.Cluster cluster,
    uint64 networkFee,
    uint64 operatorFee,
    uint64 minBlocksBeforeLiquidation,
    uint64 minCollateral,
    uint32 snapshotBlock
) {
    require owner != 0;
    require caller != 0;
    require caller != owner;
    require e.msg.sender == caller;
    require e.block.number > 0, "operator snapshots use zero as the inactive sentinel";
    require e.block.number <= max_uint32, "the deployed protocol stores snapshot blocks as uint32";
    require snapshotBlock > 0;
    require snapshotBlock <= e.block.number;
    require e.block.number - snapshotBlock <= 1000000;

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
    require networkFee <= 1000000000;
    require operatorFee <= 1000000000;
    require cluster.index <= max_uint64 - 4000000000000000;
    require cluster.networkFeeIndex <= max_uint64 - 1000000000000000;

    ssv.certoraSetSSVProtocol(
        e,
        networkFee,
        cluster.networkFeeIndex,
        minBlocksBeforeLiquidation,
        minCollateral,
        snapshotBlock
    );
    bytes32 clusterId = ssv.certoraSetSSVCluster(e, owner, operatorIds, cluster, operatorFee, snapshotBlock);

    bool liquidatable = ssv.certoraIsCurrentSSVClusterLiquidatable(e, cluster, operatorIds);
    bool viewLiquidatable = ssv.isLiquidatableSSV(e, owner, operatorIds, cluster);
    assert viewLiquidatable == liquidatable;
    require !liquidatable;

    bytes32 beforeHash = ssv.certoraStoredSSVClusterHash(clusterId);
    liquidateSSV@withrevert(e, owner, operatorIds, cluster);

    assert lastReverted;
    assert ssv.certoraStoredSSVClusterHash(clusterId) == beforeHash;
}

rule ownerMayAttemptSelfLiquidationSSV(
    env e,
    address owner,
    uint64[] operatorIds,
    ISSVNetworkCore.Cluster cluster,
    uint32 snapshotBlock
) {
    require owner != 0;
    require e.msg.sender == owner;
    require e.block.number > 0, "operator snapshots use zero as the inactive sentinel";
    require e.block.number <= max_uint32, "the deployed protocol stores snapshot blocks as uint32";
    require snapshotBlock == e.block.number;
    require operatorIds.length == 4;
    require operatorIds[0] != 0;
    require operatorIds[0] < operatorIds[1];
    require operatorIds[1] < operatorIds[2];
    require operatorIds[2] < operatorIds[3];
    require cluster.active;
    require cluster.validatorCount > 0;
    require cluster.balance == 0, "avoid modeling an external token transfer in this reachability witness";

    ssv.certoraSetSSVProtocol(e, 1, cluster.networkFeeIndex, 1, 1, snapshotBlock);
    ssv.certoraSetSSVCluster(e, owner, operatorIds, cluster, 0, snapshotBlock);
    liquidateSSV@withrevert(e, owner, operatorIds, cluster);
    satisfy !lastReverted, "an owner can execute SSV self-liquidation in at least one valid state";
}
