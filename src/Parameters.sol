// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;


import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";


contract Parameters is OwnableUpgradeable, UUPSUpgradeable {




    uint256 internal constant BEACON_TIME_WINDOW = 8191;
    uint48 public VALIDATOR_EPOCH_TIME;


    uint48 public PENALTY_WINDOW_DURATION;


    bool public SKIP_SIGNATURE_VALIDATION;
    

    uint48 public CHALLENGE_TIMEOUT_PERIOD;

    uint256 public DISPUTE_SECURITY_DEPOSIT;


    uint256 public CHAIN_HISTORY_LIMIT;


    uint256 public FINALIZATION_DELAY_SLOTS;


    uint256 public CONSENSUS_LAUNCH_TIMESTAMP;


    uint256 public CONSENSUS_SLOT_DURATION;


    uint256 public OPERATOR_COLLATERAL_MINIMUM;
    
 
    uint256[43] private __gap;

  
    function initialize(
        address adminAddress,
        uint48 epochTimeInput,
        uint48 penaltyWindowInput,
        uint48 challengeTimeoutInput,
        bool skipSignatureFlag,
        uint256 securityDepositAmount,
        uint256 historyLimitValue,
        uint256 delaySlotsPeriod,
        uint256 launchTimestampValue,
        uint256 slotDurationValue,
        uint256 minimumCollateralAmount
    ) public initializer {
        __Ownable_init(adminAddress);

        VALIDATOR_EPOCH_TIME = epochTimeInput;
        PENALTY_WINDOW_DURATION = penaltyWindowInput;
        SKIP_SIGNATURE_VALIDATION = skipSignatureFlag;
        CHALLENGE_TIMEOUT_PERIOD = challengeTimeoutInput;
        DISPUTE_SECURITY_DEPOSIT = securityDepositAmount;
        CHAIN_HISTORY_LIMIT = historyLimitValue;
        FINALIZATION_DELAY_SLOTS = delaySlotsPeriod;
        CONSENSUS_LAUNCH_TIMESTAMP = launchTimestampValue;
        CONSENSUS_SLOT_DURATION = slotDurationValue;
        OPERATOR_COLLATERAL_MINIMUM = minimumCollateralAmount;
    }

    function _authorizeUpgrade(
        address implementationContract
    ) internal override onlyOwner {}


    function setSkipSignatureValidation(
        bool signatureValidationFlag
    ) public onlyOwner {
        SKIP_SIGNATURE_VALIDATION = signatureValidationFlag;
    }


    function setChallengeTimeoutPeriod(
        uint48 timeoutPeriod
    ) public onlyOwner {
        CHALLENGE_TIMEOUT_PERIOD = timeoutPeriod;
    }


    function setDisputeSecurityDeposit(
        uint256 securityAmount
    ) public onlyOwner {
        DISPUTE_SECURITY_DEPOSIT = securityAmount;
    }


    function setOperatorCollateralMinimum(
        uint256 collateralAmount
    ) public onlyOwner {
        OPERATOR_COLLATERAL_MINIMUM = collateralAmount;
    }


    function setFinalizationDelaySlots(
        uint256 delaySlots
    ) public onlyOwner {
        FINALIZATION_DELAY_SLOTS = delaySlots;
    }
}