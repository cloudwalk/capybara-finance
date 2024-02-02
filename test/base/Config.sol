// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Loan} from "src/libraries/Loan.sol";
import {Error} from "src/libraries/Error.sol";
import {SafeCast} from "src/libraries/SafeCast.sol";
import {Interest} from "src/libraries/Interest.sol";
import {ICreditLineConfigurable} from "src/interfaces/ICreditLineConfigurable.sol";

/// @title Config contract
/// @notice Contains common configurations used for testing
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract Config {
    using SafeCast for uint256;

    address public constant ADMIN = address(bytes20(keccak256("admin")));
    address public constant OWNER = address(bytes20(keccak256("owner")));

    address public constant MARKET = address(bytes20(keccak256("market")));

    address public constant TOKEN_1 = address(bytes20(keccak256("token_1")));
    address public constant TOKEN_2 = address(bytes20(keccak256("token_2")));

    address public constant LENDER_1 = address(bytes20(keccak256("lender_1")));
    address public constant LENDER_2 = address(bytes20(keccak256("lender_2")));

    address public constant ATTACKER = address(bytes20(keccak256("attacker")));
    address public constant REGISTRY = address(bytes20(keccak256("registry")));

    address public constant BORROWER_1 = address(bytes20(keccak256("borrower_1")));
    address public constant BORROWER_2 = address(bytes20(keccak256("borrower_2")));
    address public constant BORROWER_3 = address(bytes20(keccak256("borrower_3")));
    address public constant ADDON_RECIPIENT = address(bytes20(keccak256("recipient")));

    address public constant CREDIT_LINE_1 = address(bytes20(keccak256("credit_line_1")));
    address public constant CREDIT_LINE_2 = address(bytes20(keccak256("credit_line_2")));

    address public constant LIQUIDITY_POOL_1 = address(bytes20(keccak256("liquidity_pool_1")));
    address public constant LIQUIDITY_POOL_2 = address(bytes20(keccak256("liquidity_pool_2")));

    address public constant CREDIT_LINE_FACTORY_1 = address(bytes20(keccak256("credit_line_factory_1")));
    address public constant CREDIT_LINE_FACTORY_2 = address(bytes20(keccak256("credit_line_factory_2")));

    address public constant LIQUIDITY_POOL_FACTORY_1 = address(bytes20(keccak256("liquidity_pool_factory_1")));
    address public constant LIQUIDITY_POOL_FACTORY_2 = address(bytes20(keccak256("liquidity_pool_factory_2")));

    address public constant EXPECTED_CONTRACT_ADDRESS = address(bytes20(keccak256("expected_contract_address")));

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
    bool public constant INIT_BORROWER_AUTOREPAYMENT = false;

    Interest.Formula public constant INIT_BORROWER_INTEREST_FORMULA = Interest.Formula.Simple;
    Interest.Formula public constant INIT_BORROWER_INTEREST_FORMULA_COMPOUND = Interest.Formula.Compound;
    ICreditLineConfigurable.BorrowPolicy public constant INIT_BORROWER_POLICY =
        ICreditLineConfigurable.BorrowPolicy.Decrease;

    uint16 public constant KIND_1 = 1;
    uint16 public constant KIND_2 = 2;
    bytes public constant DATA = "0x123ff";

    uint64 public constant BORROW_AMOUNT = 100;
    uint64 public constant ADDON_AMOUNT = 100;
    uint256 public constant ZERO_VALUE = 0;

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
            expiration: (blockTimestamp + INIT_BORROWER_DURATION).toUint32(),
            minBorrowAmount: INIT_BORROWER_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_BORROWER_MAX_BORROW_AMOUNT,
            interestRatePrimary: INIT_BORROWER_INTEREST_RATE_PRIMARY,
            interestRateSecondary: INIT_BORROWER_INTEREST_RATE_SECONDARY,
            interestFormula: INIT_BORROWER_INTEREST_FORMULA_COMPOUND,
            addonRecipient: ADDON_RECIPIENT,
            policy: INIT_BORROWER_POLICY,
            autoRepayment: INIT_BORROWER_AUTOREPAYMENT
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

    function initLoanTerms(address token) internal returns (Loan.Terms memory) {
        ICreditLineConfigurable.CreditLineConfig memory creditLineConfig = initCreditLineConfig();
        ICreditLineConfigurable.BorrowerConfig memory borrowerConfig = initBorrowerConfig(0);
        return Loan.Terms({
            token: token,
            periodInSeconds: creditLineConfig.periodInSeconds,
            durationInPeriods: borrowerConfig.durationInPeriods,
            interestRateFactor: creditLineConfig.interestRateFactor,
            interestRatePrimary: borrowerConfig.interestRatePrimary,
            interestRateSecondary: borrowerConfig.interestRateSecondary,
            interestFormula: borrowerConfig.interestFormula,
            addonRecipient: borrowerConfig.addonRecipient,
            autoRepayment: borrowerConfig.autoRepayment,
            addonAmount: ADDON_AMOUNT
        });
    }
}
