// SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Interest} from "src/libraries/Interest.sol";
import {ICreditLineConfigurable} from "src/interfaces/ICreditLineConfigurable.sol";

/// @title Config contract
/// @notice Contains common configurations used for testing
/// @author CloudWalk Inc. (See https://cloudwalk.io)
contract Config {
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
    address public constant ADDON_RECIPIENT = address(bytes20(keccak256("addon_recipient")));

    address public constant CREDIT_LINE_1 = address(bytes20(keccak256("credit_line_1")));
    address public constant CREDIT_LINE_2 = address(bytes20(keccak256("credit_line_2")));

    address public constant LIQUIDITY_POOL_1 = address(bytes20(keccak256("liquidity_pool_1")));
    address public constant LIQUIDITY_POOL_2 = address(bytes20(keccak256("liquidity_pool_2")));

    address public constant CREDIT_LINE_FACTORY_1 = address(bytes20(keccak256("credit_line_factory_1")));
    address public constant CREDIT_LINE_FACTORY_2 = address(bytes20(keccak256("credit_line_factory_2")));

    address public constant LIQUIDITY_POOL_FACTORY_1 = address(bytes20(keccak256("liquidity_pool_factory_1")));
    address public constant LIQUIDITY_POOL_FACTORY_2 = address(bytes20(keccak256("liquidity_pool_factory_2")));

    address public constant EXPECTED_CONTRACT_ADDRESS = address(bytes20(keccak256("expected_contract_address")));

    uint256 public constant INIT_CREDIT_LINE_MIN_BORROW_AMOUNT = 400;
    uint256 public constant INIT_CREDIT_LINE_MAX_BORROW_AMOUNT = 900;
    uint256 public constant INIT_CREDIT_LINE_PERIOD_IN_SECONDS = 600;
    uint256 public constant INIT_CREDIT_LINE_DURATION_IN_PERIODS = 100;
    uint256 public constant INIT_CREDIT_LINE_ADDON_FIXED_COST_RATE = 15;
    uint256 public constant INIT_CREDIT_LINE_ADDON_PERIOD_COST_RATE = 20;
    uint256 public constant INIT_CREDIT_LINE_MIN_INTEREST_RATE_PRIMARY = 499;
    uint256 public constant INIT_CREDIT_LINE_MAX_INTEREST_RATE_PRIMARY = 501;
    uint256 public constant INIT_CREDIT_LINE_MIN_INTEREST_RATE_SECONDARY = 599;
    uint256 public constant INIT_CREDIT_LINE_MAX_INTEREST_RATE_SECONDARY = 601;
    uint256 public constant INIT_CREDIT_LINE_INTEREST_RATE_FACTOR = 1000;

    uint256 public constant INIT_BORROWER_DURATION = 1000;
    uint256 public constant INIT_BORROWER_MIN_BORROW_AMOUNT = 500;
    uint256 public constant INIT_BORROWER_MAX_BORROW_AMOUNT = 800;
    uint256 public constant INIT_BORROWER_INTEREST_RATE_PRIMARY = 500;
    uint256 public constant INIT_BORROWER_INTEREST_RATE_SECONDARY = 600;
    Interest.Formula public constant INIT_BORROWER_INTEREST_FORMULA = Interest.Formula.Simple;
    Interest.Formula public constant INIT_BORROWER_INTEREST_FORMULA_COMPOUND = Interest.Formula.Compound;
    ICreditLineConfigurable.BorrowPolicy public constant INIT_BORROWER_POLICY =
        ICreditLineConfigurable.BorrowPolicy.Decrease;

    uint256 public constant ZERO_VALUE = 0;

    uint16 public constant KIND_1 = 1;
    uint16 public constant KIND_2 = 2;
    bytes public constant DATA = "0x123ff";

    function initCreditLineConfig() public pure returns (ICreditLineConfigurable.CreditLineConfig memory) {
        return ICreditLineConfigurable.CreditLineConfig({
            periodInSeconds: INIT_CREDIT_LINE_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_CREDIT_LINE_DURATION_IN_PERIODS,
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
            expiration: blockTimestamp + INIT_BORROWER_DURATION,
            minBorrowAmount: INIT_BORROWER_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_BORROWER_MAX_BORROW_AMOUNT,
            interestRatePrimary: INIT_BORROWER_INTEREST_RATE_PRIMARY,
            interestRateSecondary: INIT_BORROWER_INTEREST_RATE_SECONDARY,
            interestFormula: INIT_BORROWER_INTEREST_FORMULA,
            addonRecipient: ADDON_RECIPIENT,
            policy: INIT_BORROWER_POLICY
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
