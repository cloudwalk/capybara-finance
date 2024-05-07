import { ethers, network, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture, time } from "@nomicfoundation/hardhat-network-helpers";
import { proveTx } from "../../test-utils/eth";

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

  [key: string]: string | number | InterestFormula | boolean; // Index signature
}

interface LoanPreview {
  periodIndex: number,
  outstandingBalance: number

  [key: string]: number // Index signature

}

enum InterestFormula {
  // Simple = 0, Not used it tests
  Compound = 1
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
const EVENT_NAME_LOAN_UNFROZEN = "LoanUnfrozen";
const EVENT_NAME_MARKET_REGISTRY_CHANGED = "MarketRegistryChanged";
const EVENT_NAME_PAUSED = "Paused";
const EVENT_NAME_UNPAUSED = "Unpaused";

const TOKEN_NAME = "TEST";
const TOKEN_SYMBOL = "TST";
const ZERO_ADDRESS = ethers.ZeroAddress;
const BORROW_AMOUNT = 100;
const REPAY_AMOUNT = 50;
const FULL_REPAY_AMOUNT = ethers.MaxUint256;
const MINT_AMOUNT = 1000000000000000;
const BORROWER_SUPPLY_AMOUNT = 1000000000;
const DEPOSIT_AMOUNT = 1000000;
const DEFAULT_INTEREST_RATE_PRIMARY = 10;
const DEFAULT_INTEREST_RATE_SECONDARY = 20;
const DEFAULT_INTEREST_RATE_FACTOR = 15;
const DEFAULT_PERIOD_IN_SECONDS = 60;
const DEFAULT_DURATION_IN_PERIODS = 10;
const DEFAULT_ADDON_AMOUNT = 10;
const DEFAULT_LOAN_ID = 0;
const DEFAULT_NUMBER_OF_PERIODS = 20;

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

  let creditLineAddress: string;
  let liquidityPoolAddress: string;
  let tokenAddress: string;

