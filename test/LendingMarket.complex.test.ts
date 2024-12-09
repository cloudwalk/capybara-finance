import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory, TransactionResponse } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import {
  connect,
  getAddress,
  getBlockTimestamp,
  getLatestBlockTimestamp,
  increaseBlockTimestampTo,
  proveTx
} from "../test-utils/eth";

const ADMIN_ROLE = ethers.id("ADMIN_ROLE");

const ZERO_ADDRESS = ethers.ZeroAddress;
const PERIOD_IN_SECONDS = 86400;
const ADDON_AMOUNT = 0;
const PROGRAM_ID = 1;
const NEGATIVE_TIME_OFFSET = 3 * 60 * 60; // 3 hours

enum BorrowPolicy {
  // SingleActiveLoan = 0,
  // MultipleActiveLoans = 1
  TotalActiveAmountLimit = 2
}

enum ScenarioFinalAction {
  None = 0,
  FullRepayment = 1,
  Revocation = 2,
  RepaymentCheck = 3
}

interface Fixture {
  lendingMarketFactory: ContractFactory;
  creditLineFactory: ContractFactory;
  liquidityPoolFactory: ContractFactory;
  tokenFactory: ContractFactory;

  token: Contract;
  lendingMarket: Contract;
  creditLine: Contract;
  liquidityPool: Contract;

  tokenAddress: string;
  lendingMarketAddress: string;
  creditLineAddress: string;
  liquidityPoolAddress: string;
}

interface TestScenario {
  borrowAmount: number;
  durationInPeriods: number;
  interestRatePrimary: number;
  interestRateSecondary: number;
  iterationStep: number;
  relativePrecision: number;
  repaymentAmounts: number[];
  expectedOutstandingBalancesBeforeRepayment: number[];
  frozenStepIndexes: number[];
  finalAction: ScenarioFinalAction;
}

interface TestScenarioContext {
  scenario: TestScenario;
  fixture?: Fixture;
  stepIndex: number;
  loanId: bigint;
  loanTakingPeriod: number;
  frozenStepIndexes: Set<number>;
  frozenState: boolean;
  poolBalanceAtStart: bigint;
  poolBalanceAtFinish: bigint;
  totalRepaymentAmount: number;
}

interface CreditLineConfig {
  minBorrowAmount: number;
  maxBorrowAmount: number;
  minInterestRatePrimary: number;
  maxInterestRatePrimary: number;
  minInterestRateSecondary: number;
  maxInterestRateSecondary: number;
  minDurationInPeriods: number;
  maxDurationInPeriods: number;
  minAddonFixedRate: number;
  maxAddonFixedRate: number;
  minAddonPeriodRate: number;
  maxAddonPeriodRate: number;

  [key: string]: number; // Index signature
}

interface BorrowerConfig {
  expiration: number;
  minDurationInPeriods: number;
  maxDurationInPeriods: number;
  minBorrowAmount: number;
  maxBorrowAmount: number;
  borrowPolicy: BorrowPolicy;
  interestRatePrimary: number;
  interestRateSecondary: number;
  addonFixedRate: number;
  addonPeriodRate: number;

  [key: string]: number | BorrowPolicy; // Index signature
}

const testScenarioDefault: TestScenario = {
  borrowAmount: 0,
  durationInPeriods: 180,
  interestRatePrimary: 0,
  interestRateSecondary: 0,
  iterationStep: 30,
  relativePrecision: 1e-7, // 0.00001% difference
  repaymentAmounts: [],
  expectedOutstandingBalancesBeforeRepayment: [],
  frozenStepIndexes: [],
  finalAction: ScenarioFinalAction.None
};

const testScenarioContextDefault: TestScenarioContext = {
  scenario: testScenarioDefault,
  stepIndex: 0,
  loanId: 0n,
  loanTakingPeriod: 0,
  frozenStepIndexes: new Set(),
  frozenState: false,
  poolBalanceAtStart: 0n,
  poolBalanceAtFinish: 0n,
  totalRepaymentAmount: 0
};

function calculateLoanPeriodIndex(timestamp: number): number {
  return Math.floor((timestamp - NEGATIVE_TIME_OFFSET) / PERIOD_IN_SECONDS);
}

