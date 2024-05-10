import { ethers, network, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import {
  getAddress,
  getLatestBlockTimestamp,
  getTxTimestamp,
  increaseBlockTimestampTo,
  proveTx
} from "../../test-utils/eth";

async function setUpFixture<T>(func: () => Promise<T>): Promise<T> {
  if (network.name === "hardhat") {
    return loadFixture(func);
  } else {
    return func();
  }
}

interface LoanTerms {
  token: string;
  interestRatePrimary: number;
  interestRateSecondary: number;
  interestRateFactor: number;
  treasury: string;
  periodInSeconds: number;
  durationInPeriods: number;
  interestFormula: InterestFormula;
  autoRepayment: boolean;
  addonRecipient: string;
  addonAmount: number;
}

interface LoanState {
  token: string;
  interestRateFactor: number;
  interestRatePrimary: number;
  interestRateSecondary: number;
  borrower: string;
  initialBorrowAmount: number;
  startTimestamp: number;
  treasury: string;
  periodInSeconds: number;
  durationInPeriods: number;
  interestFormula: InterestFormula;
  autoRepayment: boolean;
  trackedBorrowBalance: number;
  trackedTimestamp: number;
  freezeTimestamp: number;

  [key: string]: string | number | InterestFormula | boolean; // Index signature
}

interface LoanPreview {
  periodIndex: number;
  outstandingBalance: number;

  [key: string]: number; // Index signature
}

enum InterestFormula {
  Simple = 0,
  Compound = 1
}

enum PayerKind {
  Borrower = 0,
  LiquidityPool = 1,
  Stranger = 2
}

const ERROR_NAME_ALREADY_CONFIGURED = "AlreadyConfigured";
const ERROR_NAME_ALREADY_INITIALIZED = "InvalidInitialization";
const ERROR_NAME_AUTO_REPAYMENT_NOT_ALLOWED = "AutoRepaymentNotAllowed";
const ERROR_NAME_CREDIT_LINE_ALREADY_REGISTERED = "CreditLineAlreadyRegistered";
const ERROR_NAME_CREDIT_LINE_NOT_REGISTERED = "CreditLineNotRegistered";
const ERROR_NAME_ENFORCED_PAUSED = "EnforcedPause";
const ERROR_NAME_LIQUIDITY_POOL_ALREADY_REGISTERED = "LiquidityPoolAlreadyRegistered";
const ERROR_NAME_LIQUIDITY_POOL_NOT_REGISTERED = "LiquidityPoolNotRegistered";
const ERROR_NAME_LOAN_ALREADY_FROZEN = "LoanAlreadyFrozen";
const ERROR_NAME_LOAN_ALREADY_REPAID = "LoanAlreadyRepaid";
const ERROR_NAME_LOAN_NOT_EXIST = "LoanNotExist";
const ERROR_NAME_LOAN_NOT_FROZEN = "LoanNotFrozen";
const ERROR_NAME_INAPPROPRIATE_DURATION_IN_PERIODS = "InappropriateLoanDuration";
const ERROR_NAME_INAPPROPRIATE_INTEREST_RATE = "InappropriateInterestRate";
const ERROR_NAME_INTEREST_FORMULA_NOT_IMPLEMENTED = "InterestFormulaNotImplemented";
const ERROR_NAME_INVALID_AMOUNT = "InvalidAmount";
const ERROR_NAME_NOT_IMPLEMENTED = "NotImplemented";
const ERROR_NAME_NOT_PAUSED = "ExpectedPause";
const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";
const ERROR_NAME_UNAUTHORIZED = "Unauthorized";
const ERROR_NAME_ZERO_ADDRESS = "ZeroAddress";

const EVENT_NAME_CREDIT_LINE_LENDER_UPDATED = "CreditLineLenderUpdated";
const EVENT_NAME_CREDIT_LINE_REGISTERED = "CreditLineRegistered";
const EVENT_NAME_LENDER_ALIAS_CONFIGURED = "LenderAliasConfigured";
const EVENT_NAME_LIQUIDITY_POOL_ASSIGNED_TO_CREDIT_LINE = "LiquidityPoolAssignedToCreditLine";
const EVENT_NAME_LIQUIDITY_POOL_LENDER_UPDATED = "LiquidityPoolLenderUpdated";
const EVENT_NAME_LIQUIDITY_POOL_REGISTERED = "LiquidityPoolRegistered";
const EVENT_NAME_LOAN_INTEREST_RATE_PRIMARY_UPDATED = "LoanInterestRatePrimaryUpdated";
const EVENT_NAME_LOAN_INTEREST_RATE_SECONDARY_UPDATED = "LoanInterestRateSecondaryUpdated";
const EVENT_NAME_LOAN_DURATION_UPDATED = "LoanDurationUpdated";
const EVENT_NAME_LOAN_FROZEN = "LoanFrozen";
const EVENT_NAME_LOAN_REPAYMENT = "LoanRepayment";
const EVENT_NAME_LOAN_TAKEN = "LoanTaken";
const EVENT_NAME_TRANSFER = "Transfer";
const EVENT_NAME_LOAN_UNFROZEN = "LoanUnfrozen";
const EVENT_NAME_MARKET_REGISTRY_CHANGED = "MarketRegistryChanged";
const EVENT_NAME_ON_AFTER_LOAN_TAKEN = "OnAfterLoanTakenCalled";
const EVENT_NAME_ON_BEFORE_LOAN_TAKEN = "OnBeforeLoanTakenCalled";
const EVENT_NAME_ON_AFTER_LOAN_PAYMENT = "OnAfterLoanPaymentCalled";
const EVENT_NAME_ON_BEFORE_LOAN_PAYMENT = "OnBeforeLoanPaymentCalled";
const EVENT_NAME_PAUSED = "Paused";
const EVENT_NAME_UNPAUSED = "Unpaused";

const TOKEN_NAME = "TEST";
const TOKEN_SYMBOL = "TST";
const ZERO_ADDRESS = ethers.ZeroAddress;
const BORROW_AMOUNT = 100;
const REPAY_AMOUNT = 50;
const FULL_REPAY_AMOUNT = ethers.MaxUint256;
const MINT_AMOUNT = 1000_000;
const BORROWER_SUPPLY_AMOUNT = 10_000;
const DEPOSIT_AMOUNT = 1000;
const DEFAULT_INTEREST_RATE_PRIMARY = 10;
const DEFAULT_INTEREST_RATE_SECONDARY = 20;
const DEFAULT_INTEREST_RATE_FACTOR = 100;
const DEFAULT_PERIOD_IN_SECONDS = 60;
const DEFAULT_DURATION_IN_PERIODS = 10;
const DEFAULT_ADDON_AMOUNT = 10;
const DEFAULT_LOAN_ID = 0;
const NON_EXISTENT_LOAN_ID = ethers.MaxUint256;
const TIME_OFFSET = 0;
const ALIAS_STATUS_CONFIGURED = true;
const ALIAS_STATUS_NOT_CONFIGURED = false;

describe("Contract 'LendingMarket'", async () => {
  let lendingMarketFactory: ContractFactory;
  let creditLineFactory: ContractFactory;
  let liquidityPoolFactory: ContractFactory;
  let tokenFactory: ContractFactory;

  let creditLine: Contract;
  let liquidityPool: Contract;
  let token: Contract;

  let owner: HardhatEthersSigner;
  let registry: HardhatEthersSigner;
  let lender: HardhatEthersSigner;
  let borrower: HardhatEthersSigner;
  let addonRecipient: HardhatEthersSigner;
  let alias: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;
  let stranger: HardhatEthersSigner;

  let creditLineAddress: string;
  let liquidityPoolAddress: string;
  let tokenAddress: string;

  before(async () => {
    [owner, registry, lender, borrower, addonRecipient, alias, attacker, stranger] = await ethers.getSigners();

    // Factories with an explicitly specified deployer account
    lendingMarketFactory = await ethers.getContractFactory("LendingMarket");
    lendingMarketFactory = lendingMarketFactory.connect(owner);
    creditLineFactory = await ethers.getContractFactory("CreditLineMock");
    creditLineFactory = creditLineFactory.connect(owner);
    liquidityPoolFactory = await ethers.getContractFactory("LiquidityPoolMock");
    liquidityPoolFactory = liquidityPoolFactory.connect(owner);
    tokenFactory = await ethers.getContractFactory("ERC20Mock");
    tokenFactory = tokenFactory.connect(owner);

    creditLine = await creditLineFactory.deploy() as Contract;
    await creditLine.waitForDeployment();
    creditLine = creditLine.connect(owner) as Contract; // Explicitly specifying the initial account
    creditLineAddress = getAddress(creditLine);

    liquidityPool = await liquidityPoolFactory.deploy() as Contract;
    await liquidityPool.waitForDeployment();
    liquidityPool = liquidityPool.connect(owner) as Contract; // Explicitly specifying the initial account
    liquidityPoolAddress = getAddress(liquidityPool);

    token = await tokenFactory.deploy() as Contract;
    await token.waitForDeployment();
    token = token.connect(owner) as Contract; // Explicitly specifying the initial account
    tokenAddress = getAddress(token);

    // Start tests at the beginning of a loan period to avoid rare failures due to crossing a border between two periods
    const periodIndex = calculatePeriodIndex(await getLatestBlockTimestamp());
    const nextPeriodTimestamp = ((periodIndex + 1) * DEFAULT_PERIOD_IN_SECONDS) - TIME_OFFSET + 1;
    await increaseBlockTimestampTo(nextPeriodTimestamp);
  });

  function createMockTerms(): LoanTerms {
    return {
      token: tokenAddress,
      interestRatePrimary: DEFAULT_INTEREST_RATE_PRIMARY,
      interestRateSecondary: DEFAULT_INTEREST_RATE_SECONDARY,
      interestRateFactor: DEFAULT_INTEREST_RATE_FACTOR,
      treasury: liquidityPoolAddress,
      periodInSeconds: DEFAULT_PERIOD_IN_SECONDS,
      durationInPeriods: DEFAULT_DURATION_IN_PERIODS,
      interestFormula: InterestFormula.Compound,
      autoRepayment: true,
      addonRecipient: addonRecipient.address,
      addonAmount: DEFAULT_ADDON_AMOUNT
    };
  }

  function createInitialLoanState(timestamp: number): LoanState {
    return {
      token: tokenAddress,
      interestRateFactor: DEFAULT_INTEREST_RATE_FACTOR,
      interestRatePrimary: DEFAULT_INTEREST_RATE_PRIMARY,
      interestRateSecondary: DEFAULT_INTEREST_RATE_SECONDARY,
      borrower: borrower.address,
      initialBorrowAmount: BORROW_AMOUNT + DEFAULT_ADDON_AMOUNT,
      startTimestamp: timestamp,
      treasury: liquidityPoolAddress,
      periodInSeconds: DEFAULT_PERIOD_IN_SECONDS,
      durationInPeriods: DEFAULT_DURATION_IN_PERIODS,
      interestFormula: InterestFormula.Compound,
      autoRepayment: true,
      trackedBorrowBalance: BORROW_AMOUNT + DEFAULT_ADDON_AMOUNT,
      trackedTimestamp: timestamp,
      freezeTimestamp: 0
    };
  }

  function compareLoanStates(actualState: LoanState, expectedState: LoanState) {
    Object.keys(expectedState).forEach(property => {
      expect(actualState[property]).to.eq(
        expectedState[property],
        `Mismatch in the "${property}" property of the loan state`
      );
    });
  }

  function compareLoanPreview(actualState: LoanPreview, expectedState: LoanPreview) {
    Object.keys(expectedState).forEach(property => {
      expect(actualState[property]).to.eq(
        expectedState[property],
        `Mismatch in the "${property}" property of the loan preview`
      );
    });
  }

  function calculateOutstandingBalance(
    originalBalance: number,
    numberOfPeriods: number,
    interestRate: number,
    interestRateFactor: number
  ): number {
    const outstandingBalance = originalBalance * Math.pow(1 + interestRate / interestRateFactor, numberOfPeriods);
    return Math.round(outstandingBalance);
  }

  function calculatePeriodIndex(timestamp: number): number {
    return Math.floor((timestamp + TIME_OFFSET) / DEFAULT_PERIOD_IN_SECONDS);
  }

  function defineLoanPreview(loanState: LoanState, timestamp: number): LoanPreview {
    let outstandingBalance = loanState.trackedBorrowBalance;
    if (loanState.freezeTimestamp != 0) {
      timestamp = loanState.freezeTimestamp;
    }
    const periodIndex = calculatePeriodIndex(timestamp);
    const trackedPeriodIndex = calculatePeriodIndex(loanState.trackedTimestamp);
    const startPeriodIndex = calculatePeriodIndex(loanState.startTimestamp);
    const duePeriodIndex = startPeriodIndex + loanState.durationInPeriods;
    const numberOfPeriods = periodIndex - trackedPeriodIndex;
    const numberOfPeriodsWithSecondaryRate = periodIndex - duePeriodIndex;
    const numberOfPeriodsWithPrimaryRate = numberOfPeriodsWithSecondaryRate > 0
      ? numberOfPeriods - numberOfPeriodsWithSecondaryRate
      : numberOfPeriods;

    if (numberOfPeriodsWithPrimaryRate > 0) {
      outstandingBalance = calculateOutstandingBalance(
        outstandingBalance,
        numberOfPeriodsWithPrimaryRate,
        loanState.interestRatePrimary,
        loanState.interestRateFactor
      );
    }
    if (numberOfPeriodsWithSecondaryRate > 0) {
      outstandingBalance = calculateOutstandingBalance(
        outstandingBalance,
        numberOfPeriodsWithSecondaryRate,
        loanState.interestRateSecondary,
        loanState.interestRateFactor
      );
    }
    return {
      periodIndex,
      outstandingBalance
    };
  }

  async function deployLendingMarket(): Promise<{ market: Contract }> {
    let market = await upgrades.deployProxy(lendingMarketFactory, [
      TOKEN_NAME,
      TOKEN_SYMBOL
    ]);

    market = market.connect(owner) as Contract; // Explicitly specifying the initial account

    return {
      market
    };
  }

  async function deployLendingMarketAndConfigureItForLoan(): Promise<{ market: Contract }> {
    const { market } = await deployLendingMarket();

    // register and configure a credit line & liquidity pool
    await proveTx(market.registerCreditLine(lender.address, creditLineAddress));
    await proveTx(market.registerLiquidityPool(lender.address, liquidityPoolAddress));
    await proveTx(
      (market.connect(lender) as Contract).assignLiquidityPoolToCreditLine(creditLineAddress, liquidityPoolAddress)
    );

    // mock configurations
    await proveTx(creditLine.mockTokenAddress(tokenAddress));
    await proveTx(creditLine.mockLoanTerms(borrower.address, BORROW_AMOUNT, createMockTerms()));

    // supply tokens
    await proveTx(token.mint(lender.address, MINT_AMOUNT));
    await proveTx(token.mint(stranger.address, MINT_AMOUNT));
    await proveTx((token.connect(lender) as Contract).transfer(liquidityPoolAddress, DEPOSIT_AMOUNT));
    await proveTx(liquidityPool.approveMarket(getAddress(market), tokenAddress));
    await proveTx((token.connect(borrower) as Contract).approve(getAddress(market), ethers.MaxUint256));
    await proveTx((token.connect(stranger) as Contract).approve(getAddress(market), ethers.MaxUint256));

    return {
      market
    };
  }

  async function deployLendingMarketAndTakeLoan(): Promise<{
    market: Contract;
    marketConnectedToLender: Contract;
    initialLoanState: LoanState;
  }> {
    const { market } = await deployLendingMarketAndConfigureItForLoan();
    const marketConnectedToLender = market.connect(lender) as Contract;

    await proveTx(token.mint(borrower.address, BORROWER_SUPPLY_AMOUNT));
    const tx =
      (market.connect(borrower) as Contract).takeLoan(creditLineAddress, BORROW_AMOUNT, DEFAULT_DURATION_IN_PERIODS);
    const timestmap = await getTxTimestamp(tx);
    const initialLoanState = createInitialLoanState(timestmap);

    return {
      market,
      marketConnectedToLender,
      initialLoanState
    };
  }

  describe("Function initialize()", async () => {
    it("Configures the contract as expected", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      expect(await market.name()).to.eq(TOKEN_NAME);
      expect(await market.symbol()).to.eq(TOKEN_SYMBOL);
      expect(await market.registry()).to.eq(ZERO_ADDRESS);
      expect(await market.owner()).to.eq(owner.address);
      expect(await market.paused()).to.eq(false);

      // Check the period calculation logic of the contract
      const someTimestamp = 123456789;
      expect(
        await market.calculatePeriodIndex(someTimestamp, DEFAULT_PERIOD_IN_SECONDS)
      ).to.eq(calculatePeriodIndex(someTimestamp));
    });

    it("Is reverted if called a second time", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.initialize(TOKEN_NAME, TOKEN_SYMBOL))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ALREADY_INITIALIZED);
    });
  });

  describe("Function 'pause()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.pause())
        .to.emit(market, EVENT_NAME_PAUSED)
        .withArgs(owner.address);
      expect(await market.paused()).to.eq(true);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect((market.connect(attacker) as Contract).pause())
        .to.be.revertedWithCustomError(market, ERROR_NAME_OWNABLE_UNAUTHORIZED)
        .withArgs(attacker.address);
    });

    it("Is reverted if the contract is already paused", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await proveTx(market.pause());
      await expect(market.pause())
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });
  });

  describe("Function 'unpause()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await proveTx(market.pause());
      expect(await market.paused()).to.eq(true);

      await expect(market.unpause())
        .to.emit(market, EVENT_NAME_UNPAUSED)
        .withArgs(owner.address);

      expect(await market.paused()).to.eq(false);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect((market.connect(attacker) as Contract).unpause())
        .to.be.revertedWithCustomError(market, ERROR_NAME_OWNABLE_UNAUTHORIZED)
        .withArgs(attacker.address);
    });

    it("Is reverted if the contract is not paused yet", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.unpause())
        .to.be.revertedWithCustomError(market, ERROR_NAME_NOT_PAUSED);
    });
  });

  describe("Function 'setRegistry()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.setRegistry(registry.address))
        .to.emit(market, EVENT_NAME_MARKET_REGISTRY_CHANGED)
        .withArgs(registry.address, ZERO_ADDRESS);

      expect(await market.registry()).to.eq(registry.address);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect((market.connect(attacker) as Contract).setRegistry(registry.address))
        .to.be.revertedWithCustomError(market, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });

    it("Is reverted if the registry is already configured", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.setRegistry(registry.address));

      await expect(market.setRegistry(registry.address))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ALREADY_CONFIGURED);
    });
  });

  describe("Function 'registerCreditLine()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.registerCreditLine(lender.address, creditLineAddress))
        .to.emit(market, EVENT_NAME_CREDIT_LINE_REGISTERED)
        .withArgs(lender.address, creditLineAddress);

      expect(await market.getCreditLineLender(creditLineAddress)).to.eq(lender.address);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(
        (market.connect(attacker) as Contract).registerCreditLine(lender.address, creditLineAddress)
      ).to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is reverted if the contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.pause());

      await expect(market.registerCreditLine(lender.address, creditLineAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if the credit line address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.registerCreditLine(lender.address, ZERO_ADDRESS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if the lender address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.registerCreditLine(ZERO_ADDRESS, creditLineAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if the credit line is already registered", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      // Any registered account as the lender must prohibit registration of the same credit line
      await proveTx(market.registerCreditLine(stranger.address, creditLineAddress));

      await expect(market.registerCreditLine(lender.address, creditLineAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_CREDIT_LINE_ALREADY_REGISTERED);
    });
  });

  describe("Function 'registerLiquidityPool()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.registerLiquidityPool(lender.address, liquidityPoolAddress))
        .to.emit(market, EVENT_NAME_LIQUIDITY_POOL_REGISTERED)
        .withArgs(lender.address, liquidityPoolAddress);

      expect(await market.getLiquidityPoolLender(liquidityPoolAddress)).to.eq(lender.address);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(
        (market.connect(attacker) as Contract).registerLiquidityPool(lender.address, liquidityPoolAddress)
      ).to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is reverted if the contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.pause());

      await expect(market.registerLiquidityPool(lender.address, liquidityPoolAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if the liquidity pool address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.registerLiquidityPool(lender.address, ZERO_ADDRESS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if the lender address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.registerLiquidityPool(ZERO_ADDRESS, liquidityPoolAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if the liquidity pool is already registered", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      // Any registered account as the lender must prohibit registration of the same liquidity pool
      await proveTx(market.registerLiquidityPool(stranger.address, liquidityPoolAddress));

      await expect(market.registerLiquidityPool(lender.address, liquidityPoolAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LIQUIDITY_POOL_ALREADY_REGISTERED);
    });
  });

  describe("Function 'updateCreditLineLender()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.updateCreditLineLender(creditLineAddress, lender.address))
        .to.emit(market, EVENT_NAME_CREDIT_LINE_LENDER_UPDATED)
        .withArgs(creditLineAddress, lender.address, ZERO_ADDRESS);

      expect(await market.getCreditLineLender(creditLineAddress)).to.eq(lender.address);

      // Check updating when the initial lender is the non-zero address
      await expect(market.updateCreditLineLender(creditLineAddress, stranger.address))
        .to.emit(market, EVENT_NAME_CREDIT_LINE_LENDER_UPDATED)
        .withArgs(creditLineAddress, stranger.address, lender.address);

      expect(await market.getCreditLineLender(creditLineAddress)).to.eq(stranger.address);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(
        (market.connect(attacker) as Contract).updateCreditLineLender(creditLineAddress, lender.address)
      ).to.be.revertedWithCustomError(market, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });

    it("Is reverted if the credit line address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.updateCreditLineLender(ZERO_ADDRESS, lender.address))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if the lender address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.updateCreditLineLender(creditLineAddress, ZERO_ADDRESS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if the credit line lender is already configured", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.updateCreditLineLender(creditLineAddress, lender.address));

      await expect(market.updateCreditLineLender(creditLineAddress, lender.address))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ALREADY_CONFIGURED);
    });
  });

  describe("Function 'updateLiquidityPoolLender()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.updateLiquidityPoolLender(liquidityPoolAddress, lender.address))
        .to.emit(market, EVENT_NAME_LIQUIDITY_POOL_LENDER_UPDATED)
        .withArgs(liquidityPool, lender.address, ZERO_ADDRESS);

      expect(await market.getLiquidityPoolLender(liquidityPoolAddress)).to.eq(lender.address);

      // Check updating when the initial lender is the non-zero address
      await expect(market.updateLiquidityPoolLender(liquidityPoolAddress, stranger.address))
        .to.emit(market, EVENT_NAME_LIQUIDITY_POOL_LENDER_UPDATED)
        .withArgs(liquidityPool, stranger.address, lender.address);

      expect(await market.getLiquidityPoolLender(liquidityPoolAddress)).to.eq(stranger.address);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(
        (market.connect(attacker) as Contract).updateLiquidityPoolLender(liquidityPoolAddress, lender.address)
      ).to.be.revertedWithCustomError(market, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });

    it("Is reverted if the liquidity pool address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.updateLiquidityPoolLender(ZERO_ADDRESS, lender.address))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if the lender address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.updateLiquidityPoolLender(liquidityPoolAddress, ZERO_ADDRESS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if the credit line lender is already configured", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.updateLiquidityPoolLender(liquidityPoolAddress, lender.address));

      await expect(market.updateLiquidityPoolLender(liquidityPoolAddress, lender.address))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ALREADY_CONFIGURED);
    });
  });

  describe("Function 'assignLiquidityPoolToCreditLine()'", async () => {
    it("Executes as expected and emits the correct events", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.registerCreditLine(lender.address, creditLineAddress));
      await proveTx(market.registerLiquidityPool(lender.address, liquidityPoolAddress));

      await expect(
        (market.connect(lender) as Contract).assignLiquidityPoolToCreditLine(creditLineAddress, liquidityPoolAddress)
      ).to.emit(
        market,
        EVENT_NAME_LIQUIDITY_POOL_ASSIGNED_TO_CREDIT_LINE
      ).withArgs(creditLineAddress, liquidityPoolAddress, ZERO_ADDRESS);

      expect(await market.getLiquidityPoolByCreditLine(creditLineAddress)).to.eq(liquidityPoolAddress);
    });

    it("Is reverted if the contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.pause());

      await expect(market.assignLiquidityPoolToCreditLine(creditLineAddress, liquidityPoolAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if the credit line address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.assignLiquidityPoolToCreditLine(ZERO_ADDRESS, liquidityPoolAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if the liquidity pool address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.assignLiquidityPoolToCreditLine(creditLineAddress, ZERO_ADDRESS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if the credit line is already assigned to the liquidity pool", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.registerCreditLine(lender.address, creditLineAddress));
      await proveTx(market.registerLiquidityPool(lender.address, liquidityPoolAddress));

      const marketConnectedToLender = market.connect(lender) as Contract;

      await proveTx(marketConnectedToLender.assignLiquidityPoolToCreditLine(creditLineAddress, liquidityPoolAddress));

      await expect(marketConnectedToLender.assignLiquidityPoolToCreditLine(creditLineAddress, liquidityPoolAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_NOT_IMPLEMENTED);
    });

    it("Is reverted if the caller is not credit line`s lender", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.registerLiquidityPool(lender.address, liquidityPoolAddress));

      // The credit line lender address is zero
      await expect(
        (market.connect(lender) as Contract).assignLiquidityPoolToCreditLine(creditLineAddress, liquidityPoolAddress)
      ).to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);

      // The credit line lender address is non-zero
      await proveTx(market.registerCreditLine(stranger.address, creditLineAddress));
      await expect(
        (market.connect(lender) as Contract).assignLiquidityPoolToCreditLine(creditLineAddress, liquidityPoolAddress)
      ).to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is reverted if the caller is not liquidity pool`s lender", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.registerCreditLine(lender.address, creditLineAddress));

      // The  liquidity pool lender address is zero
      await expect(
        (market.connect(lender) as Contract).assignLiquidityPoolToCreditLine(creditLineAddress, liquidityPoolAddress)
      ).to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);

      // The  liquidity pool lender address is non-zero
      await proveTx(market.registerLiquidityPool(stranger.address, liquidityPoolAddress));
      await expect(
        (market.connect(lender) as Contract).assignLiquidityPoolToCreditLine(creditLineAddress, liquidityPoolAddress)
      ).to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });
  });

  describe("Function 'takeLoan()'", async () => {
    it("Executes as expected and emits the correct events", async () => {
      const { market } = await loadFixture(deployLendingMarketAndConfigureItForLoan);

      const TOTAL_BORROW_AMOUNT = BORROW_AMOUNT + DEFAULT_ADDON_AMOUNT;

      // Check the returned value of the function for the first loan
      const expectedLoanId: bigint = await (market.connect(borrower) as Contract).takeLoan.staticCall(
        creditLineAddress,
        BORROW_AMOUNT,
        DEFAULT_DURATION_IN_PERIODS
      );
      expect(expectedLoanId).to.eq(DEFAULT_LOAN_ID);

      const tx =
        (market.connect(borrower) as Contract).takeLoan(creditLineAddress, BORROW_AMOUNT, DEFAULT_DURATION_IN_PERIODS);
      const timestamp: number = await getTxTimestamp(tx);
      const expectedLoan: LoanState = createInitialLoanState(timestamp);
      const submittedLoan: LoanState = await market.getLoanState(DEFAULT_LOAN_ID);

      compareLoanStates(submittedLoan, expectedLoan);

      await expect(tx).to.changeTokenBalances(
        token,
        [liquidityPool, borrower, addonRecipient],
        [-TOTAL_BORROW_AMOUNT, +BORROW_AMOUNT, +DEFAULT_ADDON_AMOUNT]
      );

      await expect(tx)
        .to.emit(market, EVENT_NAME_LOAN_TAKEN)
        .withArgs(DEFAULT_LOAN_ID, borrower.address, TOTAL_BORROW_AMOUNT, DEFAULT_DURATION_IN_PERIODS);

      // Check that the appropriate market hook functions are called
      await expect(tx)
        .to.emit(liquidityPool, EVENT_NAME_ON_BEFORE_LOAN_TAKEN)
        .withArgs(DEFAULT_LOAN_ID, creditLineAddress);
      await expect(tx)
        .to.emit(liquidityPool, EVENT_NAME_ON_AFTER_LOAN_TAKEN)
        .withArgs(DEFAULT_LOAN_ID, creditLineAddress);

      // Check the NFT minting
      await expect(tx)
        .to.emit(market, EVENT_NAME_TRANSFER)
        .withArgs(ZERO_ADDRESS, lender.address, DEFAULT_LOAN_ID);

      // Check the returned value of the function for the second loan
      const nextExpectedLoanId: bigint = await (market.connect(borrower) as Contract).takeLoan.staticCall(
        creditLineAddress,
        BORROW_AMOUNT,
        DEFAULT_DURATION_IN_PERIODS
      );
      expect(nextExpectedLoanId).to.eq(DEFAULT_LOAN_ID + 1);
    });

    it("Is reverted if the contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarketAndConfigureItForLoan);
      await proveTx(market.pause());

      await expect(
        (market.connect(borrower) as Contract).takeLoan(creditLineAddress, BORROW_AMOUNT, DEFAULT_DURATION_IN_PERIODS)
      ).to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if the credit line address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarketAndConfigureItForLoan);

      await expect(market.takeLoan(ZERO_ADDRESS, BORROW_AMOUNT, DEFAULT_DURATION_IN_PERIODS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if the borrow amount is zero", async () => {
      const { market } = await loadFixture(deployLendingMarketAndConfigureItForLoan);

      await expect(market.takeLoan(creditLineAddress, 0, DEFAULT_DURATION_IN_PERIODS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_INVALID_AMOUNT);
    });

    it("Is reverted if the credit line is not registered", async () => {
      const { market } = await loadFixture(deployLendingMarketAndConfigureItForLoan);

      const unregisteredCreditLineAddress = stranger.address;
      await expect(market.takeLoan(unregisteredCreditLineAddress, BORROW_AMOUNT, DEFAULT_DURATION_IN_PERIODS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_CREDIT_LINE_NOT_REGISTERED);
    });

    it("Is reverted if the liquidity pool is not registered", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.registerCreditLine(lender.address, creditLineAddress));

      await expect(market.takeLoan(creditLineAddress, BORROW_AMOUNT, DEFAULT_DURATION_IN_PERIODS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LIQUIDITY_POOL_NOT_REGISTERED);
    });
  });

  describe("Function 'repayLoan()'", async () => {
    async function repayLoanAndCheck(
      market: Contract,
      repayAmount: number | bigint,
      payerKind: PayerKind,
      initialLoanState: LoanState
    ) {
      const expectedLoanState: LoanState = { ...initialLoanState };

      let tx;
      let payer: HardhatEthersSigner;
      switch (payerKind) {
        case PayerKind.Borrower:
          tx = (market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, repayAmount);
          payer = borrower;
          break;
        case PayerKind.LiquidityPool:
          tx = liquidityPool.autoRepay(getAddress(market), DEFAULT_LOAN_ID, repayAmount);
          payer = borrower;
          break;
        default:
          tx = (market.connect(stranger) as Contract).repayLoan(DEFAULT_LOAN_ID, repayAmount);
          payer = stranger;
      }
      const repaymentTimestamp = await getTxTimestamp(tx);
      const loanPreviewBeforeRepayment = defineLoanPreview(expectedLoanState, repaymentTimestamp);
      if (repayAmount === FULL_REPAY_AMOUNT) {
        repayAmount = loanPreviewBeforeRepayment.outstandingBalance;
        expectedLoanState.trackedBorrowBalance = 0;
      } else {
        repayAmount = Number(repayAmount);
        expectedLoanState.trackedBorrowBalance = loanPreviewBeforeRepayment.outstandingBalance - repayAmount;
      }
      expectedLoanState.trackedTimestamp = repaymentTimestamp;
      const actualLoanStateAfterRepayment = await market.getLoanState(DEFAULT_LOAN_ID);
      compareLoanStates(actualLoanStateAfterRepayment, expectedLoanState);

      await expect(tx).to.changeTokenBalances(
        token,
        [liquidityPool, payer],
        [+repayAmount, -repayAmount]
      );

      await expect(tx)
        .to.emit(market, EVENT_NAME_LOAN_REPAYMENT)
        .withArgs(
          DEFAULT_LOAN_ID,
          payer.address,
          borrower.address,
          repayAmount,
          expectedLoanState.trackedBorrowBalance // outstanding balance
        );

      // Check that the appropriate market hook functions are called
      await expect(tx)
        .to.emit(liquidityPool, EVENT_NAME_ON_BEFORE_LOAN_PAYMENT)
        .withArgs(DEFAULT_LOAN_ID, repayAmount);
      await expect(tx)
        .to.emit(liquidityPool, EVENT_NAME_ON_AFTER_LOAN_PAYMENT)
        .withArgs(DEFAULT_LOAN_ID, repayAmount);

      // Check an appropriate NFT transfer if any
      if (expectedLoanState.trackedBorrowBalance == 0) {
        await expect(tx)
          .to.emit(market, EVENT_NAME_TRANSFER)
          .withArgs(lender.address, borrower.address, DEFAULT_LOAN_ID);
      } else {
        await expect(tx).not.to.emit(market, EVENT_NAME_TRANSFER);
      }
    }

    describe("Executes as expected if", async () => {
      it("There is a partial repayment from the borrower on the same period the loan is taken", async () => {
        const { market, initialLoanState } = await loadFixture(deployLendingMarketAndTakeLoan);
        await repayLoanAndCheck(market, REPAY_AMOUNT, PayerKind.Borrower, initialLoanState);
      });

      it("There is the full partial repayment from the borrower on the same period the loan is taken", async () => {
        const { market, initialLoanState } = await loadFixture(deployLendingMarketAndTakeLoan);
        await repayLoanAndCheck(market, FULL_REPAY_AMOUNT, PayerKind.Borrower, initialLoanState);
      });

      it("There is a partial repayment from a stranger before the loan is defaulted", async () => {
        const { market, initialLoanState } = await setUpFixture(deployLendingMarketAndTakeLoan);
        const timestamp = await getLatestBlockTimestamp();
        const futureTimestamp = timestamp + DEFAULT_DURATION_IN_PERIODS / 2 * DEFAULT_PERIOD_IN_SECONDS;
        await increaseBlockTimestampTo(futureTimestamp);
        await repayLoanAndCheck(market, REPAY_AMOUNT, PayerKind.Stranger, initialLoanState);
      });

      it("There is the full repayment from a stranger after the loan is defaulted", async () => {
        const { market, initialLoanState } = await setUpFixture(deployLendingMarketAndTakeLoan);
        const timestamp = await getLatestBlockTimestamp();
        const futureTimestamp = timestamp + (DEFAULT_DURATION_IN_PERIODS + 1) * DEFAULT_PERIOD_IN_SECONDS;
        await increaseBlockTimestampTo(futureTimestamp);
        await repayLoanAndCheck(market, FULL_REPAY_AMOUNT, PayerKind.Stranger, initialLoanState);
      });

      it("There is a full auto repayment from the liquidity pool after the loan is defaulted", async () => {
        const { market, initialLoanState } = await setUpFixture(deployLendingMarketAndTakeLoan);
        const timestamp = await getLatestBlockTimestamp();
        const futureTimestamp = timestamp + (DEFAULT_DURATION_IN_PERIODS + 1) * DEFAULT_PERIOD_IN_SECONDS;
        await increaseBlockTimestampTo(futureTimestamp);
        await repayLoanAndCheck(market, FULL_REPAY_AMOUNT, PayerKind.LiquidityPool, initialLoanState);
      });
    });

    describe("Is reverted if", async () => {
      it("The contract is paused", async () => {
        const { market } = await loadFixture(deployLendingMarketAndTakeLoan);
        await proveTx(market.pause());

        await expect(market.repayLoan(DEFAULT_LOAN_ID, REPAY_AMOUNT))
          .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
      });

      it("The loan does not exist", async () => {
        const { market } = await loadFixture(deployLendingMarket);

        await expect(market.repayLoan(DEFAULT_LOAN_ID, REPAY_AMOUNT))
          .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_NOT_EXIST);
      });

      it("The loan is already repaid", async () => {
        const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

        await proveTx((market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, FULL_REPAY_AMOUNT));

        await expect(market.repayLoan(DEFAULT_LOAN_ID, REPAY_AMOUNT))
          .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_ALREADY_REPAID);
      });

      it("The repayment amount is zero", async () => {
        const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

        await expect(market.repayLoan(DEFAULT_LOAN_ID, 0))
          .to.be.revertedWithCustomError(market, ERROR_NAME_INVALID_AMOUNT);
      });

      it("The repayment amount is greater than the outstanding balance", async () => {
        const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

        await expect(market.repayLoan(DEFAULT_LOAN_ID, BORROWER_SUPPLY_AMOUNT))
          .to.be.revertedWithCustomError(market, ERROR_NAME_INVALID_AMOUNT);
      });

      it("The repayment is called by a liquidity pool and the auto repayment is not allowed", async () => {
        const { market } = await loadFixture(deployLendingMarketAndConfigureItForLoan);
        const terms: LoanTerms = createMockTerms();
        terms.autoRepayment = false;

        await proveTx(creditLine.mockLoanTerms(borrower.address, BORROW_AMOUNT, terms));

        await proveTx(
          (market.connect(borrower) as Contract).takeLoan(creditLineAddress, BORROW_AMOUNT, DEFAULT_DURATION_IN_PERIODS)
        );

        await expect(liquidityPool.autoRepay(getAddress(market), DEFAULT_LOAN_ID, FULL_REPAY_AMOUNT))
          .to.be.revertedWithCustomError(market, ERROR_NAME_AUTO_REPAYMENT_NOT_ALLOWED);
      });
    });
  });

  describe("Function 'freeze()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { market, marketConnectedToLender, initialLoanState } = await loadFixture(deployLendingMarketAndTakeLoan);
      const expectedLoanState = { ...initialLoanState };

      const tx = marketConnectedToLender.freeze(DEFAULT_LOAN_ID);
      expectedLoanState.freezeTimestamp = await getTxTimestamp(tx);
      const actualLoanStateAfterFreezing: LoanState = await market.getLoanState(DEFAULT_LOAN_ID);

      await expect(tx)
        .to.emit(market, EVENT_NAME_LOAN_FROZEN)
        .withArgs(DEFAULT_LOAN_ID);

      compareLoanStates(actualLoanStateAfterFreezing, expectedLoanState);
    });

    it("Is reverted if the contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx(market.pause());

      await expect(market.freeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if the loan does not exist", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(market.freeze(NON_EXISTENT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_NOT_EXIST);
    });

    it("Is reverted if the loan is already repaid", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx((market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, FULL_REPAY_AMOUNT));

      await expect(market.freeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_ALREADY_REPAID);
    });

    it("Is reverted if the caller is not the lender or an alias", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect((market.connect(attacker) as Contract).freeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is reverted if the loan is already frozen", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx(marketConnectedToLender.freeze(DEFAULT_LOAN_ID));

      await expect(marketConnectedToLender.freeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_ALREADY_FROZEN);
    });
  });

  describe("Function 'unfreeze()'", async () => {
    async function unfreezeAndCheck(
      marketConnectedToLender: Contract,
      initialLoanState: LoanState,
      frozenInterval: number
    ) {
      const freezingTx = marketConnectedToLender.freeze(DEFAULT_LOAN_ID);
      const freezingTimestamp = await getTxTimestamp(freezingTx);

      if (frozenInterval > 0) {
        await increaseBlockTimestampTo(await getLatestBlockTimestamp() + frozenInterval);
      }

      const unfreezingTx = marketConnectedToLender.unfreeze(DEFAULT_LOAN_ID);
      const unfreezingTimestamp = await getTxTimestamp(unfreezingTx);

      const frozenPeriods = calculatePeriodIndex(unfreezingTimestamp) - calculatePeriodIndex(freezingTimestamp);
      const expectedLoanState = { ...initialLoanState };
      expectedLoanState.trackedTimestamp += frozenPeriods * DEFAULT_PERIOD_IN_SECONDS;
      expectedLoanState.durationInPeriods += frozenPeriods;

      await expect(unfreezingTx)
        .to.emit(marketConnectedToLender, EVENT_NAME_LOAN_UNFROZEN)
        .withArgs(DEFAULT_LOAN_ID);

      const actualLoanState: LoanState = await marketConnectedToLender.getLoanState(DEFAULT_LOAN_ID);
      compareLoanStates(actualLoanState, expectedLoanState);
    }

    it("Executes as expected if it is done at the same loan period as the freezing", async () => {
      const { marketConnectedToLender, initialLoanState } = await setUpFixture(deployLendingMarketAndTakeLoan);
      const frozenInterval = 0;
      await unfreezeAndCheck(marketConnectedToLender, initialLoanState, frozenInterval);
    });

    it("Executes as expected if it is done after some loan periods past the freezing", async () => {
      const { marketConnectedToLender, initialLoanState } = await setUpFixture(deployLendingMarketAndTakeLoan);
      const frozenInterval = DEFAULT_DURATION_IN_PERIODS * DEFAULT_PERIOD_IN_SECONDS;
      await unfreezeAndCheck(marketConnectedToLender, initialLoanState, frozenInterval);
    });

    it("Is reverted if the contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx(market.pause());

      await expect(market.unfreeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if the loan does not exist", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(market.unfreeze(NON_EXISTENT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_NOT_EXIST);
    });

    it("Is reverted if the loan is already repaid", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx((market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, FULL_REPAY_AMOUNT));

      await expect(marketConnectedToLender.unfreeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_ALREADY_REPAID);
    });

    it("Is reverted if the caller is not the lender or an alias", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect((market.connect(attacker) as Contract).unfreeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is reverted if the loan is not frozen", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(marketConnectedToLender.unfreeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_NOT_FROZEN);
    });
  });

  describe("Function 'updateLoanDuration()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { market, marketConnectedToLender, initialLoanState } = await loadFixture(deployLendingMarketAndTakeLoan);
      const newDuration = DEFAULT_DURATION_IN_PERIODS + 1;
      const expectedLoanState: LoanState = { ...initialLoanState };
      expectedLoanState.durationInPeriods = newDuration;

      await expect(marketConnectedToLender.updateLoanDuration(DEFAULT_LOAN_ID, newDuration))
        .to.emit(market, EVENT_NAME_LOAN_DURATION_UPDATED)
        .withArgs(DEFAULT_LOAN_ID, newDuration, DEFAULT_DURATION_IN_PERIODS);
      const actualLoanState = await market.getLoanState(DEFAULT_LOAN_ID);
      compareLoanStates(actualLoanState, expectedLoanState);
    });

    it("Is reverted if the contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx(market.pause());

      await expect(market.updateLoanDuration(DEFAULT_LOAN_ID, DEFAULT_DURATION_IN_PERIODS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if the loan does not exist", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(market.updateLoanDuration(NON_EXISTENT_LOAN_ID, DEFAULT_DURATION_IN_PERIODS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_NOT_EXIST);
    });

    it("Is reverted if the loan is already repaid", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx((market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, FULL_REPAY_AMOUNT));

      await expect(market.updateLoanDuration(DEFAULT_LOAN_ID, DEFAULT_DURATION_IN_PERIODS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_ALREADY_REPAID);
    });

    it("Is reverted if the caller is not the lender or an alias", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(
        (market.connect(attacker) as Contract).updateLoanDuration(DEFAULT_LOAN_ID, DEFAULT_DURATION_IN_PERIODS)
      ).to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is reverted if the new duration is the same as the previous one or less", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(marketConnectedToLender.updateLoanDuration(DEFAULT_LOAN_ID, DEFAULT_DURATION_IN_PERIODS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_INAPPROPRIATE_DURATION_IN_PERIODS);
      await expect(marketConnectedToLender.updateLoanDuration(DEFAULT_LOAN_ID, DEFAULT_DURATION_IN_PERIODS - 1))
        .to.be.revertedWithCustomError(market, ERROR_NAME_INAPPROPRIATE_DURATION_IN_PERIODS);
    });
  });

  describe("Function 'updateLoanInterestRatePrimary()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { market, marketConnectedToLender, initialLoanState } = await loadFixture(deployLendingMarketAndTakeLoan);
      const newInterestRate = DEFAULT_INTEREST_RATE_PRIMARY - 1;
      const expectedLoanState = { ...initialLoanState };
      expectedLoanState.interestRatePrimary = newInterestRate;

      await expect(
        marketConnectedToLender.updateLoanInterestRatePrimary(DEFAULT_LOAN_ID, newInterestRate)
      ).to.emit(
        market,
        EVENT_NAME_LOAN_INTEREST_RATE_PRIMARY_UPDATED
      ).withArgs(DEFAULT_LOAN_ID, newInterestRate, DEFAULT_INTEREST_RATE_PRIMARY);
      const actualLoanState = await marketConnectedToLender.getLoanState(DEFAULT_LOAN_ID);
      compareLoanStates(actualLoanState, expectedLoanState);
    });

    it("Is reverted if the contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx(market.pause());

      await expect(market.updateLoanInterestRatePrimary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_PRIMARY))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if the loan does not exist", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(market.updateLoanInterestRatePrimary(NON_EXISTENT_LOAN_ID, DEFAULT_INTEREST_RATE_PRIMARY))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_NOT_EXIST);
    });

    it("Is reverted if the loan is already repaid", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx((market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, FULL_REPAY_AMOUNT));

      await expect(
        marketConnectedToLender.updateLoanInterestRatePrimary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_PRIMARY)
      ).to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_ALREADY_REPAID);
    });

    it("Is reverted if the caller is not the lender or an alias", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(
        (market.connect(attacker) as Contract).updateLoanInterestRatePrimary(
          DEFAULT_LOAN_ID,
          DEFAULT_INTEREST_RATE_PRIMARY
        )
      ).to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is is reverted if the new interest rate is the same as the previous one or greater", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(
        marketConnectedToLender.updateLoanInterestRatePrimary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_PRIMARY)
      ).to.be.revertedWithCustomError(market, ERROR_NAME_INAPPROPRIATE_INTEREST_RATE);
      await expect(
        marketConnectedToLender.updateLoanInterestRatePrimary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_PRIMARY + 1)
      ).to.be.revertedWithCustomError(market, ERROR_NAME_INAPPROPRIATE_INTEREST_RATE);
    });
  });

  describe("Function 'updateLoanInterestRateSecondary()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { market, marketConnectedToLender, initialLoanState } = await loadFixture(deployLendingMarketAndTakeLoan);
      const newInterestRate = DEFAULT_INTEREST_RATE_SECONDARY - 1;
      const expectedLoanState = { ...initialLoanState };
      expectedLoanState.interestRateSecondary = newInterestRate;

      await expect(
        marketConnectedToLender.updateLoanInterestRateSecondary(DEFAULT_LOAN_ID, newInterestRate)
      ).to.emit(
        market,
        EVENT_NAME_LOAN_INTEREST_RATE_SECONDARY_UPDATED
      ).withArgs(DEFAULT_LOAN_ID, newInterestRate, DEFAULT_INTEREST_RATE_SECONDARY);
      const actualLoanState = await marketConnectedToLender.getLoanState(DEFAULT_LOAN_ID);
      compareLoanStates(actualLoanState, expectedLoanState);
    });

    it("Is reverted if the contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx(market.pause());

      await expect(market.updateLoanInterestRateSecondary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_SECONDARY))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if the loan does not exist", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(market.updateLoanInterestRateSecondary(NON_EXISTENT_LOAN_ID, DEFAULT_INTEREST_RATE_SECONDARY))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_NOT_EXIST);
    });

    it("Is reverted if the loan is already repaid", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx((market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, FULL_REPAY_AMOUNT));

      await expect(
        marketConnectedToLender.updateLoanInterestRateSecondary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_SECONDARY)
      ).to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_ALREADY_REPAID);
    });

    it("Is reverted if the caller is not the lender or an alias", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(
        (market.connect(attacker) as Contract).updateLoanInterestRateSecondary(
          DEFAULT_LOAN_ID,
          DEFAULT_INTEREST_RATE_SECONDARY
        )
      ).to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is is reverted if the new interest rate is the same as the previous one or greater", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(
        marketConnectedToLender.updateLoanInterestRateSecondary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_SECONDARY)
      ).to.be.revertedWithCustomError(market, ERROR_NAME_INAPPROPRIATE_INTEREST_RATE);
      await expect(
        marketConnectedToLender.updateLoanInterestRateSecondary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_SECONDARY + 1)
      ).to.be.revertedWithCustomError(market, ERROR_NAME_INAPPROPRIATE_INTEREST_RATE);
    });
  });

  describe("Function 'configureAlias()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect((market.connect(lender) as Contract).configureAlias(alias.address, ALIAS_STATUS_CONFIGURED))
        .to.emit(market, EVENT_NAME_LENDER_ALIAS_CONFIGURED)
        .withArgs(lender.address, alias.address, ALIAS_STATUS_CONFIGURED);

      expect(await market.hasAlias(lender.address, alias.address)).to.eq(ALIAS_STATUS_CONFIGURED);

      await expect((market.connect(lender) as Contract).configureAlias(alias.address, ALIAS_STATUS_NOT_CONFIGURED))
        .to.emit(market, EVENT_NAME_LENDER_ALIAS_CONFIGURED)
        .withArgs(lender.address, alias.address, ALIAS_STATUS_NOT_CONFIGURED);

      expect(await market.hasAlias(lender.address, alias.address)).to.eq(ALIAS_STATUS_NOT_CONFIGURED);
    });

    it("Is reverted if the contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.pause());

      await expect(market.configureAlias(alias.address, ALIAS_STATUS_CONFIGURED))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if the account address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.configureAlias(ZERO_ADDRESS, ALIAS_STATUS_CONFIGURED))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if the new alias state is the same as the previous one", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await expect(market.configureAlias(alias.address, ALIAS_STATUS_NOT_CONFIGURED))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ALREADY_CONFIGURED);

      await proveTx(market.configureAlias(alias.address, ALIAS_STATUS_CONFIGURED));

      await expect(market.configureAlias(alias.address, ALIAS_STATUS_CONFIGURED))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ALREADY_CONFIGURED);
    });
  });

  describe("Function 'getLoanPreview()'", async () => {
    async function checkLoanPreview(market: Contract, loanState: LoanState, timestamp: number): Promise<LoanPreview> {
      const expectedLoanPreview = defineLoanPreview(loanState, timestamp);
      const actualLoanPreview = await market.getLoanPreview(DEFAULT_LOAN_ID, timestamp);
      compareLoanPreview(actualLoanPreview, expectedLoanPreview);
      return expectedLoanPreview;
    }

    describe("Executes as expected for different loan states", async () => {
      it("Except freezing", async () => {
        const { market, initialLoanState } = await loadFixture(deployLendingMarketAndTakeLoan);
        const loanState = { ...initialLoanState };

        // Check the preview just after the loan taken
        let timestamp = initialLoanState.startTimestamp;
        let expectedLoanPreview: LoanPreview = defineLoanPreview(loanState, timestamp);
        const actualLoanPreview: LoanPreview = await market.getLoanPreview(DEFAULT_LOAN_ID, 0);
        compareLoanPreview(actualLoanPreview, expectedLoanPreview);
        await checkLoanPreview(market, loanState, timestamp);

        // Check the preview after one loan period passed after the loan taken
        timestamp += DEFAULT_PERIOD_IN_SECONDS;
        expectedLoanPreview = await checkLoanPreview(market, loanState, timestamp);

        // Check the preview after one loan period passed after the loan taken and after a partial repayment
        await increaseBlockTimestampTo(timestamp);
        const repaymentTx = (market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, REPAY_AMOUNT);
        timestamp = await getTxTimestamp(repaymentTx);
        loanState.trackedTimestamp = timestamp;
        loanState.trackedBorrowBalance = expectedLoanPreview.outstandingBalance - REPAY_AMOUNT;
        await checkLoanPreview(market, loanState, timestamp);

        // Check the preview after the previous actions and one more loan period passed
        timestamp += DEFAULT_PERIOD_IN_SECONDS;
        await checkLoanPreview(market, loanState, timestamp);

        // Check the preview after the previous actions and after the loan is defaulted
        timestamp = initialLoanState.startTimestamp + (DEFAULT_DURATION_IN_PERIODS + 1) * DEFAULT_PERIOD_IN_SECONDS;
        await checkLoanPreview(market, loanState, timestamp);

        // Check the preview after the previous actions and the full loan repayment
        await increaseBlockTimestampTo(timestamp);
        const fullRepaymentTx = (market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, FULL_REPAY_AMOUNT);
        timestamp = await getTxTimestamp(fullRepaymentTx);
        loanState.trackedBorrowBalance = 0;
        await checkLoanPreview(market, loanState, timestamp);

        // Check the preview after the previous actions and one more loan period passed
        timestamp += DEFAULT_PERIOD_IN_SECONDS;
        await checkLoanPreview(market, loanState, timestamp);
      });

      it("With freezing", async () => {
        const { market, marketConnectedToLender, initialLoanState } = await loadFixture(deployLendingMarketAndTakeLoan);
        const loanState = { ...initialLoanState };

        // Check the preview after one loan period passed after the loan taken and after the loan is frozen
        let timestamp = loanState.startTimestamp + DEFAULT_PERIOD_IN_SECONDS;
        await increaseBlockTimestampTo(timestamp);
        const freezingTx = marketConnectedToLender.freeze(DEFAULT_LOAN_ID);
        timestamp = await getTxTimestamp(freezingTx);
        loanState.freezeTimestamp = timestamp;
        await checkLoanPreview(market, loanState, timestamp);

        // Check the preview after the previous actions and one more loan period passed
        timestamp += DEFAULT_PERIOD_IN_SECONDS;
        await checkLoanPreview(market, loanState, timestamp);

        // Check the preview after the previous actions and the full loan repayment
        await increaseBlockTimestampTo(timestamp);
        const fullRepaymentTx = (market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, FULL_REPAY_AMOUNT);
        timestamp = await getTxTimestamp(fullRepaymentTx);
        loanState.trackedBorrowBalance = 0;
        await checkLoanPreview(market, loanState, timestamp);

        // Check the preview after the previous actions and one more loan period passed
        timestamp += DEFAULT_PERIOD_IN_SECONDS;
        await checkLoanPreview(market, loanState, timestamp);
      });
    });
  });

  describe("Function 'calculateOutstandingBalance()'", async () => {
    it("Executes as expected", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);
      const actualBalance = await market.calculateOutstandingBalance(
        BORROW_AMOUNT,
        DEFAULT_DURATION_IN_PERIODS,
        DEFAULT_INTEREST_RATE_PRIMARY,
        DEFAULT_INTEREST_RATE_FACTOR,
        InterestFormula.Compound
      );

      const expectedBalance = calculateOutstandingBalance(
        BORROW_AMOUNT,
        DEFAULT_DURATION_IN_PERIODS,
        DEFAULT_INTEREST_RATE_PRIMARY,
        DEFAULT_INTEREST_RATE_FACTOR
      );
      expect(actualBalance).to.eq(expectedBalance);
    });

    it("Is reverted if is called with a non-implemented formula type", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);
      await expect(market.calculateOutstandingBalance(
        BORROW_AMOUNT,
        DEFAULT_DURATION_IN_PERIODS,
        DEFAULT_INTEREST_RATE_PRIMARY,
        DEFAULT_INTEREST_RATE_FACTOR,
        InterestFormula.Simple
      )).to.be.revertedWithCustomError(market, ERROR_NAME_INTEREST_FORMULA_NOT_IMPLEMENTED);
    });
  });
});
