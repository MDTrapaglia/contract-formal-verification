// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.24;

import {SSVClusters} from "../../contracts/modules/SSVClusters.sol";
import {SSVViews} from "../../contracts/modules/SSVViews.sol";
import {ISSVNetworkCore} from "../../contracts/interfaces/ISSVNetworkCore.sol";
import {ClusterLib} from "../../contracts/libraries/ClusterLib.sol";
import {ProtocolLib} from "../../contracts/libraries/ProtocolLib.sol";
import {SSVStorage, StorageData} from "../../contracts/libraries/storage/SSVStorage.sol";
import {SSVStorageProtocol, StorageProtocol} from "../../contracts/libraries/storage/SSVStorageProtocol.sol";
import {SSVStorageEB, StorageEB} from "../../contracts/libraries/storage/SSVStorageEB.sol";
import {SSVStorageReentrancy} from "../../contracts/libraries/storage/SSVStorageReentrancy.sol";
import {
    PackedSSV,
    PackedETH,
    PACKED_SSV_ZERO,
    PACKED_ETH_ZERO,
    BPS_DENOMINATOR
} from "../../contracts/libraries/SSVCoreTypes.sol";
import {PackedETHLib} from "../../contracts/libraries/SSVPackedLib.sol";

contract SSVClustersCertoraHarness is SSVClusters, SSVViews {
    using ClusterLib for ISSVNetworkCore.Cluster;
    using ProtocolLib for StorageProtocol;

    constructor() SSVViews(address(0)) {}

    function certoraHashCluster(address owner, uint64[] calldata operatorIds) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(owner, operatorIds));
    }

    function certoraHashClusterData(ISSVNetworkCore.Cluster memory cluster) external pure returns (bytes32) {
        return cluster.hashClusterData();
    }

    function certoraSetETHCluster(
        address owner,
        uint64[] calldata operatorIds,
        ISSVNetworkCore.Cluster memory cluster
    ) external returns (bytes32 clusterId) {
        StorageData storage s = SSVStorage.load();
        StorageProtocol storage sp = SSVStorageProtocol.load();
        StorageEB storage seb = SSVStorageEB.load();

        clusterId = keccak256(abi.encodePacked(owner, operatorIds));
        s.ethClusters[clusterId] = cluster.hashClusterData();
        seb.clusterEB[clusterId].vUnits = 0;

        sp.ethDaoValidatorCount = cluster.active ? cluster.validatorCount : 0;
        sp.daoTotalEthVUnits = cluster.active ? uint64(cluster.validatorCount) * BPS_DENOMINATOR : 0;

        for (uint256 i; i < operatorIds.length; ++i) {
            uint64 operatorId = operatorIds[i];
            ISSVNetworkCore.Operator storage operator = s.operators[operatorId];
            operator.owner = owner;
            operator.ethFee = PACKED_ETH_ZERO;
            operator.ethSnapshot.block = uint32(block.number);
            operator.ethSnapshot.index = i == 0 ? cluster.index : 0;
            operator.ethSnapshot.balance = PACKED_ETH_ZERO;
            operator.ethValidatorCount = cluster.active ? cluster.validatorCount : 0;
            seb.operatorEthVUnits[operatorId] = 0;
        }
    }

    function certoraSetETHClusterWithAccrual(
        address owner,
        uint64[] calldata operatorIds,
        ISSVNetworkCore.Cluster memory cluster,
        uint64 operatorFee,
        uint32 snapshotBlock
    ) external returns (bytes32 clusterId) {
        StorageData storage s = SSVStorage.load();
        StorageProtocol storage sp = SSVStorageProtocol.load();
        StorageEB storage seb = SSVStorageEB.load();

        clusterId = keccak256(abi.encodePacked(owner, operatorIds));
        s.ethClusters[clusterId] = cluster.hashClusterData();
        seb.clusterEB[clusterId].vUnits = 0;
        sp.ethDaoValidatorCount = cluster.active ? cluster.validatorCount : 0;
        sp.daoTotalEthVUnits = cluster.active ? uint64(cluster.validatorCount) * BPS_DENOMINATOR : 0;

        for (uint256 i; i < operatorIds.length; ++i) {
            uint64 operatorId = operatorIds[i];
            ISSVNetworkCore.Operator storage operator = s.operators[operatorId];
            operator.owner = owner;
            operator.ethFee = PackedETH.wrap(operatorFee);
            operator.ethSnapshot.block = snapshotBlock;
            operator.ethSnapshot.index = i == 0 ? cluster.index : 0;
            operator.ethSnapshot.balance = PACKED_ETH_ZERO;
            operator.ethValidatorCount = cluster.active ? cluster.validatorCount : 0;
            seb.operatorEthVUnits[operatorId] = 0;
        }
    }

    function certoraSetSSVCluster(
        address owner,
        uint64[] calldata operatorIds,
        ISSVNetworkCore.Cluster memory cluster,
        uint64 operatorFee,
        uint32 snapshotBlock
    ) external returns (bytes32 clusterId) {
        StorageData storage s = SSVStorage.load();
        StorageProtocol storage sp = SSVStorageProtocol.load();

        clusterId = keccak256(abi.encodePacked(owner, operatorIds));
        s.clusters[clusterId] = cluster.hashClusterData();

        sp.daoValidatorCount = cluster.active ? cluster.validatorCount : 0;

        for (uint256 i; i < operatorIds.length; ++i) {
            uint64 operatorId = operatorIds[i];
            ISSVNetworkCore.Operator storage operator = s.operators[operatorId];
            operator.owner = owner;
            operator.fee = PackedSSV.wrap(operatorFee);
            operator.snapshot.block = snapshotBlock;
            operator.snapshot.index = i == 0 ? cluster.index : 0;
            operator.snapshot.balance = PACKED_SSV_ZERO;
            operator.validatorCount = cluster.active ? cluster.validatorCount : 0;
        }
    }

    function certoraSetETHProtocol(
        uint64 ethNetworkFee,
        uint64 initialNetworkFeeIndex,
        uint64 minimumBlocksBeforeLiquidation,
        uint64 minimumLiquidationCollateral
    ) external {
        StorageProtocol storage sp = SSVStorageProtocol.load();
        sp.ethNetworkFee = PackedETH.wrap(ethNetworkFee);
        sp.ethNetworkFeeIndex = initialNetworkFeeIndex;
        sp.ethNetworkFeeIndexBlockNumber = uint32(block.number);
        sp.ethDaoBalance = PACKED_ETH_ZERO;
        sp.ethDaoIndexBlockNumber = uint32(block.number);
        sp.minimumBlocksBeforeLiquidation = minimumBlocksBeforeLiquidation;
        sp.minimumLiquidationCollateral = PackedETH.wrap(minimumLiquidationCollateral);
        SSVStorageReentrancy.load().status = 1;
    }

    function certoraSetETHProtocolWithAccrual(
        uint64 ethNetworkFee,
        uint64 initialNetworkFeeIndex,
        uint64 minimumBlocksBeforeLiquidation,
        uint64 minimumLiquidationCollateral,
        uint32 accrualStartBlock
    ) external {
        StorageProtocol storage sp = SSVStorageProtocol.load();
        sp.ethNetworkFee = PackedETH.wrap(ethNetworkFee);
        sp.ethNetworkFeeIndex = initialNetworkFeeIndex;
        sp.ethNetworkFeeIndexBlockNumber = accrualStartBlock;
        sp.ethDaoBalance = PACKED_ETH_ZERO;
        sp.ethDaoIndexBlockNumber = accrualStartBlock;
        sp.minimumBlocksBeforeLiquidation = minimumBlocksBeforeLiquidation;
        sp.minimumLiquidationCollateral = PackedETH.wrap(minimumLiquidationCollateral);
        SSVStorageReentrancy.load().status = 1;
    }

    function certoraSetSSVProtocol(
        uint64 networkFee,
        uint64 initialNetworkFeeIndex,
        uint64 minimumBlocksBeforeLiquidation,
        uint64 minimumLiquidationCollateral,
        uint32 accrualStartBlock
    ) external {
        StorageProtocol storage sp = SSVStorageProtocol.load();
        sp.networkFee = PackedSSV.wrap(networkFee);
        sp.networkFeeIndex = initialNetworkFeeIndex;
        sp.networkFeeIndexBlockNumber = accrualStartBlock;
        sp.daoBalance = PACKED_SSV_ZERO;
        sp.daoIndexBlockNumber = accrualStartBlock;
        sp.minimumBlocksBeforeLiquidationSSV = minimumBlocksBeforeLiquidation;
        sp.minimumLiquidationCollateralSSV = PackedSSV.wrap(minimumLiquidationCollateral);
        SSVStorageReentrancy.load().status = 1;
    }

    function certoraSetOperatorETHFee(uint64 operatorId, uint64 packedFee) external {
        StorageData storage s = SSVStorage.load();
        ISSVNetworkCore.Operator storage operator = s.operators[operatorId];
        operator.ethFee = PackedETH.wrap(packedFee);
        if (operator.ethSnapshot.block == 0) {
            operator.ethSnapshot.block = uint32(block.number);
        }
    }

    function certoraSetClusterVUnits(
        bytes32 clusterId,
        uint64[] calldata operatorIds,
        uint32 validatorCount,
        uint64 vUnits
    ) external {
        StorageEB storage seb = SSVStorageEB.load();
        seb.clusterEB[clusterId].vUnits = vUnits;

        uint64 baseline = uint64(validatorCount) * BPS_DENOMINATOR;
        uint64 deviation = vUnits - baseline;
        SSVStorageProtocol.load().daoTotalEthVUnits = vUnits;
        for (uint256 i; i < operatorIds.length; ++i) {
            seb.operatorEthVUnits[operatorIds[i]] = deviation;
        }
    }

    function certoraIsETHClusterLiquidatable(
        ISSVNetworkCore.Cluster memory cluster,
        bytes32 clusterId,
        uint64 burnRate
    ) external view returns (bool) {
        StorageProtocol storage sp = SSVStorageProtocol.load();
        return cluster.isLiquidatableWithEB(
            clusterId,
            burnRate,
            PackedETH.unwrap(sp.ethNetworkFee),
            sp.minimumBlocksBeforeLiquidation,
            sp.minimumLiquidationCollateral
        );
    }

    function certoraIsCurrentETHClusterLiquidatable(
        ISSVNetworkCore.Cluster memory cluster,
        bytes32 clusterId,
        uint64[] calldata operatorIds
    ) external view returns (bool) {
        StorageData storage s = SSVStorage.load();
        StorageProtocol storage sp = SSVStorageProtocol.load();
        uint64 clusterIndex;
        uint64 burnRate;

        for (uint256 i; i < operatorIds.length; ++i) {
            ISSVNetworkCore.Operator storage operator = s.operators[operatorIds[i]];
            if (operator.ethSnapshot.block == 0) continue;
            clusterIndex += operator.ethSnapshot.index +
                (uint64(block.number) - operator.ethSnapshot.block) * PackedETH.unwrap(operator.ethFee);
            burnRate += PackedETH.unwrap(operator.ethFee);
        }

        cluster.updateClusterData(clusterId, clusterIndex, sp.currentNetworkFeeIndex());
        return cluster.isLiquidatableWithEB(
            clusterId,
            burnRate,
            PackedETH.unwrap(sp.ethNetworkFee),
            sp.minimumBlocksBeforeLiquidation,
            sp.minimumLiquidationCollateral
        );
    }

    function certoraETHBurnRate(uint64[] calldata operatorIds) external view returns (uint64 burnRate) {
        StorageData storage s = SSVStorage.load();
        for (uint256 i; i < operatorIds.length; ++i) {
            ISSVNetworkCore.Operator storage operator = s.operators[operatorIds[i]];
            if (operator.ethSnapshot.block == 0) {
                continue;
            }
            burnRate += PackedETH.unwrap(operator.ethFee);
        }
    }

    function certoraStoredETHClusterHash(bytes32 clusterId) external view returns (bytes32) {
        return SSVStorage.load().ethClusters[clusterId];
    }

    function certoraExpectedLiquidatedETHClusterHash(
        ISSVNetworkCore.Cluster memory cluster
    ) external pure returns (bytes32) {
        cluster.balance = 0;
        cluster.index = 0;
        cluster.networkFeeIndex = 0;
        cluster.active = false;
        return cluster.hashClusterData();
    }

    function certoraETHDaoValidatorCount() external view returns (uint32) {
        return SSVStorageProtocol.load().ethDaoValidatorCount;
    }

    function certoraDAOTotalETHVUnits() external view returns (uint64) {
        return SSVStorageProtocol.load().daoTotalEthVUnits;
    }

    function certoraOperatorETHValidatorCount(uint64 operatorId) external view returns (uint32) {
        return SSVStorage.load().operators[operatorId].ethValidatorCount;
    }

    function certoraOperatorETHVUnits(uint64 operatorId) external view returns (uint64) {
        return SSVStorageEB.load().operatorEthVUnits[operatorId];
    }

    function certoraWouldETHWithdrawLeaveLiquidatable(
        ISSVNetworkCore.Cluster memory cluster,
        bytes32 clusterId,
        uint64 burnRate,
        uint256 amount
    ) external view returns (bool) {
        if (amount > cluster.balance) {
            return true;
        }

        cluster.balance -= amount;
        StorageProtocol storage sp = SSVStorageProtocol.load();
        return
            cluster.isLiquidatableWithEB(
                clusterId,
                burnRate,
                PackedETH.unwrap(sp.ethNetworkFee),
                sp.minimumBlocksBeforeLiquidation,
                sp.minimumLiquidationCollateral
            );
    }

    function certoraCurrentETHWithdrawIsLiquidatable(
        ISSVNetworkCore.Cluster memory cluster,
        bytes32 clusterId,
        uint64[] calldata operatorIds,
        uint256 amount
    ) external view returns (bool) {
        StorageData storage s = SSVStorage.load();
        StorageProtocol storage sp = SSVStorageProtocol.load();
        uint64 clusterIndex;
        uint64 burnRate;

        for (uint256 i; i < operatorIds.length; ++i) {
            ISSVNetworkCore.Operator storage operator = s.operators[operatorIds[i]];
            clusterIndex +=
                operator.ethSnapshot.index +
                (uint64(block.number) - operator.ethSnapshot.block) *
                PackedETH.unwrap(operator.ethFee);
            burnRate += PackedETH.unwrap(operator.ethFee);
        }

        cluster.updateClusterData(clusterId, clusterIndex, sp.currentNetworkFeeIndex());
        if (cluster.balance < amount) {
            return true;
        }
        cluster.balance -= amount;

        return cluster.isLiquidatableWithEB(
            clusterId,
            burnRate,
            PackedETH.unwrap(sp.ethNetworkFee),
            sp.minimumBlocksBeforeLiquidation,
            sp.minimumLiquidationCollateral
        );
    }

    function certoraCurrentETHWithdrawHash(
        ISSVNetworkCore.Cluster memory cluster,
        bytes32 clusterId,
        uint64[] calldata operatorIds,
        uint256 amount
    ) external view returns (bytes32) {
        StorageData storage s = SSVStorage.load();
        StorageProtocol storage sp = SSVStorageProtocol.load();
        uint64 clusterIndex;

        for (uint256 i; i < operatorIds.length; ++i) {
            ISSVNetworkCore.Operator storage operator = s.operators[operatorIds[i]];
            clusterIndex +=
                operator.ethSnapshot.index +
                (uint64(block.number) - operator.ethSnapshot.block) *
                PackedETH.unwrap(operator.ethFee);
        }

        cluster.updateClusterData(clusterId, clusterIndex, sp.currentNetworkFeeIndex());
        if (cluster.balance < amount) {
            return bytes32(0);
        }
        cluster.balance -= amount;
        return cluster.hashClusterData();
    }

    function certoraExpectedETHWithdrawHash(
        ISSVNetworkCore.Cluster memory cluster,
        uint256 amount
    ) external pure returns (bytes32) {
        if (amount > cluster.balance) {
            return bytes32(0);
        }
        cluster.balance -= amount;
        return cluster.hashClusterData();
    }

    function certoraIsSSVClusterLiquidatable(
        ISSVNetworkCore.Cluster memory cluster,
        uint64 burnRate
    ) external view returns (bool) {
        StorageProtocol storage sp = SSVStorageProtocol.load();
        return
            cluster.isLiquidatable(
                burnRate,
                PackedSSV.unwrap(sp.networkFee),
                sp.minimumBlocksBeforeLiquidationSSV,
                sp.minimumLiquidationCollateralSSV
            );
    }

    function certoraIsCurrentSSVClusterLiquidatable(
        ISSVNetworkCore.Cluster memory cluster,
        uint64[] calldata operatorIds
    ) external view returns (bool) {
        StorageData storage s = SSVStorage.load();
        StorageProtocol storage sp = SSVStorageProtocol.load();
        uint64 clusterIndex;
        uint64 burnRate;

        for (uint256 i; i < operatorIds.length; ++i) {
            ISSVNetworkCore.Operator storage operator = s.operators[operatorIds[i]];
            if (operator.snapshot.block == 0) {
                clusterIndex += operator.snapshot.index;
                continue;
            }

            uint64 fee = PackedSSV.unwrap(operator.fee);
            clusterIndex += operator.snapshot.index + (uint32(block.number) - operator.snapshot.block) * fee;
            burnRate += fee;
        }

        cluster.updateBalanceSSV(clusterIndex, sp.currentNetworkFeeIndexSSV());
        return
            cluster.isLiquidatable(
                burnRate,
                PackedSSV.unwrap(sp.networkFee),
                sp.minimumBlocksBeforeLiquidationSSV,
                sp.minimumLiquidationCollateralSSV
            );
    }

    function certoraSSVBurnRate(uint64[] calldata operatorIds) external view returns (uint64 burnRate) {
        StorageData storage s = SSVStorage.load();
        for (uint256 i; i < operatorIds.length; ++i) {
            ISSVNetworkCore.Operator storage operator = s.operators[operatorIds[i]];
            if (operator.snapshot.block == 0) {
                continue;
            }
            burnRate += PackedSSV.unwrap(operator.fee);
        }
    }

    function certoraStoredSSVClusterHash(bytes32 clusterId) external view returns (bytes32) {
        return SSVStorage.load().clusters[clusterId];
    }

    function certoraBaselineVUnits(uint32 validatorCount) external pure returns (uint64) {
        return uint64(validatorCount) * BPS_DENOMINATOR;
    }
}