function calculateTimestampByLoanPeriodIndex(periodIndex: number): number {
  return Math.floor(periodIndex * PERIOD_IN_SECONDS + NEGATIVE_TIME_OFFSET);
}

describe("Contract 'LendingMarket': complex tests", async () => {
  let fixture: Fixture;

  let owner: HardhatEthersSigner;
  let lender: HardhatEthersSigner;
  let admin: HardhatEthersSigner;
  let borrower: HardhatEthersSigner;

  before(async () => {
    [owner, lender, admin, borrower] = await ethers.getSigners();

    fixture = await deployContracts();
    await configureContracts(fixture);

    // Start tests at the beginning of a loan period to avoid rare failures due to crossing a border between two periods
    const periodIndex = calculateLoanPeriodIndex(await getLatestBlockTimestamp());
    const nextPeriodTimestamp = calculateTimestampByLoanPeriodIndex(periodIndex + 1);
    await increaseBlockTimestampTo(nextPeriodTimestamp);
  });

  async function deployContracts(): Promise<Fixture> {
    // Factories with an explicitly specified deployer account
    let tokenFactory: ContractFactory = await ethers.getContractFactory("ERC20Mock");
    tokenFactory = tokenFactory.connect(owner);
    let lendingMarketFactory: ContractFactory = await ethers.getContractFactory("LendingMarketUUPS");
    lendingMarketFactory = lendingMarketFactory.connect(owner);
    let creditLineFactory: ContractFactory = await ethers.getContractFactory("CreditLineConfigurableUUPS");
    creditLineFactory = creditLineFactory.connect(owner);
    let liquidityPoolFactory: ContractFactory = await ethers.getContractFactory("LiquidityPoolAccountableUUPS");
    liquidityPoolFactory = liquidityPoolFactory.connect(owner);

    // Deploy the token contract
    let token: Contract = (await tokenFactory.deploy()) as Contract;
    await token.waitForDeployment();
    token = connect(token, owner); // Explicitly specifying the initial account
    const tokenAddress = getAddress(token);

    // Deploy the lending market contract
    let lendingMarket: Contract = await upgrades.deployProxy(lendingMarketFactory, [lender.address]);
    await lendingMarket.waitForDeployment();
    lendingMarket = connect(lendingMarket, lender); // Explicitly specifying the initial account
    const lendingMarketAddress = getAddress(lendingMarket);

    // Deploy the credit line contract
    let creditLine: Contract = await upgrades.deployProxy(
      creditLineFactory,
      [lender.address, lendingMarketAddress, tokenAddress]
    );
    await creditLine.waitForDeployment();
    creditLine = connect(creditLine, lender); // Explicitly specifying the initial account
    const creditLineAddress = getAddress(creditLine);

    // Deploy the liquidity pool contract
    let liquidityPool: Contract = await upgrades.deployProxy(liquidityPoolFactory, [
      lender.address,
      lendingMarketAddress,
      tokenAddress,
      ZERO_ADDRESS // addonTreasury
    ]);
    await liquidityPool.waitForDeployment();
    liquidityPool = connect(liquidityPool, lender); // Explicitly specifying the initial account
    const liquidityPoolAddress = getAddress(liquidityPool);

    return {
      lendingMarketFactory,
      creditLineFactory,
      liquidityPoolFactory,
      tokenFactory,

      token,
      lendingMarket,
      creditLine,
      liquidityPool,

      tokenAddress,
      lendingMarketAddress,
      creditLineAddress,
      liquidityPoolAddress
    };
  }

  async function configureContracts(fixture: Fixture) {
    const { token, lendingMarket, creditLine, lendingMarketAddress, liquidityPoolAddress, creditLineAddress } = fixture;
    // Allowance
    await proveTx(connect(token, lender).approve(liquidityPoolAddress, ethers.MaxUint256));
    await proveTx(connect(token, borrower).approve(lendingMarketAddress, ethers.MaxUint256));

    // Configure contracts and create a lending program
    await proveTx(creditLine.grantRole(ADMIN_ROLE, admin.address));
    await proveTx(lendingMarket.registerCreditLine(creditLineAddress));
    await proveTx(lendingMarket.registerLiquidityPool(liquidityPoolAddress));
    await proveTx(lendingMarket.createProgram(creditLineAddress, liquidityPoolAddress));
  }

  async function runScenario(scenario: TestScenario) {
    const context: TestScenarioContext = { ...testScenarioContextDefault, scenario, fixture };
    const { token, lendingMarket, liquidityPoolAddress } = context.fixture as Fixture;
    await prepareContractsForScenario(context);
    await manageLoansForScenario(context);
    context.poolBalanceAtStart = await token.balanceOf(liquidityPoolAddress);
    context.frozenStepIndexes = new Set(scenario.frozenStepIndexes);
    context.totalRepaymentAmount = scenario.repaymentAmounts.reduce((sum, amount) => sum + amount);

    for (let i = 0; i < scenario.repaymentAmounts.length; i++) {
      context.stepIndex = i;
      await manageLoanFreezingForScenario(context);
      await manageBlockTimestampForScenario(context);
      const loanPreviewBefore = await lendingMarket.getLoanPreview(context.loanId, 0);
      await repayLoanIfNeededForScenario(context);
      await checkLoanRepaymentForScenario(loanPreviewBefore, context);
    }
    await checkFinalPoolBalanceForScenario(context);
    await checkLoanRepaidAmountForScenario(context);
    await executeFinalActionIfNeededForScenario(context);
  }

  async function prepareContractsForScenario(context: TestScenarioContext) {
    const { token, liquidityPool, creditLine } = context.fixture as Fixture;
    const scenario = context.scenario;

    // Mint token
    await proveTx(token.mint(lender.address, scenario.borrowAmount));
    await proveTx(token.mint(borrower.address, scenario.borrowAmount * 10));

    // Configure liquidity pool and credit line
    await proveTx(liquidityPool.deposit(scenario.borrowAmount));
    const creditLineConfig: CreditLineConfig = createCreditLineConfig(scenario);
    await proveTx(creditLine.configureCreditLine(creditLineConfig));

    // Configure borrower
    const borrowerConfig: BorrowerConfig = createBorrowerConfig(scenario);
    await proveTx(connect(creditLine, admin).configureBorrower(borrower.address, borrowerConfig));
  }

  function createCreditLineConfig(scenario: TestScenario): CreditLineConfig {
    return {
      minDurationInPeriods: scenario.durationInPeriods,
      maxDurationInPeriods: scenario.durationInPeriods,
      minBorrowAmount: scenario.borrowAmount,
      maxBorrowAmount: scenario.borrowAmount,
      minInterestRatePrimary: scenario.interestRatePrimary,
      maxInterestRatePrimary: scenario.interestRatePrimary,
      minInterestRateSecondary: scenario.interestRateSecondary,
      maxInterestRateSecondary: scenario.interestRateSecondary,
      minAddonFixedRate: 0,
      maxAddonFixedRate: 0,
      minAddonPeriodRate: 0,
      maxAddonPeriodRate: 0
    };
  }

  function createBorrowerConfig(scenario: TestScenario): BorrowerConfig {
    return {
      minBorrowAmount: scenario.borrowAmount,
      maxBorrowAmount: scenario.borrowAmount,
      minDurationInPeriods: scenario.durationInPeriods,
      maxDurationInPeriods: scenario.durationInPeriods,
      interestRatePrimary: scenario.interestRatePrimary,
      interestRateSecondary: scenario.interestRateSecondary,
      addonFixedRate: 0,
      addonPeriodRate: 0,
      borrowPolicy: BorrowPolicy.TotalActiveAmountLimit,
      expiration: 2 ** 32 - 1
    };
  }

  async function isLoanClosed(lendingMarket: Contract, loanId: bigint): Promise<boolean> {
    const trackedBalance = (await lendingMarket.getLoanState(loanId)).trackedBalance;
    if (trackedBalance === undefined) {
      throw new Error("The 'trackedBalance' field does not exist in the loan state structure");
    }
    if (typeof trackedBalance !== "bigint") {
      throw new Error("The 'trackedBalance' field of the loan state structure has wrong type");
    }
    return trackedBalance === 0n;
  }

  async function manageLoansForScenario(context: TestScenarioContext) {
    const scenario: TestScenario = context.scenario;
    const { lendingMarket } = context.fixture as Fixture;

    // Close a previous loan if it is not closed already
    const loanCounter = await lendingMarket.loanCounter();
    if (loanCounter > 0) {
      const previousLoanId = loanCounter - 1n;
      if (!(await isLoanClosed(lendingMarket, previousLoanId))) {
        await proveTx(lendingMarket.revokeLoan(previousLoanId));
      }
    }

    context.loanId = loanCounter;

    const tx: Promise<TransactionResponse> = lendingMarket.takeLoanFor(
      borrower.address,
      PROGRAM_ID,
      scenario.borrowAmount,
      ADDON_AMOUNT,
      scenario.durationInPeriods
    );

    const txReceipt = await proveTx(tx);
    context.loanTakingPeriod = calculateLoanPeriodIndex(await getBlockTimestamp(txReceipt.blockNumber));
  }

  async function manageLoanFreezingForScenario(context: TestScenarioContext) {
    const { lendingMarket } = context.fixture as Fixture;
    if (context.frozenStepIndexes.has(context.stepIndex)) {
      if (!context.frozenState) {
        await proveTx(lendingMarket.freeze(context.loanId));
        context.frozenState = true;
      }
    } else if (context.frozenState) {
      await proveTx(lendingMarket.unfreeze(context.loanId));
      context.frozenState = false;
    }
  }

  async function manageBlockTimestampForScenario(context: TestScenarioContext) {
    const targetLoanPeriod = context.loanTakingPeriod + (context.stepIndex + 1) * context.scenario.iterationStep;
    const targetTimestamp = calculateTimestampByLoanPeriodIndex(targetLoanPeriod);
    await increaseBlockTimestampTo(targetTimestamp);
  }

  async function repayLoanIfNeededForScenario(context: TestScenarioContext) {
    const { lendingMarket } = context.fixture as Fixture;
    const repaymentAmount = context.scenario.repaymentAmounts[context.stepIndex] ?? 0;
    if (repaymentAmount != 0) {
      await proveTx(connect(lendingMarket, borrower).repayLoan(context.loanId, repaymentAmount));
    }
  }

  async function checkLoanRepaymentForScenario(
    loanPreviewBefore: Record<string, bigint>,
    context: TestScenarioContext
  ) {
    const { lendingMarket } = context.fixture as Fixture;
    const loanPreviewAfter = await lendingMarket.getLoanPreview(context.loanId, 0);

    const scenario = context.scenario;
    const actualBalanceBefore = Number(loanPreviewBefore.outstandingBalance);
    const actualBalanceAfter = Number(loanPreviewAfter.outstandingBalance);
    const expectedBalanceBefore = scenario.expectedOutstandingBalancesBeforeRepayment[context.stepIndex] ?? 0;
    const repaymentAmount = scenario.repaymentAmounts[context.stepIndex] ?? 0;
    const expectedBalanceAfter = actualBalanceBefore - repaymentAmount;
    const differenceBefore = actualBalanceBefore - expectedBalanceBefore;
    const differenceAfter = actualBalanceAfter - expectedBalanceAfter;
    const actualRelativePrecision = Math.abs(differenceBefore / expectedBalanceBefore);
    const errorMessageBefore = `Balances mismatch before a repayment (` +
      `loan repayment index: ${context.stepIndex}; actual balance before: ${actualBalanceBefore}; ` +
      `expected balance before: ${expectedBalanceBefore}; difference: ${differenceBefore})`;
    const errorMessageAfter = `Balances mismatch after a repayment (` +
      `loan repayment index: ${context.stepIndex}; actual balance after: ${actualBalanceAfter}; ` +
      `expected balance after: ${expectedBalanceAfter}; difference: ${differenceAfter})`;

    expect(actualRelativePrecision).to.lessThanOrEqual(scenario.relativePrecision, errorMessageBefore);
    expect(actualBalanceAfter).to.eq(expectedBalanceAfter, errorMessageAfter);
  }

  async function checkFinalPoolBalanceForScenario(context: TestScenarioContext) {
    const { token, liquidityPoolAddress } = context.fixture as Fixture;
    context.poolBalanceAtFinish = await token.balanceOf(liquidityPoolAddress);
    expect(context.poolBalanceAtFinish - context.poolBalanceAtStart).to.eq(context.totalRepaymentAmount);
  }

  async function checkLoanRepaidAmountForScenario(context: TestScenarioContext) {
    const { lendingMarket } = context.fixture as Fixture;
    const loanState = await lendingMarket.getLoanState(context.loanId);
    expect(loanState.repaidAmount).to.eq(context.totalRepaymentAmount);
  }

  async function executeFinalActionIfNeededForScenario(context: TestScenarioContext) {
    switch (context.scenario.finalAction) {
      case ScenarioFinalAction.FullRepayment: {
        await executeAndCheckFullLoanRepaymentForScenario(context);
        break;
      }
      case ScenarioFinalAction.Revocation: {
        await executeAndCheckLoanRevocationForScenario(context);
        break;
      }
      case ScenarioFinalAction.RepaymentCheck: {
        const { lendingMarket } = context.fixture as Fixture;
        await checkLoanClosedState(lendingMarket, context.loanId);
        break;
      }
      default: {
        // do nothing
      }
    }
  }

  async function executeAndCheckFullLoanRepaymentForScenario(context: TestScenarioContext) {
    const { token, lendingMarket, liquidityPool } = context.fixture as Fixture;
    const outstandingBalance = (await lendingMarket.getLoanPreview(context.loanId, 0)).outstandingBalance;
    await expect(
      connect(lendingMarket, borrower).repayLoan(context.loanId, ethers.MaxUint256)
    ).changeTokenBalances(
      token,
      [lendingMarket, liquidityPool, borrower],
      [0, outstandingBalance, -outstandingBalance]
    );
    await checkLoanClosedState(lendingMarket, context.loanId);
  }

  async function executeAndCheckLoanRevocationForScenario(context: TestScenarioContext) {
    const { token, lendingMarket, liquidityPool } = context.fixture as Fixture;
    const loanState = await lendingMarket.getLoanState(context.loanId);
    const repaidAmount = loanState.repaidAmount - loanState.borrowAmount;
    await expect(
      lendingMarket.revokeLoan(context.loanId)
    ).to.changeTokenBalances(
      token,
      [lendingMarket, liquidityPool, borrower],
      [0, -repaidAmount, repaidAmount]
    );
    await checkLoanRepaidAmountForScenario(context);
    await checkLoanClosedState(lendingMarket, context.loanId);
  }

  async function checkLoanClosedState(lendingMarket: Contract, loanId: bigint) {
    const loanState = await lendingMarket.getLoanState(loanId);
    const loanPreview = await lendingMarket.getLoanPreview(loanId, 0);
    expect(loanState.trackedBalance).to.eq(0);
    expect(loanPreview.trackedBalance).to.eq(0);
    expect(loanPreview.outstandingBalance).to.eq(0);
  }

  describe("Complex scenarios", async () => {
    it("Scenario 1: a typical loan with short freezing after defaulting and full repayment at the end", async () => {
      const borrowAmount = 1e9; // 1000 BRLC
      const interestRatePrimary = 2_724_943; // 170 % annual
      const interestRateSecondary = 4_067440; // 340 % annual

      const repaymentAmounts: number[] = Array(12).fill(170_000_000); // 170 BRLC
      repaymentAmounts[2] = 0;
      repaymentAmounts[3] = 0;

      const frozenStepIndexes: number[] = [8, 9];

      const expectedOutstandingBalancesBeforeRepayment: number[] = [
        /* eslint-disable @stylistic/array-element-newline*/
        // The numbers below are taken form spreadsheet:
        // https://docs.google.com/spreadsheets/d/148elvx9Yd0QuaDtc7AkaelIn3t5rvZCx5iG2ceVfpe8
        1085060000, 992900000, 892900000, 968850000, 1051260000, 956220000,
        888040000, 811020000, 641020000, 471020000, 340010000, 192020000
        /* eslint-enable @stylistic/array-element-newline*/
      ];

      const scenario: TestScenario = {
        ...testScenarioDefault,
        borrowAmount,
        interestRatePrimary,
        interestRateSecondary,
        repaymentAmounts,
        expectedOutstandingBalancesBeforeRepayment,
        frozenStepIndexes,
        finalAction: ScenarioFinalAction.FullRepayment
      };
      await runScenario(scenario);
    });

    it("Scenario 2: a typical loan with short freezing and repayments only after defaulting", async () => {
      const borrowAmount = 1e9; // 1000 BRLC
      const interestRatePrimary = 2_724_943; // 170 % annual
      const interestRateSecondary = 4_067440; // 340 % annual

      const repaymentAmounts: number[] = Array(12).fill(0); // 0 BRLC
      repaymentAmounts[10] = 1500_000_000; // 1500 BRLC
      repaymentAmounts[11] = 962_030_000; // 962.03 BRLC

      const frozenStepIndexes: number[] = [2, 3];

      const expectedOutstandingBalancesBeforeRepayment: number[] = [
        /* eslint-disable @stylistic/array-element-newline*/
        // The numbers below are taken form spreadsheet:
        // https://docs.google.com/spreadsheets/d/148elvx9Yd0QuaDtc7AkaelIn3t5rvZCx5iG2ceVfpe8
        1085060000, 1177360000, 1177360000, 1177360000, 1277510000, 1386180000,
        1504090000, 1632030000, 1843380000, 2082090000, 2351730000, 962030000
        /* eslint-enable @stylistic/array-element-newline*/
      ];

      const scenario: TestScenario = {
        ...testScenarioDefault,
        borrowAmount,
        interestRatePrimary,
        interestRateSecondary,
        repaymentAmounts,
        expectedOutstandingBalancesBeforeRepayment,
        frozenStepIndexes,
        finalAction: ScenarioFinalAction.RepaymentCheck
      };
      await runScenario(scenario);
    });

    it("Scenario 3: a big loan with big rates, lots of small repayments and revocation at the end", async () => {
      const borrowAmount = 1e12; // 1000_000 BRLC
      const interestRatePrimary = 4_219_472; // 365 % annual
      const interestRateSecondary = 5_814_801; // 730 % annual

      const repaymentAmounts: number[] = Array(24).fill(100_000_000); // 100 BRLC

      const frozenStepIndexes: number[] = [];

      const expectedOutstandingBalancesBeforeRepayment: number[] = [
        /* eslint-disable @stylistic/array-element-newline*/
        // The numbers below are taken form spreadsheet:
        // https://docs.google.com/spreadsheets/d/148elvx9Yd0QuaDtc7AkaelIn3t5rvZCx5iG2ceVfpe8
        1134642760000, 1287300730000, 1460512990000, 1657047030000, 1880042950000, 2133063660000,
        2538189960000, 3020283270000, 3593965980000, 4276638520000, 5089007060000, 6055711610000,
        7206073340000, 8574983950000, 10203963970000, 12142422090000, 14449153800000, 17194124750000,
        20460592820000, 24347633470000, 28973144780000, 34477423440000, 41027420090000, 48821803090000
        /* eslint-enable @stylistic/array-element-newline*/
      ];

      const scenario: TestScenario = {
        ...testScenarioDefault,
        borrowAmount,
        interestRatePrimary,
        interestRateSecondary,
        repaymentAmounts,
        expectedOutstandingBalancesBeforeRepayment,
        frozenStepIndexes,
        finalAction: ScenarioFinalAction.Revocation
      };
      await runScenario(scenario);
    });

    it("Scenario 4: a small loan with low rates, lots of repayments leading to the full repayment", async () => {
      const borrowAmount = 1e6; // 1 BRLC
      const interestRatePrimary = 261_157; // 10 % annual
      const interestRateSecondary = 499_635; // 20 % annual

      const repaymentAmounts: number[] = Array(12).fill(90_000); // 0.09 BRLC
      repaymentAmounts[repaymentAmounts.length - 1] = 70_000; // 0.07 BRLC

      const frozenStepIndexes: number[] = [];

      const expectedOutstandingBalancesBeforeRepayment: number[] = [
        /* eslint-disable @stylistic/array-element-newline*/
        // The numbers below are taken form spreadsheet:
        // https://docs.google.com/spreadsheets/d/148elvx9Yd0QuaDtc7AkaelIn3t5rvZCx5iG2ceVfpe8
        1010000, 930000, 840000, 760000, 670000, 590000,
        500000, 420000, 340000, 250000, 160000, 70000
        /* eslint-enable @stylistic/array-element-newline*/
      ];

      const scenario: TestScenario = {
        ...testScenarioDefault,
        borrowAmount,
        interestRatePrimary,
        interestRateSecondary,
        repaymentAmounts,
        expectedOutstandingBalancesBeforeRepayment,
        frozenStepIndexes,
        finalAction: ScenarioFinalAction.RepaymentCheck
      };
      await runScenario(scenario);
    });
  });
});
