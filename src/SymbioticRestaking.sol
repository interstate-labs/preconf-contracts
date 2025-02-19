pragma solidity 0.8.25;

import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import {IBaseDelegator} from "@symbiotic/interfaces/delegator/IBaseDelegator.sol";
import {Subnetwork} from "@symbiotic/contracts/libraries/Subnetwork.sol";
import {IVault} from "@symbiotic/interfaces/vault/IVault.sol";
import {IRegistry} from "@symbiotic/interfaces/common/IRegistry.sol";
import {IOptInService} from "@symbiotic/interfaces/service/IOptInService.sol";
import {ISlasher} from "@symbiotic/interfaces/slasher/ISlasher.sol";
import {IVetoSlasher} from "@symbiotic/interfaces/slasher/IVetoSlasher.sol";
import {IEntity} from "@symbiotic/interfaces/common/IEntity.sol";

import {IConsensusRestaking} from "./interfaces/IRestaking.sol";
import {IParameters} from "./interfaces/IParameters.sol";
import {MapWithTimeData} from "./library/MapWithTimeData.sol";

contract SymbioticRestaking is
    IConsensusRestaking,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using MapWithTimeData for EnumerableMap.AddressToUintMap;
    using Subnetwork for address;

    uint256 public INSTANT_SLASHER_TYPE = 0;

    uint256 public VETO_SLASHER_TYPE = 1;

    uint48 public START_TIMESTAMP;

    IParameters public parameters;

    IConsensusRestaking public manager;

    EnumerableMap.AddressToUintMap private vaults;

    address public SYMBIOTIC_NETWORK;

    address public OPERATOR_REGISTRY;

    address public VAULT_FACTORY;

    address public OPERATOR_NET_OPTIN;

    bytes32 public NAME_HASH;

    uint256[38] private __gap;



    error NotVault();
    error SlashAmountTooHigh();
    error UnknownSlasherType();
    error OperatorNotOptedIn();

    function initialize(
        address _owner,
        address _parameters,
        address _manager,
        address _symbioticNetwork,
        address _symbioticOperatorRegistry,
        address _symbioticOperatorNetOptIn,
        address _symbioticVaultFactory
    ) public reinitializer(2) {
        __Ownable_init(_owner);
        parameters = IParameters(_parameters);
        manager = IConsensusRestaking(_manager);
        START_TIMESTAMP = Time.timestamp();

        SYMBIOTIC_NETWORK = _symbioticNetwork;
        OPERATOR_REGISTRY = _symbioticOperatorRegistry;
        OPERATOR_NET_OPTIN = _symbioticOperatorNetOptIn;
        VAULT_FACTORY = _symbioticVaultFactory;
        NAME_HASH = keccak256("SYMBIOTIC");
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function getPeriodStartTime(
        uint48 epoch
    ) public view returns (uint48 periodIndex) {
        return START_TIMESTAMP + epoch * parameters.VALIDATOR_EPOCH_TIME();
    }

    function getPeriodAtTime(uint48 periodIndex) public view returns (uint48) {
        return
            (periodIndex - START_TIMESTAMP) / parameters.VALIDATOR_EPOCH_TIME();
    }

    function getCurrentTime() public view returns (uint48 epoch) {
        return getPeriodAtTime(Time.timestamp());
    }

    function getWhitelistedVaults() public view returns (address[] memory) {
        return vaults.keys();
    }

    function registerVault(address vault) public onlyOwner {
        if (vaults.contains(vault)) {
            revert AlreadyRegistered();
        }

        if (!IRegistry(VAULT_FACTORY).isEntity(vault)) {
            revert NotVault();
        }

        vaults.add(vault);
        vaults.enable(vault);
    }

    function deregisterVault(address vault) public onlyOwner {
        if (!vaults.contains(vault)) {
            revert NotRegistered();
        }

        vaults.remove(vault);
    }

    function registerOperator(string calldata rpc) public {
        
        // if (manager.isOperator(msg.sender)) {
        //     revert AlreadyRegistered();
        // }

        if (!IRegistry(OPERATOR_REGISTRY).isEntity(msg.sender)) {
            revert NotOperator();
        }

        if (
            !IOptInService(OPERATOR_NET_OPTIN).isOptedIn(
                msg.sender,
                SYMBIOTIC_NETWORK
            )
        ) {
            revert OperatorNotOptedIn();
        }

        // manager.registerOperator(msg.sender, rpc);
    }

    function deregisterOperator() public {
        // if (!manager.isOperator(msg.sender)) {
        //     revert NotRegistered();
        // }

        // manager.deregisterOperator(msg.sender);
    }

    // function pauseOperator() public {
    //     manager.pauseOperator(msg.sender);
    // }

    // function unpauseOperator() public {
    //     manager.unpauseOperator(msg.sender);
    // }

    function pauseVault() public {
        if (!vaults.contains(msg.sender)) {
            revert NotRegistered();
        }

        vaults.disable(msg.sender);
    }

    function unpauseVault() public {
        if (!vaults.contains(msg.sender)) {
            revert NotRegistered();
        }

        vaults.enable(msg.sender);
    }

    function isVaultEnabled(address vault) public view returns (bool) {
        (uint48 enabledTime, uint48 disabledTime) = vaults.getTimes(vault);
        return enabledTime != 0 && disabledTime == 0;
    }

    function getProviderCollateralTokens(
        address operator
    ) public view returns (address[] memory, uint256[] memory) {
        address[] memory collateralTokens = new address[](vaults.length());
        uint256[] memory amounts = new uint256[](vaults.length());

        uint48 epochStartTs = getPeriodStartTime(
            getPeriodAtTime(Time.timestamp())
        );

        for (uint256 i = 0; i < vaults.length(); ++i) {
            (address vault, uint48 enabledTime, uint48 disabledTime) = vaults
                .atWithTimes(i);

            if (!_wasEnabledAt(enabledTime, disabledTime, epochStartTs)) {
                continue;
            }

            address collateral = IVault(vault).collateral();
            collateralTokens[i] = collateral;

            amounts[i] = IBaseDelegator(IVault(vault).delegator()).stakeAt(
                SYMBIOTIC_NETWORK.subnetwork(0),
                operator,
                epochStartTs,
                new bytes(0)
            );
        }

        return (collateralTokens, amounts);
    }

    function  getProviderCollateral(
        address operator,
        address collateral
    ) public view returns (uint256 amount) {
        uint48 timestamp = Time.timestamp();
        return getOperatorStakeAt(operator, collateral, timestamp);
    }

    function getOperatorStakeAt(
        address operator,
        address collateral,
        uint48 timestamp
    ) public view returns (uint256 amount) {
        if (timestamp > Time.timestamp() || timestamp < START_TIMESTAMP) {
            revert InvalidQuery();
        }

        uint48 epochStartTs = getPeriodStartTime(getPeriodAtTime(timestamp));

        for (uint256 i = 0; i < vaults.length(); ++i) {
            (address vault, uint48 enabledTime, uint48 disabledTime) = vaults
                .atWithTimes(i);

            if (collateral != IVault(vault).collateral()) {
                continue;
            }

            if (!_wasEnabledAt(enabledTime, disabledTime, epochStartTs)) {
                continue;
            }

            amount += IBaseDelegator(IVault(vault).delegator()).stakeAt(
                SYMBIOTIC_NETWORK.subnetwork(0),
                operator,
                epochStartTs,
                new bytes(0)
            );
        }
        return amount;
    }

    function slash(
        uint48 timestamp,
        address operator,
        address collateral,
        uint256 amount
    ) public onlyOwner {
        uint48 epochStartTs = getPeriodStartTime(getPeriodAtTime(timestamp));

        for (uint256 i = 0; i < vaults.length(); ++i) {
            (address vault, uint48 enabledTime, uint48 disabledTime) = vaults
                .atWithTimes(i);

            if (!_wasEnabledAt(enabledTime, disabledTime, epochStartTs)) {
                continue;
            }

            if (collateral != IVault(vault).collateral()) {
                continue;
            }

            uint256 operatorStake = getOperatorStakeAt(
                operator,
                collateral,
                epochStartTs
            );

            if (amount > operatorStake) {
                revert SlashAmountTooHigh();
            }

            uint256 vaultStake = IBaseDelegator(IVault(vault).delegator())
                .stakeAt(
                    SYMBIOTIC_NETWORK.subnetwork(0),
                    operator,
                    epochStartTs,
                    new bytes(0)
                );

            // Slash the vault pro-rata.
            _slashVault(
                epochStartTs,
                vault,
                operator,
                (amount * vaultStake) / operatorStake
            );
        }
    }

    function _wasEnabledAt(
        uint48 enabledTime,
        uint48 disabledTime,
        uint48 timestamp
    ) private pure returns (bool) {
        return
            enabledTime != 0 &&
            enabledTime <= timestamp &&
            (disabledTime == 0 || disabledTime >= timestamp);
    }

    function _slashVault(
        uint48 timestamp,
        address vault,
        address operator,
        uint256 amount
    ) private {
        address slasher = IVault(vault).slasher();
        uint256 slasherType = IEntity(slasher).TYPE();

        if (slasherType == INSTANT_SLASHER_TYPE) {
            ISlasher(slasher).slash(
                SYMBIOTIC_NETWORK.subnetwork(0),
                operator,
                amount,
                timestamp,
                new bytes(0)
            );
        } else if (slasherType == VETO_SLASHER_TYPE) {
            IVetoSlasher(slasher).requestSlash(
                SYMBIOTIC_NETWORK.subnetwork(0),
                operator,
                amount,
                timestamp,
                new bytes(0)
            );
        } else {
            revert UnknownSlasherType();
        }
    }
}
