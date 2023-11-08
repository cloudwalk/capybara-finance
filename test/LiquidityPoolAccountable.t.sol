// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {LiquidityPoolAccountable} from "../src/pools/LiquidityPoolAccountable.sol";
import {CreditLineConfigurable} from "../src/lines/CreditLineConfigurable.sol";
import {ICreditLineConfigurable} from "src/interfaces/ICreditLineConfigurable.sol";
import {Interest} from "src/libraries/Interest.sol";
import {Loan} from "src/libraries/Loan.sol";
import {Error} from "src/libraries/Error.sol";
import {CapybaraNFT} from "../src/CapybaraNFT.sol";
import {LendingRegistry} from "../src/LendingRegistry.sol";
import {LendingMarket} from "../src/LendingMarket.sol";
import {Token} from "./mocks/Token.sol";

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract LiquidityPoolAccountableTest is Test {
    event Deposit(address indexed creditLine, uint256 amount);
    event Withdraw(address indexed tokenSource, uint256 amount);

    address public constant ATTACKER = 0x447a8BAfc4747Aa92583d6a5ddB839DA91ded5A5;
    address public constant ADMIN = 0x97cFe60890C572d2Af20AA160Edabf6E03bf453E;

    string public constant TOKEN_NAME = "CapybaraFinance";
    string public constant TOKEN_SYMBOL = "CAPY";

    uint256 public constant DEPOSIT_AMOUNT = 100;
    uint256 public constant INIT_LOAN_DURATION_IN_PERIODS = 100;
    uint256 public constant INIT_MIN_BORROW_AMOUNT = 50;
    uint256 public constant INIT_MAX_BORROW_AMOUNT = 500;
    uint256 public constant INIT_MIN_BORROWER_BORROW_AMOUNT = 50;
    uint256 public constant INIT_MAX_BORROWER_BORROW_AMOUNT = 400;
    uint256 public constant INIT_PERIOD_IN_SECONDS = 3600;
    uint256 public constant INIT_LOAN_INTEREST = 1;
    uint256 public constant MINT_AMOUNT = 1000000;

    LiquidityPoolAccountable public pool;
    CreditLineConfigurable public line;
    CreditLineConfigurable public secondLine;
    Token public token;
    Token public secondToken;
    LendingMarket public marketLogic;
    LendingMarket public market;
    CapybaraNFT public nftLogic;
    CapybaraNFT public nft;
    LendingRegistry public registryLogic;
    LendingRegistry public registry;

    function setUp() public {
        token = new Token(MINT_AMOUNT);
        secondToken = new Token(MINT_AMOUNT);
        nftLogic = new CapybaraNFT();
        marketLogic = new LendingMarket();
        registryLogic = new LendingRegistry();

        ERC1967Proxy marketProxy = new ERC1967Proxy(address(marketLogic), "");
        ERC1967Proxy nftProxy = new ERC1967Proxy(address(nftLogic), "");
        ERC1967Proxy registryProxy = new ERC1967Proxy(address(registryLogic), "");

        market = LendingMarket(address(marketProxy));

        nft = CapybaraNFT(address(nftProxy));
        nft.initialize(TOKEN_NAME, TOKEN_SYMBOL, address(market));

        market.initialize(address(nft));

        registry = LendingRegistry(address(registryProxy));
        registry.initialize(address(market));

        pool = new LiquidityPoolAccountable(address(market), address(this));
        line = new CreditLineConfigurable(address(market), address(this));
        secondLine = new CreditLineConfigurable(address(market), address(this));
        line.configureToken(address(token));
        secondLine.configureToken(address(token));

        market.setRegistry(address(registry));

        vm.startPrank(address(registry));

        market.registerCreditLine(address(this), address(line));
        market.registerCreditLine(address(ADMIN), address(secondLine));
        market.registerLiquidityPool(address(this), address(pool));
        market.registerLiquidityPool(address(ADMIN), address(this));

        vm.stopPrank();

        token.approve(address(pool), type(uint256).max);
        token.approve(address(market), type(uint256).max);
        secondToken.approve(address(pool), type(uint256).max);
        secondToken.approve(address(market), type(uint256).max);
    }

    function test_constructor() public {
        assertEq(pool.market(), address(market));

        assertEq(pool.lender(), address(this));

        assertEq(pool.owner(), address(this));
    }

    function test_constructor_Revert_IfMarketIsZeroAddress() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        pool = new LiquidityPoolAccountable(address(0), address(this));
    }

    function test_constructor_Revert_IfLenderIsZeroAddress() public {
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0))
        );
        pool = new LiquidityPoolAccountable(address(this), address(0));
    }

    function test_pause() public {
        assertEq(pool.paused(), false);
        pool.pause();
        assertEq(pool.paused(), true);
    }

    function test_pause_Revert_IfCallerNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(ATTACKER))
        );
        vm.prank(ATTACKER);
        pool.pause();
    }

    function test_pause_Revert_IfContractIsPaused() public {
        pool.pause();
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        pool.pause();
    }

    function test_unpause() public {
        assertEq(pool.paused(), false);
        pool.pause();
        assertEq(pool.paused(), true);
        pool.unpause();
        assertEq(pool.paused(), false);
    }

    function test_unpause_Revert_IfCallerNotOwner() public {
        assertEq(pool.paused(), false);
        pool.pause();
        vm.prank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(ATTACKER))
        );
        pool.unpause();
    }

    function test_unpause_RevertIfContractNotPaused() public {
        assertEq(pool.paused(), false);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        pool.unpause();
    }

    function test_deposit() public {
        assertEq(token.allowance(address(pool), address(this)), 0);
        vm.prank(address(pool));
        token.approve(address(this), DEPOSIT_AMOUNT);

        vm.prank(address(pool));
        token.approve(address(market), type(uint256).max);

        vm.expectEmit(true, true, true, true, address(pool));
        emit Deposit(address(this), DEPOSIT_AMOUNT);
        pool.deposit(address(this), DEPOSIT_AMOUNT);

        assertEq(token.allowance(address(pool), address(this)), DEPOSIT_AMOUNT);
        assertEq(token.balanceOf(address(pool)), DEPOSIT_AMOUNT);

        assertEq(pool.getTokenBalance(address(this)), DEPOSIT_AMOUNT);
    }

    function test_deposit_WithZeroPreviousAllowance() public {
        assertEq(token.balanceOf(address(pool)), 0);
        assertEq(token.allowance(address(pool), address(this)), 0);

        pool.deposit(address(this), DEPOSIT_AMOUNT);

        assertEq(token.allowance(address(pool), address(market)), type(uint256).max);
        assertEq(token.balanceOf(address(pool)), DEPOSIT_AMOUNT);
    }

    function test_deposit_Revert_IfCreditLineIsZeroAddress() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        pool.deposit(address(0), DEPOSIT_AMOUNT);
    }

    function test_deposit_Revert_IfDepositAmountZero() public {
        vm.expectRevert(Error.InvalidAmount.selector);
        pool.deposit(address(this), 0);
    }

    function test_deposit_Revert_IfCallerNotOwner() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(ATTACKER))
        );
        pool.deposit(address(this), DEPOSIT_AMOUNT);
    }

    function test_withdraw_CreditLineBalance() public {
        pool.deposit(address(line), DEPOSIT_AMOUNT);
        assertEq(token.balanceOf(address(pool)), DEPOSIT_AMOUNT);
        assertEq(pool.getTokenBalance(address(token)), DEPOSIT_AMOUNT);

        vm.expectEmit(true, true, true, true, address(pool));
        emit Withdraw(address(token), DEPOSIT_AMOUNT);
        pool.withdraw(address(token), DEPOSIT_AMOUNT);
        assertEq(token.balanceOf(address(pool)), 0);

        vm.expectRevert();
        pool.getTokenBalance(address(token));
    }

    function test_withdraw_Rescue() public {
        assertEq(token.balanceOf(address(pool)), 0);
        token.transfer(address(pool), DEPOSIT_AMOUNT);
        assertEq(token.balanceOf(address(pool)), DEPOSIT_AMOUNT);

        uint256 beforeBalance = token.balanceOf(address(this));

        pool.withdraw(address(token), DEPOSIT_AMOUNT);
        assertEq(token.balanceOf(address(this)), beforeBalance + DEPOSIT_AMOUNT);
    }

    function test_withdraw_Revert_IfZeroAddress() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        pool.withdraw(address(0), DEPOSIT_AMOUNT);
    }

    function test_withdraw_Revert_IfZeroAmount() public {
        vm.expectRevert(Error.InvalidAmount.selector);
        pool.withdraw(address(token), 0);
    }

    function test_withdraw_Revert_IfCreditLineOutOfTokenBalance() public {
        pool.deposit(address(line), DEPOSIT_AMOUNT);
        vm.expectRevert(LiquidityPoolAccountable.OutOfTokenBalance.selector);
        pool.withdraw(address(line), DEPOSIT_AMOUNT + 1);
    }

    function test_withdraw_Revert_IfRescueOutOfTokenBalance() public {
        token.transfer(address(pool), DEPOSIT_AMOUNT);
        vm.expectRevert(LiquidityPoolAccountable.OutOfTokenBalance.selector);
        pool.withdraw(address(token), DEPOSIT_AMOUNT + 1);
    }

    function test_withdraw_Revert_IfUnexpectedTokenSource() public {
        vm.expectRevert();
        pool.withdraw(ATTACKER, DEPOSIT_AMOUNT);
    }

    function test_withdraw_IfCallerNotOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(ATTACKER))
        );
        vm.prank(ATTACKER);
        pool.withdraw(address(token), DEPOSIT_AMOUNT);
    }

    function test_onBeforeLoanTaken() public {
        vm.prank(address(market));
        pool.onBeforeLoanTaken(0, address(this));
    }

    function test_onBeforeLoanTaken_Revert_IfCallerNotMarket() public {
        vm.expectRevert(Error.Unauthorized.selector);
        pool.onBeforeLoanTaken(0, address(this));
    }

    function test_onBeforeLoanTaken_Revert_IfContractIsPaused() public {
        pool.pause();
        vm.prank(address(market));
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        pool.onBeforeLoanTaken(0, address(this));
    }

    function test_onAfterLoanTaken() public {
        configureCredit();

        vm.prank(address(market));
        pool.onAfterLoanTaken(DEPOSIT_AMOUNT, address(this));

        assertEq(pool.getTokenBalance(address(line)), 1);
    }

    function test_onAfterLoanTaken_Revert_IfCallerNotMarket() public {
        vm.expectRevert(Error.Unauthorized.selector);
        pool.onAfterLoanTaken(0, address(this));
    }

    function test_onAfterLoanTaken_Revert_IfContractIsPaused() public {
        configureCredit();
        pool.pause();
        vm.prank(address(market));
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        pool.onAfterLoanTaken(0, address(this));
    }

    function test_onBeforeLoanPayment() public {
        vm.prank(address(market));
        pool.onBeforeLoanPayment(0, DEPOSIT_AMOUNT);
    }

    function test_onBeforeLoanPayment_Revert_IfCallerNotMarket() public {
        vm.expectRevert(Error.Unauthorized.selector);
        pool.onBeforeLoanPayment(0, DEPOSIT_AMOUNT);
    }

    function test_onBeforeLoanPayment_Revert_IfContractIsPaused() public {
        pool.pause();
        vm.prank(address(market));
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        pool.onBeforeLoanPayment(0, DEPOSIT_AMOUNT);
    }

    function test_onAfterLoanPayment() public {
        configureCredit();
        vm.prank(address(market));
        pool.onAfterLoanPayment(0, DEPOSIT_AMOUNT);

        assertEq(pool.getTokenBalance(address(line)), DEPOSIT_AMOUNT + 1);
    }

    function test_onAfterLoanPayment_ZeroCreditLineAddress() public {
        vm.prank(address(market));
        pool.onAfterLoanPayment(0, DEPOSIT_AMOUNT);
    }

    function test_onAfterLoanPayment_Revert_IfCallerNotMarket() public {
        vm.expectRevert(Error.Unauthorized.selector);
        pool.onAfterLoanPayment(0, DEPOSIT_AMOUNT);
    }

    function test_onAfterLoanPayment_Revert_IfContractIsPaused() public {
        configureCredit();
        pool.pause();
        vm.prank(address(market));
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        pool.onAfterLoanPayment(0, DEPOSIT_AMOUNT);
    }

    function test_getTokenBalance_CreditLineBalance() public {
        pool.deposit(address(line), DEPOSIT_AMOUNT);
        assertEq(pool.getTokenBalance(address(token)), DEPOSIT_AMOUNT);
    }

    function test_getTokenBalance_Rescue() public {
        token.transfer(address(pool), DEPOSIT_AMOUNT);
        assertEq(pool.getTokenBalance(address(token)), DEPOSIT_AMOUNT);
    }

    function test_getTokenBalance_Revert_IfZeroTokenAddress() public {
        vm.expectRevert(Error.InvalidAddress.selector);
        pool.getTokenBalance(address(0));
    }

    function test_getTokenBalance_Revert_IfUnexpectedTokenSource() public {
        vm.expectRevert(LiquidityPoolAccountable.UnexpectedTokenSource.selector);
        pool.getTokenBalance(address(token));
    }

    function test_getCreditLine() public {
        configureCredit();

        assertEq(pool.getCreditLine(0), address(line));
    }

    function test_market() public {
        assertEq(pool.market(), address(market));
    }

    function test_lender() public {
        assertEq(pool.lender(), address(this));
    }

    function test_kind() public {
        assertEq(pool.kind(), 1);
    }

    function configureCredit() internal {
        ICreditLineConfigurable.CreditLineConfig memory lineConfig = ICreditLineConfigurable.CreditLineConfig({
            minBorrowAmount: INIT_MIN_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROW_AMOUNT,
            periodInSeconds: INIT_PERIOD_IN_SECONDS,
            durationInPeriods: INIT_LOAN_DURATION_IN_PERIODS,
            addonPeriodCostRate: 0,
            addonFixedCostRate: 0
        });

        ICreditLineConfigurable.BorrowerConfig memory config = ICreditLineConfigurable.BorrowerConfig({
            minBorrowAmount: INIT_MIN_BORROWER_BORROW_AMOUNT,
            maxBorrowAmount: INIT_MAX_BORROWER_BORROW_AMOUNT,
            expiration: block.timestamp + 10000000,
            interestRatePrimary: INIT_LOAN_INTEREST,
            interestRateSecondary: INIT_LOAN_INTEREST,
            addonRecipient: address(0),
            interestFormula: Interest.Formula.Simple,
            policy: ICreditLineConfigurable.BorrowPolicy.Decrease
        });

        line.configureAdmin(address(this), true);
        line.configureCreditLine(lineConfig);
        line.configureBorrower(address(this), config);

        pool.deposit(address(line), DEPOSIT_AMOUNT);
        market.takeLoan(address(line), DEPOSIT_AMOUNT - 1);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}
