// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Test} from "forge-std/Test.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {Loan} from "src/libraries/Loan.sol";
import {Error} from "src/libraries/Error.sol";
import {SafeCast} from "src/libraries/SafeCast.sol";
import {Interest} from "src/libraries/Interest.sol";
import {ICreditLineConfigurable} from "src/interfaces/ICreditLineConfigurable.sol";
import {CreditLineConfigurable} from "src/lines/CreditLineConfigurable.sol";

/// @title CreditLineConfigurableTest contract
/// @notice Contains tests for the CreditLineConfigurable contract
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract Config is Test{

    address public constant BORROWER_1 = address(bytes20(keccak256("borrower_1")));
    address public constant BORROWER_2 = address(bytes20(keccak256("borrower_2")));
    address public constant BORROWER_3 = address(bytes20(keccak256("borrower_3")));
    address public constant ADDON_RECIPIENT = address(bytes20(keccak256("addon_recipient")));

    uint64 public constant INIT_CREDIT_LINE_MIN_BORROW_AMOUNT = 400;
    uint64 public constant INIT_CREDIT_LINE_MAX_BORROW_AMOUNT = 900;
    uint32 public constant INIT_CREDIT_LINE_ADDON_FIXED_COST_RATE = 15;
    uint32 public constant INIT_CREDIT_LINE_ADDON_PERIOD_COST_RATE = 20;
    uint32 public constant INIT_CREDIT_LINE_MIN_INTEREST_RATE_PRIMARY = 3;
    uint32 public constant INIT_CREDIT_LINE_MAX_INTEREST_RATE_PRIMARY = 7;
    uint32 public constant INIT_CREDIT_LINE_MIN_INTEREST_RATE_SECONDARY = 4;
    uint32 public constant INIT_CREDIT_LINE_MAX_INTEREST_RATE_SECONDARY = 8;
    uint32 public constant INIT_CREDIT_LINE_INTEREST_RATE_FACTOR = 1000;
    uint32 public constant INIT_CREDIT_LINE_PERIOD_IN_SECONDS = 600;
    uint32 public constant INIT_CREDIT_LINE_MIN_DURATION_IN_PERIODS = 50;
    uint32 public constant INIT_CREDIT_LINE_MAX_DURATION_IN_PERIODS = 200;

    uint32 public constant INIT_BORROWER_DURATION_IN_PERIODS = 100;
    uint32 public constant INIT_BORROWER_DURATION = 1000;
    uint64 public constant INIT_BORROWER_MIN_BORROW_AMOUNT = 500;
    uint64 public constant INIT_BORROWER_MAX_BORROW_AMOUNT = 800;
    uint32 public constant INIT_BORROWER_INTEREST_RATE_PRIMARY = 5;
    uint32 public constant INIT_BORROWER_INTEREST_RATE_SECONDARY = 6;
    bool public constant INIT_BORROWER_AUTOREPAYMENT_FALSE = false;
    bool public constant INIT_BORROWER_AUTOREPAYMENT_TRUE = true;
    Interest.Formula public constant INIT_BORROWER_INTEREST_FORMULA = Interest.Formula.Simple;
    Interest.Formula public constant INIT_BORROWER_INTEREST_FORMULA_COMPOUND = Interest.Formula.Compound;
    ICreditLineConfigurable.BorrowPolicy public constant INIT_BORROWER_POLICY =
        ICreditLineConfigurable.BorrowPolicy.Decrease;

    uint16 public constant KIND = 1;

    function initCreditLineConfig() public pure returns (ICreditLineConfigurable.CreditLineConfig memory) {
        return ICreditLineConfigurable.CreditLineConfig({
            periodInSeconds: INIT_CREDIT_LINE_PERIOD_IN_SECONDS,
            minDurationInPeriods: INIT_CREDIT_LINE_MIN_DURATION_IN_PERIODS,
            maxDurationInPeriods: INIT_CREDIT_LINE_MAX_DURATION_IN_PERIODS,
            minBorrowAmount: INIT_CREDIT_LINE_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_CREDIT_LINE_MAX_BORROW_AMOUNT,
            interestRateFactor: INIT_CREDIT_LINE_INTEREST_RATE_FACTOR,
            minInterestRatePrimary: INIT_CREDIT_LINE_MIN_INTEREST_RATE_PRIMARY,
            maxInterestRatePrimary: INIT_CREDIT_LINE_MAX_INTEREST_RATE_PRIMARY,
            minInterestRateSecondary: INIT_CREDIT_LINE_MIN_INTEREST_RATE_SECONDARY,
            maxInterestRateSecondary: INIT_CREDIT_LINE_MAX_INTEREST_RATE_SECONDARY,
            addonPeriodCostRate: INIT_CREDIT_LINE_ADDON_PERIOD_COST_RATE,
            addonFixedCostRate: INIT_CREDIT_LINE_ADDON_FIXED_COST_RATE
        });
    }

    function initBorrowerConfig(uint256 blockTimestamp)
        public
        pure
        returns (ICreditLineConfigurable.BorrowerConfig memory)
    {
        return ICreditLineConfigurable.BorrowerConfig({
            durationInPeriods: INIT_BORROWER_DURATION_IN_PERIODS,
            expiration: SafeCast.toUint32(blockTimestamp + INIT_BORROWER_DURATION),
            minBorrowAmount: INIT_BORROWER_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_BORROWER_MAX_BORROW_AMOUNT,
            interestRatePrimary: INIT_BORROWER_INTEREST_RATE_PRIMARY,
            interestRateSecondary: INIT_BORROWER_INTEREST_RATE_SECONDARY,
            interestFormula: INIT_BORROWER_INTEREST_FORMULA,
            addonRecipient: ADDON_RECIPIENT,
            policy: INIT_BORROWER_POLICY,
            autoRepayment: INIT_BORROWER_AUTOREPAYMENT_FALSE
        });
    }

    function initBorrowerConfigs(uint256 blockTimestamp)
        public
        pure
        returns (address[] memory, ICreditLineConfigurable.BorrowerConfig[] memory)
    {
        address[] memory borrowers = new address[](3);
        borrowers[0] = BORROWER_1;
        borrowers[1] = BORROWER_2;
        borrowers[2] = BORROWER_3;

        ICreditLineConfigurable.BorrowerConfig[] memory configs = new ICreditLineConfigurable.BorrowerConfig[](3);
        configs[0] = initBorrowerConfig(blockTimestamp);
        configs[1] = initBorrowerConfig(blockTimestamp);
        configs[2] = initBorrowerConfig(blockTimestamp);

        return (borrowers, configs);
    }
}