  before(async () => {
    lendingMarketFactory = await ethers.getContractFactory("LendingMarket");
    creditLineFactory = await ethers.getContractFactory("CreditLineMock");
    liquidityPoolFactory = await ethers.getContractFactory("LiquidityPoolMock");
    tokenFactory = await ethers.getContractFactory("ERC20Mock");

    creditLine = await creditLineFactory.deploy() as Contract;
    await creditLine.waitForDeployment();
    creditLineAddress = await creditLine.getAddress();

    liquidityPool = await liquidityPoolFactory.deploy() as Contract;
    await liquidityPool.waitForDeployment();
    liquidityPoolAddress = await liquidityPool.getAddress();

    token = await tokenFactory.deploy() as Contract;
    await token.waitForDeployment();
    tokenAddress = await token.getAddress();

    [owner, registry, lender, borrower, addonRecipient, alias, attacker] = await ethers.getSigners();
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

  function createExpectedLoanState(timestamp: number): LoanState {
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
      autoRepayment: true
    };
  }

  function compareLoanStates(actualState: LoanState, expectedState: LoanState) {
    Object.keys(expectedState).forEach(property => {
      expect(actualState[property]).to.eq(
        expectedState[property],
        `Mismatch in the "${property}" property of the credit line config`
      );
    });
  }

  function compareLoanPreview(actualState: LoanPreview, expectedState: LoanPreview) {
    Object.keys(expectedState).forEach(property => {
      expect(actualState[property]).to.eq(
        expectedState[property],
        `Mismatch in the "${property}" property of the credit line config`
      );
    });
  }

  function calculateOutstandingBalance(
    originalBalance: number,
    numberOfPeriods: number,
    interestRate: number,
    interestRateFactor: number,
  ): number {
    let outstandingBalance = originalBalance;
    for (let i = 0; i < numberOfPeriods; i++) {
      const interest = (outstandingBalance * interestRate) / interestRateFactor;
      outstandingBalance += Math.round(interest);
    }
    return outstandingBalance;
  }

  async function deployLendingMarket(): Promise<{ market: Contract }> {
    let market = await upgrades.deployProxy(lendingMarketFactory, [
      TOKEN_NAME, TOKEN_SYMBOL
    ]);

    market = market.connect(owner) as Contract;

    return {
      market
    };
  }

  async function deployLendingMarketAndConfigureItForLoan(): Promise<{ market: Contract }> {
    const { market } = await deployLendingMarket();

    // register and configure credit line & liquidity pool
    await proveTx(market.registerCreditLine(lender.address, creditLineAddress));
    await proveTx(market.registerLiquidityPool(lender.address, liquidityPoolAddress));
    await proveTx((market.connect(lender) as Contract)
      .assignLiquidityPoolToCreditLine(creditLineAddress, liquidityPoolAddress));

    // mock configurations
    await proveTx(creditLine.mockTokenAddress(tokenAddress));
    await proveTx(creditLine.mockLoanTerms(borrower.address, BORROW_AMOUNT, createMockTerms()));

    // supply tokens
    await proveTx(token.mint(lender.address, MINT_AMOUNT));
    await proveTx((token.connect(lender) as Contract).transfer(liquidityPoolAddress, DEPOSIT_AMOUNT));
    await proveTx(liquidityPool.approveMarket(await market.getAddress(), tokenAddress));
    await proveTx((token.connect(borrower) as Contract).approve(await market.getAddress(), ethers.MaxUint256));

    return {
      market
    };
  }

  async function deployLendingMarketAndTakeLoan(): Promise<{
    market: Contract,
    marketConnectedToLender: Contract
  }> {
    const { market } = await deployLendingMarketAndConfigureItForLoan();
    const marketConnectedToLender = market.connect(lender) as Contract;

    await proveTx((token.connect(lender) as Contract).transfer(borrower.address, BORROWER_SUPPLY_AMOUNT));

    await proveTx((market.connect(borrower) as Contract)
      .takeLoan(creditLineAddress, BORROW_AMOUNT, DEFAULT_DURATION_IN_PERIODS));

    return {
      market,
      marketConnectedToLender
    };
  }

  describe("Function initialize()", async () => {
    it("Configures contract as expected", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      expect(await market.name()).to.eq(TOKEN_NAME);
      expect(await market.symbol()).to.eq(TOKEN_SYMBOL);
      expect(await market.registry()).to.eq(ZERO_ADDRESS);
      expect(await market.owner()).to.eq(owner.address);
    });

    it("Is reverted if called second time", async () => {
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
    it("Executes as expected and emits correct event", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.setRegistry(registry.address))
        .to.emit(market, EVENT_NAME_MARKET_REGISTRY_CHANGED)
        .withArgs(registry.address, ZERO_ADDRESS);

      expect(await market.registry()).to.eq(registry.address);
    });

    it("Is reverted if caller not the owner", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect((market.connect(attacker) as Contract).setRegistry(registry.address))
        .to.be.revertedWithCustomError(market, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });

    it("Is reverted if registry is already configured", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.setRegistry(registry.address));

      await expect(market.setRegistry(registry.address))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ALREADY_CONFIGURED);
    });
  });

  describe("Function 'registerCreditLine()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.registerCreditLine(lender.address, creditLineAddress))
        .to.emit(market, EVENT_NAME_CREDIT_LINE_REGISTERED)
        .withArgs(lender.address, creditLineAddress);

      expect(await market.getCreditLineLender(creditLineAddress))
        .to.eq(lender.address);
    });

    it("Is reverted if caller is not the owner", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect((market.connect(attacker) as Contract)
        .registerCreditLine(lender.address, creditLineAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is reverted if contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.pause());

      await expect(market.registerCreditLine(lender.address, creditLineAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if credit line address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.registerCreditLine(lender.address, ZERO_ADDRESS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if lender address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.registerCreditLine(ZERO_ADDRESS, creditLineAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if credit line is already registered", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.registerCreditLine(lender.address, creditLineAddress));

      await expect(market.registerCreditLine(lender.address, creditLineAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_CREDIT_LINE_ALREADY_REGISTERED);
    });
  });

  describe("Function 'registerLiquidityPool()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.registerLiquidityPool(lender.address, liquidityPoolAddress))
        .to.emit(market, EVENT_NAME_LIQUIDITY_POOL_REGISTERED)
        .withArgs(lender.address, liquidityPoolAddress);

      expect(await market.getLiquidityPoolLender(liquidityPoolAddress))
        .to.eq(lender.address);
    });

    it("Is reverted if caller is not the owner", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect((market.connect(attacker) as Contract)
        .registerLiquidityPool(lender.address, liquidityPoolAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is reverted if contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.pause());

      await expect(market.registerLiquidityPool(lender.address, liquidityPoolAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if liquidity pool address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.registerLiquidityPool(lender.address, ZERO_ADDRESS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if lender address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.registerLiquidityPool(ZERO_ADDRESS, liquidityPoolAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if liquidity pool is already registered", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.registerLiquidityPool(lender.address, liquidityPoolAddress));

      await expect(market.registerLiquidityPool(lender.address, liquidityPoolAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LIQUIDITY_POOL_ALREADY_REGISTERED);
    });
  });

  describe("Function 'updateCreditLineLender()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.updateCreditLineLender(creditLineAddress, lender.address))
        .to.emit(market, EVENT_NAME_CREDIT_LINE_LENDER_UPDATED)
        .withArgs(creditLineAddress, lender.address, ZERO_ADDRESS);

      expect(await market.getCreditLineLender(creditLineAddress)).to.eq(lender.address);
    });

    it("Is reverted if caller is not the owner", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect((market.connect(attacker) as Contract)
        .updateCreditLineLender(creditLineAddress, lender.address))
        .to.be.revertedWithCustomError(market, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });

    it("Is reverted if credit line address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.updateCreditLineLender(ZERO_ADDRESS, lender.address))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if lender address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.updateCreditLineLender(creditLineAddress, ZERO_ADDRESS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if credit line lender is already configured", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.updateCreditLineLender(creditLineAddress, lender.address));

      await expect(market.updateCreditLineLender(creditLineAddress, lender.address))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ALREADY_CONFIGURED);
    });
  });

  describe("Function 'updateLiquidityPoolLender()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.updateLiquidityPoolLender(liquidityPoolAddress, lender.address))
        .to.emit(market, EVENT_NAME_LIQUIDITY_POOL_LENDER_UPDATED)
        .withArgs(liquidityPool, lender.address, ZERO_ADDRESS);

      expect(await market.getLiquidityPoolLender(liquidityPoolAddress)).to.eq(lender.address);
    });

    it("Is reverted if caller is not the owner", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect((market.connect(attacker) as Contract)
        .updateLiquidityPoolLender(liquidityPoolAddress, lender.address))
        .to.be.revertedWithCustomError(market, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });

    it("Is reverted if liquidity pool address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.updateLiquidityPoolLender(ZERO_ADDRESS, lender.address))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if lender address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.updateLiquidityPoolLender(liquidityPoolAddress, ZERO_ADDRESS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if credit line lender is already configured", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.updateLiquidityPoolLender(liquidityPoolAddress, lender.address));

      await expect(market.updateLiquidityPoolLender(liquidityPoolAddress, lender.address))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ALREADY_CONFIGURED);
    });
  });

  describe("Function 'assignLiquidityPoolToCreditLine()'", async () => {
    it("Executes as expected and emits correct events", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.registerCreditLine(lender.address, creditLineAddress));
      await proveTx(market.registerLiquidityPool(lender.address, liquidityPoolAddress));

      await expect((market.connect(lender) as Contract)
        .assignLiquidityPoolToCreditLine(creditLineAddress, liquidityPoolAddress))
        .to.emit(market, EVENT_NAME_LIQUIDITY_POOL_ASSIGNED_TO_CREDIT_LINE)
        .withArgs(creditLineAddress, liquidityPoolAddress, ZERO_ADDRESS);

      expect(await market.getLiquidityPoolByCreditLine(creditLineAddress)).to.eq(liquidityPoolAddress);
    });

    it("Is reverted if contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.pause());

      await expect(market.assignLiquidityPoolToCreditLine(creditLineAddress, liquidityPoolAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if credit line address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.assignLiquidityPoolToCreditLine(ZERO_ADDRESS, liquidityPoolAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if liquidity pool address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.assignLiquidityPoolToCreditLine(creditLineAddress, ZERO_ADDRESS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if credit line is already assigned to liquidity pool", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.registerCreditLine(lender.address, creditLineAddress));
      await proveTx(market.registerLiquidityPool(lender.address, liquidityPoolAddress));

      const marketConnectedToLender = market.connect(lender) as Contract;

      await proveTx(marketConnectedToLender.assignLiquidityPoolToCreditLine(creditLineAddress, liquidityPoolAddress));

      await expect(marketConnectedToLender.assignLiquidityPoolToCreditLine(creditLineAddress, liquidityPoolAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_NOT_IMPLEMENTED);
    });

    it("Is reverted if caller is not credit line`s lender", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.registerLiquidityPool(lender.address, liquidityPoolAddress));

      await expect((market.connect(lender) as Contract).assignLiquidityPoolToCreditLine(creditLineAddress, liquidityPoolAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is reverted if caller if not liquidity pool`s lender", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.registerCreditLine(lender.address, creditLineAddress));

      await expect((market.connect(lender) as Contract).assignLiquidityPoolToCreditLine(creditLineAddress, liquidityPoolAddress))
        .to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });
  });

  describe("Function 'takeLoan()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { market } = await loadFixture(deployLendingMarketAndConfigureItForLoan);

      const TOTAL_BORROW_AMOUNT = BORROW_AMOUNT + DEFAULT_ADDON_AMOUNT;

      const tx = await ((market.connect(borrower) as Contract)
        .takeLoan(creditLineAddress, BORROW_AMOUNT, DEFAULT_DURATION_IN_PERIODS));

      const timestamp = await time.latest();

      const expectedLoan: LoanState = createExpectedLoanState(timestamp);
      const submittedLoan: LoanState = await market.getLoanState(DEFAULT_LOAN_ID);

      compareLoanStates(submittedLoan, expectedLoan);

      await expect(tx).to.changeTokenBalances(
        token,
        [liquidityPool, borrower, addonRecipient],
        [-TOTAL_BORROW_AMOUNT, +BORROW_AMOUNT, +DEFAULT_ADDON_AMOUNT]
      );

      await expect(tx).to.emit(market, EVENT_NAME_LOAN_TAKEN)
        .withArgs(DEFAULT_LOAN_ID, borrower.address, TOTAL_BORROW_AMOUNT, DEFAULT_DURATION_IN_PERIODS);
    });

    it("Is reverted if contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.pause());

      await expect(market.pause())
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if credit line address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.takeLoan(ZERO_ADDRESS, BORROW_AMOUNT, DEFAULT_DURATION_IN_PERIODS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if borrow amount is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.takeLoan(creditLineAddress, 0, DEFAULT_DURATION_IN_PERIODS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_INVALID_AMOUNT);
    });

    it("Is reverted if credit line is not registered", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.takeLoan(creditLineAddress, BORROW_AMOUNT, DEFAULT_DURATION_IN_PERIODS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_CREDIT_LINE_NOT_REGISTERED);
    });

    it("Is reverted if liquidity pool is not registered", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.registerCreditLine(lender.address, creditLineAddress));

      await expect(market.takeLoan(creditLineAddress, BORROW_AMOUNT, DEFAULT_DURATION_IN_PERIODS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LIQUIDITY_POOL_NOT_REGISTERED);
    });
  });

  describe("Function 'repayLoan()'", async () => {
    it("Executes as expected and emits correct event with partial repayment", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      const tx = await ((market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, REPAY_AMOUNT));

      await expect(tx)
        .to.emit(market, EVENT_NAME_LOAN_REPAYMENT)
        .withArgs(
          DEFAULT_LOAN_ID,
          borrower.address,
          borrower.address,
          REPAY_AMOUNT,
          BORROW_AMOUNT + DEFAULT_ADDON_AMOUNT - REPAY_AMOUNT // outstanding balance
        );

      await expect(tx).to.changeTokenBalances(
        token,
        [liquidityPool, borrower],
        [+REPAY_AMOUNT, -REPAY_AMOUNT]
      );
    });

    it("Executes as expected and emits correct event with full repayment", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      const tx = await ((market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, FULL_REPAY_AMOUNT));

      const expectedBorrowAmount = BORROW_AMOUNT + DEFAULT_ADDON_AMOUNT;

      await expect(tx)
        .to.emit(market, EVENT_NAME_LOAN_REPAYMENT)
        .withArgs(
          DEFAULT_LOAN_ID,
          borrower.address,
          borrower.address,
          BORROW_AMOUNT + DEFAULT_ADDON_AMOUNT,
          0 // outstanding balance
        );

      await expect(tx).to.changeTokenBalances(
        token,
        [liquidityPool, borrower],
        [+expectedBorrowAmount, -expectedBorrowAmount]
      );
    });

    it("Executes as expected if loan is not defaulted", async () => {
      const { market } = await setUpFixture(deployLendingMarketAndTakeLoan);
      const timestamp = await time.latest();
      const futureTimestamp = timestamp + DEFAULT_DURATION_IN_PERIODS / 2 * DEFAULT_PERIOD_IN_SECONDS;
      const expectedLoan: LoanPreview = await market.getLoanPreview(DEFAULT_LOAN_ID, futureTimestamp);

      await time.increaseTo(futureTimestamp);
      const currentLoan: LoanPreview = await market.getLoanPreview(DEFAULT_LOAN_ID, 0);

      expect(expectedLoan.outstandingBalance).to.eq(currentLoan.outstandingBalance);

      await expect((market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, expectedLoan.outstandingBalance))
        .to.emit(market, EVENT_NAME_LOAN_REPAYMENT)
        .withArgs(
          DEFAULT_LOAN_ID,
          borrower.address,
          borrower.address,
          expectedLoan.outstandingBalance,
          0 // outstanding balance after payment
        );
    });

    it("Executes as expected if loan is defaulted", async () => {
      const { market } = await setUpFixture(deployLendingMarketAndTakeLoan);
      const timestamp = await time.latest();
      const futureTimestamp = timestamp + (DEFAULT_DURATION_IN_PERIODS + 1) * DEFAULT_PERIOD_IN_SECONDS;
      const expectedLoan: LoanPreview = await market.getLoanPreview(DEFAULT_LOAN_ID, futureTimestamp);

      await time.increaseTo(futureTimestamp);
      const currentLoan: LoanPreview = await market.getLoanPreview(DEFAULT_LOAN_ID, 0);

      expect(expectedLoan.outstandingBalance).to.eq(currentLoan.outstandingBalance);

      await expect((market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, expectedLoan.outstandingBalance))
        .to.emit(market, EVENT_NAME_LOAN_REPAYMENT)
        .withArgs(
          DEFAULT_LOAN_ID,
          borrower.address,
          borrower.address,
          expectedLoan.outstandingBalance,
          0 // outstanding balance after payment
        );
    });

    it("Is reverted if contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx(market.pause());

      await expect(market.repayLoan(DEFAULT_LOAN_ID, REPAY_AMOUNT))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if loan does not exist", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.repayLoan(DEFAULT_LOAN_ID, REPAY_AMOUNT))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_NOT_EXIST);
    });

    it("Is reverted if loan is already repaid", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await proveTx((market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, FULL_REPAY_AMOUNT));

      await expect(market.repayLoan(DEFAULT_LOAN_ID, REPAY_AMOUNT))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_ALREADY_REPAID);
    });

    it("Is reverted if repay amount is zero", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(market.repayLoan(DEFAULT_LOAN_ID, 0))
        .to.be.revertedWithCustomError(market, ERROR_NAME_INVALID_AMOUNT);
    });

    it("Is reverted if repay amount is bigger than outstanding balance", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(market.repayLoan(DEFAULT_LOAN_ID, BORROWER_SUPPLY_AMOUNT))
        .to.be.revertedWithCustomError(market, ERROR_NAME_INVALID_AMOUNT);
    });

    it("Is reverted if called by liquidity pool and auto repayment is not allowed", async () => {
      const { market } = await loadFixture(deployLendingMarketAndConfigureItForLoan);
      const terms: LoanTerms = createMockTerms();
      terms.autoRepayment = false;

      await proveTx(creditLine.mockLoanTerms(borrower.address, BORROW_AMOUNT, terms));

      await proveTx((market.connect(borrower) as Contract)
        .takeLoan(creditLineAddress, BORROW_AMOUNT, DEFAULT_DURATION_IN_PERIODS));

      await expect(liquidityPool.autoRepay(await market.getAddress(), DEFAULT_LOAN_ID, FULL_REPAY_AMOUNT))
        .to.be.revertedWithCustomError(market, ERROR_NAME_AUTO_REPAYMENT_NOT_ALLOWED);
    });
  });

  describe("Function 'freeze()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(marketConnectedToLender.freeze(DEFAULT_LOAN_ID))
        .to.emit(market, EVENT_NAME_LOAN_FROZEN)
        .withArgs(DEFAULT_LOAN_ID);
    });

    it("Is reverted if contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.pause());

      await expect(market.freeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if loan does not exist", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.freeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_NOT_EXIST);
    });

    it("Is reverted if loan is already repaid", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx((market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, FULL_REPAY_AMOUNT));

      await expect(market.freeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_ALREADY_REPAID);
    });

    it("Is reverted if caller is not lender or alias", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect((market.connect(attacker) as Contract).freeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is reverted if loan is already frozen", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx(marketConnectedToLender.freeze(DEFAULT_LOAN_ID));

      await expect(marketConnectedToLender.freeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_ALREADY_FROZEN);
    });
  });

  describe("Function 'unfreeze()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { market, marketConnectedToLender } = await setUpFixture(deployLendingMarketAndTakeLoan);
      await proveTx(marketConnectedToLender.freeze(DEFAULT_LOAN_ID));
      const timestamp = await time.latest();
      const frozenLoanState: LoanPreview = await market.getLoanPreview(DEFAULT_LOAN_ID, timestamp);
      await time.increaseTo(timestamp + DEFAULT_PERIOD_IN_SECONDS * DEFAULT_NUMBER_OF_PERIODS);

      await expect(marketConnectedToLender.unfreeze(DEFAULT_LOAN_ID))
        .to.emit(market, EVENT_NAME_LOAN_UNFROZEN)
        .withArgs(DEFAULT_LOAN_ID);

      const unfrozenLoanState: LoanPreview = await market.getLoanPreview(DEFAULT_LOAN_ID, timestamp);

      expect(frozenLoanState.outstandingBalance).to.eq(unfrozenLoanState.outstandingBalance);
      expect(frozenLoanState.periodIndex).to.eq(unfrozenLoanState.periodIndex);
    });

    it("Is reverted if contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.pause());

      await expect(market.unfreeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if loan does not exist", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.unfreeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_NOT_EXIST);
    });

    it("Is reverted if loan is already repaid", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx((market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, FULL_REPAY_AMOUNT));

      await expect(marketConnectedToLender.unfreeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_ALREADY_REPAID);
    });

    it("Is reverted if caller is not lender or alias", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect((market.connect(attacker) as Contract).unfreeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is reverted if loan is not frozen", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(marketConnectedToLender.unfreeze(DEFAULT_LOAN_ID))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_NOT_FROZEN);
    });
  });

  describe("Function 'updateLoanDuration()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(marketConnectedToLender.updateLoanDuration(DEFAULT_LOAN_ID, DEFAULT_DURATION_IN_PERIODS + 1))
        .to.emit(market, EVENT_NAME_LOAN_DURATION_UPDATED)
        .withArgs(DEFAULT_LOAN_ID, DEFAULT_DURATION_IN_PERIODS + 1, DEFAULT_DURATION_IN_PERIODS);
    });

    it("Is reverted if contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.pause());

      await expect(market.updateLoanDuration(DEFAULT_LOAN_ID, DEFAULT_DURATION_IN_PERIODS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if loan does not exist", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.updateLoanDuration(DEFAULT_LOAN_ID, DEFAULT_DURATION_IN_PERIODS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_NOT_EXIST);
    });

    it("Is reverted if loan is already repaid", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx((market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, FULL_REPAY_AMOUNT));

      await expect(market.updateLoanDuration(DEFAULT_LOAN_ID, DEFAULT_DURATION_IN_PERIODS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_ALREADY_REPAID);
    });

    it("Is reverted if caller is not lender or alias", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect((market.connect(attacker) as Contract)
        .updateLoanDuration(DEFAULT_LOAN_ID, DEFAULT_DURATION_IN_PERIODS))
        .to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is reverted if new duration amount is inappropriate", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(marketConnectedToLender.updateLoanDuration(DEFAULT_LOAN_ID, DEFAULT_DURATION_IN_PERIODS - 1))
        .to.be.revertedWithCustomError(market, ERROR_NAME_INAPPROPRIATE_DURATION_IN_PERIODS);
    });
  });

  describe("Function 'updateLoanInterestRatePrimary()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(marketConnectedToLender.updateLoanInterestRatePrimary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_PRIMARY - 1))
        .to.emit(market, EVENT_NAME_LOAN_INTEREST_RATE_PRIMARY_UPDATED)
        .withArgs(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_PRIMARY - 1, DEFAULT_INTEREST_RATE_PRIMARY);
    });

    it("Is reverted if contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.pause());

      await expect(market.updateLoanInterestRatePrimary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_PRIMARY))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if loan does not exist", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.updateLoanInterestRatePrimary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_PRIMARY))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_NOT_EXIST);
    });

    it("Is reverted if loan is already repaid", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx((market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, FULL_REPAY_AMOUNT));

      await expect(marketConnectedToLender.updateLoanInterestRatePrimary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_PRIMARY))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_ALREADY_REPAID);
    });

    it("Is reverted if caller is not lender or alias", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect((market.connect(attacker) as Contract).updateLoanInterestRatePrimary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_PRIMARY))
        .to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is is reverted if interest rate is inappropriate", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(marketConnectedToLender.updateLoanInterestRatePrimary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_PRIMARY + 1))
        .to.be.revertedWithCustomError(market, ERROR_NAME_INAPPROPRIATE_INTEREST_RATE);
    });
  });

  describe("Function 'updateLoanInterestRateSecondary()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(marketConnectedToLender.updateLoanInterestRateSecondary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_SECONDARY - 1))
        .to.emit(market, EVENT_NAME_LOAN_INTEREST_RATE_SECONDARY_UPDATED)
        .withArgs(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_SECONDARY - 1, DEFAULT_INTEREST_RATE_SECONDARY);
    });

    it("Is reverted if contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.pause());

      await expect(market.updateLoanInterestRateSecondary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_SECONDARY))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if loan does not exist", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.updateLoanInterestRateSecondary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_SECONDARY))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_NOT_EXIST);
    });

    it("Is reverted if loan is already repaid", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);
      await proveTx((market.connect(borrower) as Contract).repayLoan(DEFAULT_LOAN_ID, FULL_REPAY_AMOUNT));

      await expect(marketConnectedToLender.updateLoanInterestRateSecondary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_SECONDARY))
        .to.be.revertedWithCustomError(market, ERROR_NAME_LOAN_ALREADY_REPAID);
    });

    it("Is reverted if caller is not lender or alias", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect((market.connect(attacker) as Contract).updateLoanInterestRateSecondary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_SECONDARY))
        .to.be.revertedWithCustomError(market, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is is reverted if interest rate is inappropriate", async () => {
      const { market, marketConnectedToLender } = await loadFixture(deployLendingMarketAndTakeLoan);

      await expect(marketConnectedToLender.updateLoanInterestRateSecondary(DEFAULT_LOAN_ID, DEFAULT_INTEREST_RATE_SECONDARY + 1))
        .to.be.revertedWithCustomError(market, ERROR_NAME_INAPPROPRIATE_INTEREST_RATE);
    });
  });

  describe("Function 'configureAlias()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect((market.connect(lender) as Contract).configureAlias(alias.address, true))
        .to.emit(market, EVENT_NAME_LENDER_ALIAS_CONFIGURED)
        .withArgs(lender.address, alias.address, true);

      expect(await market.hasAlias(lender.address, alias.address)).to.eq(true);
    });

    it("Is reverted if contract is paused", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.pause());

      await expect(market.configureAlias(alias.address, true))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if account address is zero", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      await expect(market.configureAlias(ZERO_ADDRESS, true))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if alias is already configured", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      await proveTx(market.configureAlias(alias.address, true));

      await expect(market.configureAlias(alias.address, true))
        .to.be.revertedWithCustomError(market, ERROR_NAME_ALREADY_CONFIGURED);
    });
  });

  describe("Function 'getLoanPreview()'", async () => {
    it("Executes as expected", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);

      const actualState: LoanPreview = await market.getLoanPreview(DEFAULT_LOAN_ID, 0);
      const index = await market.calculatePeriodIndex(await time.latest(), DEFAULT_PERIOD_IN_SECONDS);
      const expectedState: LoanPreview = {
        periodIndex: index,
        outstandingBalance: BORROW_AMOUNT + DEFAULT_ADDON_AMOUNT
      };

      compareLoanPreview(actualState, expectedState);
    });
  });

  describe("Function 'calculateOutstandingBalance()'", async () => {
    it("Executes as expected", async () => {
      const { market } = await loadFixture(deployLendingMarketAndTakeLoan);
      const initialBorrowAmount = BigInt(BORROW_AMOUNT) + BigInt(DEFAULT_ADDON_AMOUNT);

      const actualBalance = await market.calculateOutstandingBalance(
        initialBorrowAmount,
        BigInt(DEFAULT_NUMBER_OF_PERIODS),
        BigInt(DEFAULT_INTEREST_RATE_PRIMARY),
        BigInt(DEFAULT_INTEREST_RATE_FACTOR),
        InterestFormula.Compound
      );

      const expectedBalance = BigInt(calculateOutstandingBalance(
        Number(initialBorrowAmount),
        DEFAULT_NUMBER_OF_PERIODS,
        DEFAULT_INTEREST_RATE_PRIMARY,
        DEFAULT_INTEREST_RATE_FACTOR
      ));

      const difference = BigInt(Math.abs(Number(actualBalance) - Number(expectedBalance)));
      const percentageDifference = difference * BigInt(100) / expectedBalance;
      const threshold = BigInt("1"); // 1%

      expect(percentageDifference).to.be.at.most(threshold);
    });
  });
});