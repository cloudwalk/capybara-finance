import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { proveTx } from "../../../test-utils/eth";

interface CreditLineConfig {
  treasury: string;
  periodInSeconds: number;
  minDurationInPeriods: number;
  maxDurationInPeriods: number;
  minBorrowAmount: number;
  maxBorrowAmount: number;
  minInterestRatePrimary: number;
  maxInterestRatePrimary: number;
  minInterestRateSecondary: number;
  maxInterestRateSecondary: number;
  interestRateFactor: number;
  addonRecipient: string;
  minAddonFixedRate: number;
  maxAddonFixedRate: number;
  minAddonPeriodRate: number;
  maxAddonPeriodRate: number;

  [key: string]: string | number;  // Index signature
}

interface BorrowerConfig {
  minBorrowAmount: number;
  maxBorrowAmount: number;
  minDurationInPeriods: number;
  maxDurationInPeriods: number;
  interestRatePrimary: number;
  interestRateSecondary: number;
  addonFixedRate: number;
  addonPeriodRate: number;
  interestFormula: InterestFormula;
  borrowPolicy: BorrowPolicy;
  autoRepayment: boolean;
  expiration: number;

  [key: string]: string | number | InterestFormula | BorrowPolicy | boolean; // Index signature
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

  [key: string]: string | number | boolean | InterestFormula;  // Index signature
}

enum InterestFormula {
  // Simple = 0 -- this value is not used in tests
  Compound = 1
}

enum BorrowPolicy {
  Reset = 0,
  Decrease = 1,
  Keep = 2
}

const ERROR_NAME_ALREADY_INITIALIZED = "InvalidInitialization";
const ERROR_NAME_ALREADY_CONFIGURED = "AlreadyConfigured";
const ERROR_NAME_ARRAYS_LENGTH_MISMATCH = "ArrayLengthMismatch";
const ERROR_NAME_BORROWER_CONFIGURATION_EXPIRED = "BorrowerConfigurationExpired";
const ERROR_NAME_ENFORCED_PAUSED = "EnforcedPause";
const ERROR_NAME_INVALID_AMOUNT = "InvalidAmount";
const ERROR_NAME_INVALID_BORROWER_CONFIGURATION = "InvalidBorrowerConfiguration";
const ERROR_NAME_INVALID_CREDIT_LINE_CONFIGURATION = "InvalidCreditLineConfiguration";
const ERROR_NAME_LOAN_DURATION_OUT_OF_RANGE = "LoanDurationOutOfRange";
const ERROR_NAME_NOT_PAUSED = "ExpectedPause";
const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";
const ERROR_NAME_UNAUTHORIZED = "Unauthorized";
const ERROR_NAME_ZERO_ADDRESS = "ZeroAddress";

const EVENT_NAME_ADMIN_CONFIGURED = "AdminConfigured";
const EVENT_NAME_BORROWER_CONFIGURED = "BorrowerConfigured";
const EVENT_NAME_CREDIT_LINE_CONFIGURED = "CreditLineConfigured";
const EVENT_NAME_PAUSED = "Paused";
const EVENT_NAME_UNPAUSED = "Unpaused";

const ZERO_ADDRESS = ethers.ZeroAddress;
const CREDIT_LINE_KIND = 1;
const DEFAULT_PERIOD_IN_SECONDS = 86400;
const DEFAULT_MIN_DURATION_IN_PERIODS = 7;
const DEFAULT_MAX_DURATION_IN_PERIODS = 14;
const DEFAULT_MIN_BORROW_AMOUNT = 100;
const DEFAULT_MAX_BORROW_AMOUNT = 1000;
const DEFAULT_MIN_INTEREST_RATE_PRIMARY = 1;
const DEFAULT_MAX_INTEREST_RATE_PRIMARY = 10;
const DEFAULT_MIN_INTEREST_RATE_SECONDARY = 10;
const DEFAULT_MAX_INTEREST_RATE_SECONDARY = 20;
const DEFAULT_INTEREST_RATE_FACTOR = 1000;
const DEFAULT_MIN_ADDON_FIXED_RATE = 1;
const DEFAULT_MAX_ADDON_FIXED_RATE = 10;
const DEFAULT_MIN_ADDON_PERIOD_RATE = 1;
const DEFAULT_MAX_ADDON_PERIOD_RATE = 10;
const DEFAULT_EXPIRATION_TIME = 4294967295;
const BORROWERS_NUMBER = 3;

describe("Contract 'CreditLineConfigurable'", async () => {
  let creditLineFactory: ContractFactory;

  let deployer: HardhatEthersSigner;
  let lender: HardhatEthersSigner;
  let market: HardhatEthersSigner;
  let token: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;
  let treasury: HardhatEthersSigner;
  let addonRecipient: HardhatEthersSigner;
  let borrower: HardhatEthersSigner;
  let users: HardhatEthersSigner[];

  before(async () => {
    [deployer, lender, market, token, attacker, treasury, addonRecipient, borrower, ...users]
      = await ethers.getSigners();

    creditLineFactory = await ethers.getContractFactory("CreditLineConfigurable");
    creditLineFactory.connect(deployer); // Explicitly specifying the deployer account
  });

  function createDefaultCreditLineConfiguration(): CreditLineConfig {
    return {
      treasury: treasury.address,
      periodInSeconds: DEFAULT_PERIOD_IN_SECONDS,
      minDurationInPeriods: DEFAULT_MIN_DURATION_IN_PERIODS,
      maxDurationInPeriods: DEFAULT_MAX_DURATION_IN_PERIODS,
      minBorrowAmount: DEFAULT_MIN_BORROW_AMOUNT,
      maxBorrowAmount: DEFAULT_MAX_BORROW_AMOUNT,
      minInterestRatePrimary: DEFAULT_MIN_INTEREST_RATE_PRIMARY,
      maxInterestRatePrimary: DEFAULT_MAX_INTEREST_RATE_PRIMARY,
      minInterestRateSecondary: DEFAULT_MIN_INTEREST_RATE_SECONDARY,
      maxInterestRateSecondary: DEFAULT_MAX_INTEREST_RATE_SECONDARY,
      interestRateFactor: DEFAULT_INTEREST_RATE_FACTOR,
      addonRecipient: addonRecipient.address,
      minAddonFixedRate: DEFAULT_MIN_ADDON_FIXED_RATE,
      maxAddonFixedRate: DEFAULT_MAX_ADDON_FIXED_RATE,
      minAddonPeriodRate: DEFAULT_MIN_ADDON_PERIOD_RATE,
      maxAddonPeriodRate: DEFAULT_MAX_ADDON_PERIOD_RATE
    };
  }

  function createDefaultBorrowerConfiguration(): BorrowerConfig {
    return {
      minBorrowAmount: DEFAULT_MIN_BORROW_AMOUNT,
      maxBorrowAmount: DEFAULT_MAX_BORROW_AMOUNT,
      minDurationInPeriods: DEFAULT_MIN_DURATION_IN_PERIODS,
      maxDurationInPeriods: DEFAULT_MAX_DURATION_IN_PERIODS,
      interestRatePrimary: DEFAULT_MIN_INTEREST_RATE_PRIMARY,
      interestRateSecondary: DEFAULT_MIN_INTEREST_RATE_SECONDARY,
      addonFixedRate: DEFAULT_MIN_ADDON_FIXED_RATE,
      addonPeriodRate: DEFAULT_MIN_ADDON_PERIOD_RATE,
      interestFormula: InterestFormula.Compound,
      borrowPolicy: BorrowPolicy.Keep,
      autoRepayment: true,
      expiration: DEFAULT_EXPIRATION_TIME
    };
  }

  function createLoanTerms(
    borrowAmount: number,
    durationInPeriods: number,
    creditLineConfig: CreditLineConfig,
    borrowerConfig: BorrowerConfig
  ): LoanTerms {
    let addonAmount = 0;
    if (creditLineConfig.addonRecipient !== ZERO_ADDRESS) {
      addonAmount = calculateAddonAmount(
        borrowAmount,
        durationInPeriods,
        borrowerConfig.addonFixedRate,
        borrowerConfig.addonPeriodRate,
        creditLineConfig.interestRateFactor
      );
    }
    return {
      token: token.address,
      interestRatePrimary: borrowerConfig.interestRatePrimary,
      interestRateSecondary: borrowerConfig.interestRateSecondary,
      interestRateFactor: DEFAULT_INTEREST_RATE_FACTOR,
      treasury: treasury.address,
      periodInSeconds: DEFAULT_PERIOD_IN_SECONDS,
      durationInPeriods,
      interestFormula: borrowerConfig.interestFormula,
      autoRepayment: borrowerConfig.autoRepayment,
      addonRecipient: creditLineConfig.addonRecipient,
      addonAmount: addonAmount
    };
  }

  function calculateAddonAmount(
    borrowAmount: number,
    durationInPeriods: number,
    addonFixedRate: number,
    addonPeriodRate: number,
    interestRateFactor: number
  ): number {
    const addonRate = addonPeriodRate * durationInPeriods + addonFixedRate;
    return Math.floor((borrowAmount * addonRate) / (interestRateFactor - addonRate));
  }

  function compareCreditLineConfigs(actualConfig: CreditLineConfig, expectedConfig: CreditLineConfig) {
    Object.keys(expectedConfig).forEach(property => {
      expect(actualConfig[property]).to.eq(
        expectedConfig[property],
        `Mismatch in the "${property}" property of the credit line config`
      );
    });
  }

  function compareBorrowerConfigs(actualConfig: BorrowerConfig, expectedConfig: BorrowerConfig) {
    Object.keys(expectedConfig).forEach(property => {
      expect(actualConfig[property]).to.eq(
        expectedConfig[property],
        `Mismatch in the "${property}" property of the borrower config`
      );
    });
  }

  function compareLoanTerms(actualTerms: LoanTerms, expectedTerms: LoanTerms) {
    Object.keys(expectedTerms).forEach(property => {
      expect(actualTerms[property]).to.eq(
        expectedTerms[property],
        `Mismatch in the "${property}" property of the loan terms`
      );
    });
  }

  async function prepareDataForBatchBorrowerConfig(borrowersNumber: number): Promise<{
    borrowers: string[],
    configs: BorrowerConfig[]
  }> {
    const config = createDefaultBorrowerConfiguration();
    if (borrowersNumber > users.length) {
      throw new Error(
        "The number of borrowers is greater than the number of free accounts in the Hardhat settings. " +
        `Requested number of borrowers: ${borrowersNumber}. ` +
        `The number of free accounts: ${users.length}`
      );
    }

    const borrowers = users.slice(0, borrowersNumber).map(user => user.address);
    const configs: BorrowerConfig[] = Array(borrowersNumber).fill(config); // Same ref to config for each borrower

    return {
      borrowers,
      configs
    };
  }

  async function deployCreditLine(): Promise<{ creditLine: Contract }> {
    let creditLine = await upgrades.deployProxy(creditLineFactory, [
      market.address,
      lender.address,
      token.address,
    ]);
    await creditLine.waitForDeployment();
    creditLine = creditLine.connect(lender) as Contract; // Explicitly specifying the initial account

    return { creditLine };
  }

  async function deployAndConfigureCreditLine(): Promise<{ creditLine: Contract }> {
    const { creditLine } = await deployCreditLine();

    await proveTx(creditLine.configureAdmin(lender.address, true));

    const creditLineConfig = createDefaultCreditLineConfiguration();
    await proveTx(creditLine.configureCreditLine(creditLineConfig));

    return { creditLine };
  }

  async function deployAndConfigureCreditLineWithBorrower(): Promise<{ creditLine: Contract }> {
    const { creditLine } = await deployAndConfigureCreditLine();

    const borrowerConfig = createDefaultBorrowerConfiguration();
    await proveTx(creditLine.configureBorrower(borrower.address, borrowerConfig));

    return { creditLine };
  }

  describe("Function 'initialize()'", async () => {
    it("Configures the contract as expected", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      expect(await creditLine.lender()).to.eq(lender.address);
      expect(await creditLine.owner()).to.eq(lender.address);
      expect(await creditLine.token()).to.eq(token.address);
      expect(await creditLine.market()).to.eq(market.address);
      expect(await creditLine.kind()).to.eq(CREDIT_LINE_KIND);
      expect(await creditLine.paused()).to.eq(false);
    });

    it("Is reverted if the market address is zero", async () => {
      await expect(upgrades.deployProxy(creditLineFactory, [
        ZERO_ADDRESS, // market
        lender.address,
        token.address
      ])).to.be.revertedWithCustomError(creditLineFactory, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if the token address is zero", async () => {
      await expect(upgrades.deployProxy(creditLineFactory, [
        market.address,
        lender.address,
        ZERO_ADDRESS // token
      ])).to.be.revertedWithCustomError(creditLineFactory, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if called a second time", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await expect(creditLine.initialize(market.address, lender.address, token.address))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_ALREADY_INITIALIZED);
    });
  });

  describe("Function 'pause()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await expect(creditLine.pause())
        .to.emit(creditLine, EVENT_NAME_PAUSED)
        .withArgs(lender.address);
      expect(await creditLine.paused()).to.eq(true);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await expect((creditLine.connect(attacker) as Contract).pause())
        .to.be.revertedWithCustomError(creditLineFactory, ERROR_NAME_OWNABLE_UNAUTHORIZED)
        .withArgs(attacker.address);
    });

    it("Is reverted if the contract is already paused", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await proveTx(creditLine.pause());
      await expect(creditLine.pause())
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_ENFORCED_PAUSED);
    });
  });

  describe("Function 'unpause()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await proveTx(creditLine.pause());
      expect(await creditLine.paused()).to.eq(true);

      await expect(creditLine.unpause())
        .to.emit(creditLine, EVENT_NAME_UNPAUSED)
        .withArgs(lender.address);

      expect(await creditLine.paused()).to.eq(false);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await expect((creditLine.connect(attacker) as Contract).unpause())
        .to.be.revertedWithCustomError(creditLineFactory, ERROR_NAME_OWNABLE_UNAUTHORIZED)
        .withArgs(attacker.address);
    });

    it("Is reverted if the contract is not paused yet", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await expect(creditLine.unpause())
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_NOT_PAUSED);
    });
  });

  describe("Function 'configureAdmin()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      expect(await creditLine.isAdmin(users[0].address)).to.eq(false);

      expect(await creditLine.configureAdmin(users[0].address, true))
        .to.emit(creditLine, EVENT_NAME_ADMIN_CONFIGURED)
        .withArgs(users[0].address, true);

      expect(await creditLine.isAdmin(users[0].address)).to.eq(true);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await expect((creditLine.connect(attacker) as Contract).configureAdmin(attacker.address, true))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_OWNABLE_UNAUTHORIZED)
        .withArgs(attacker.address);
    });

    it("Is reverted if the account address is zero", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await expect(creditLine.configureAdmin(
        ZERO_ADDRESS, // account
        true // isAdmin
      )).to.be.revertedWithCustomError(creditLine, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if the admin is already configured", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await proveTx(creditLine.configureAdmin(users[0].address, true));

      await expect(creditLine.configureAdmin(users[0].address, true))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_ALREADY_CONFIGURED);
    });
  });

  describe("Function 'configureCreditLine()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      await expect(creditLine.configureCreditLine(config))
        .to.emit(creditLine, EVENT_NAME_CREDIT_LINE_CONFIGURED)
        .withArgs(await creditLine.getAddress());

      const onChainConfig: CreditLineConfig = await creditLine.creditLineConfiguration();

      compareCreditLineConfigs(onChainConfig, config);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      await expect((creditLine.connect(attacker) as Contract).configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_OWNABLE_UNAUTHORIZED)
        .withArgs(attacker.address);
    });

    it("Is reverted if the loan period is zero", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      config.periodInSeconds = 0;

      await expect(creditLine.configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_CREDIT_LINE_CONFIGURATION);
    });

    it("Is reverted if the interest rate factor is zero", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      config.interestRateFactor = 0;

      await expect(creditLine.configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_CREDIT_LINE_CONFIGURATION);
    });

    it("Is reverted if the min borrow amount is bigger than the max one", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      config.minBorrowAmount = config.maxBorrowAmount + 1;

      await expect(creditLine.configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_CREDIT_LINE_CONFIGURATION);
    });

    it("Is reverted if the min loan duration is bigger than the max one", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      config.minDurationInPeriods = config.maxDurationInPeriods + 1;

      await expect(creditLine.configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_CREDIT_LINE_CONFIGURATION);
    });

    it("Is reverted if the min primary interest rate is bigger than the max one", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      config.minInterestRatePrimary = config.maxInterestRatePrimary + 1;

      await expect(creditLine.configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_CREDIT_LINE_CONFIGURATION);
    });

    it("Is reverted if the min secondary interest rate is bigger than the max one", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      config.minInterestRateSecondary = config.maxInterestRateSecondary + 1;

      await expect(creditLine.configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_CREDIT_LINE_CONFIGURATION);
    });

    it("Is reverted if the min addon fixed rate is bigger than the max one", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      config.minAddonFixedRate = config.maxAddonFixedRate + 1;

      await expect(creditLine.configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_CREDIT_LINE_CONFIGURATION);
    });

    it("Is reverted if the min addon period rate is bigger than the max one", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      config.minAddonPeriodRate = config.maxAddonPeriodRate + 1;

      await expect(creditLine.configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_CREDIT_LINE_CONFIGURATION);
    });
  });

  describe("Function 'configureBorrower()'", async () => {
    it("Executes as expected and emits the correct event if is called by the lender", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      await expect(creditLine.configureBorrower(borrower.address, config))
        .to.emit(creditLine, EVENT_NAME_BORROWER_CONFIGURED)
        .withArgs(await creditLine.getAddress(), borrower.address);

      const onChainConfig: BorrowerConfig = await creditLine.getBorrowerConfiguration(borrower.address);

      compareBorrowerConfigs(onChainConfig, config);
    });

    it("Executes as expected and emits the correct event if is called by an admin", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      await proveTx(creditLine.configureAdmin(users[0].address, true));

      await expect((creditLine.connect(users[0]) as Contract).configureBorrower(borrower.address, config))
        .to.emit(creditLine, EVENT_NAME_BORROWER_CONFIGURED)
        .withArgs(await creditLine.getAddress(), borrower.address);

      const onChainConfig: BorrowerConfig = await creditLine.getBorrowerConfiguration(borrower.address);

      compareBorrowerConfigs(onChainConfig, config);
    });

    it("Is reverted if the caller is not an admin", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      await expect((creditLine.connect(attacker) as Contract).configureBorrower(attacker.address, config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is reverted if the contract is paused", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      await proveTx(creditLine.pause());

      await expect(creditLine.configureBorrower(borrower.address, config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if the borrower address is zero", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      await expect(creditLine.configureBorrower(
        ZERO_ADDRESS, // borrower
        config
      )).to.be.revertedWithCustomError(creditLine, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if the min borrow amount is greater than the max one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.minBorrowAmount = DEFAULT_MAX_BORROW_AMOUNT + 1;

      await expect(creditLine.configureBorrower(borrower.address, config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_BORROWER_CONFIGURATION);
    });

    it("Is reverted if the min borrow amount is less than credit line`s one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.minBorrowAmount = DEFAULT_MIN_BORROW_AMOUNT - 1;

      await expect(creditLine.configureBorrower(borrower.address, config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_BORROWER_CONFIGURATION);
    });

    it("Is reverted if the max borrow amount is greater than credit line`s one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.maxBorrowAmount = DEFAULT_MAX_BORROW_AMOUNT + 1;

      await expect(creditLine.configureBorrower(borrower.address, config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_BORROWER_CONFIGURATION);
    });

    it("Is reverted if the min duration in periods is greater than the max one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.minDurationInPeriods = DEFAULT_MAX_DURATION_IN_PERIODS + 1;

      await expect(creditLine.configureBorrower(borrower.address, config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_BORROWER_CONFIGURATION);
    });

    it("Is reverted if the min loan duration is less than credit line`s one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.minDurationInPeriods = DEFAULT_MIN_DURATION_IN_PERIODS - 1;

      await expect(creditLine.configureBorrower(borrower.address, config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_BORROWER_CONFIGURATION);
    });

    it("Is reverted if the max loan duration is greater than credit line`s one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.maxDurationInPeriods = DEFAULT_MAX_DURATION_IN_PERIODS + 1;

      await expect(creditLine.configureBorrower(borrower.address, config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_BORROWER_CONFIGURATION);
    });

    it("Is reverted if the primary interest rate is less than credit line`s minimum one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.interestRatePrimary = DEFAULT_MIN_INTEREST_RATE_PRIMARY - 1;

      await expect(creditLine.configureBorrower(borrower.address, config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_BORROWER_CONFIGURATION);
    });

    it("Is reverted if the primary interest rate is greater than credit line`s maximum one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.interestRatePrimary = DEFAULT_MAX_INTEREST_RATE_PRIMARY + 1;

      await expect(creditLine.configureBorrower(borrower.address, config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_BORROWER_CONFIGURATION);
    });

    it("Is reverted if the secondary interest rate is less than credit line`s minimum one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.interestRateSecondary = DEFAULT_MIN_INTEREST_RATE_SECONDARY - 1;

      await expect(creditLine.configureBorrower(borrower.address, config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_BORROWER_CONFIGURATION);
    });

    it("Is reverted if the secondary interest rate is greater than credit line`s maximum one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.interestRateSecondary = DEFAULT_MAX_INTEREST_RATE_SECONDARY + 1;

      await expect(creditLine.configureBorrower(borrower.address, config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_BORROWER_CONFIGURATION);
    });

    it("Is reverted if the addon fixed rate is less than credit line`s minimum one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.addonFixedRate = DEFAULT_MIN_ADDON_FIXED_RATE - 1;

      await expect(creditLine.configureBorrower(borrower.address, config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_BORROWER_CONFIGURATION);
    });

    it("Is reverted if the addon fixed rate is greater than credit line`s maximum one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.addonFixedRate = DEFAULT_MAX_ADDON_FIXED_RATE + 1;

      await expect(creditLine.configureBorrower(borrower.address, config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_BORROWER_CONFIGURATION);
    });

    it("Is reverted if the addon period rate is less than credit line`s minimum one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.addonPeriodRate = DEFAULT_MIN_ADDON_PERIOD_RATE - 1;

      await expect(creditLine.configureBorrower(borrower.address, config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_BORROWER_CONFIGURATION);
    });

    it("Is reverted if the addon period rate is greater than credit line`s maximum one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.addonPeriodRate = DEFAULT_MAX_ADDON_PERIOD_RATE + 1;

      await expect(creditLine.configureBorrower(borrower.address, config))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_BORROWER_CONFIGURATION);
    });
  });

  describe("Function 'configureBorrowers()'", async () => {
    it("Executes as expected and emits correct events if is called by the lender", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const { borrowers, configs } = await prepareDataForBatchBorrowerConfig(BORROWERS_NUMBER);

      const tx = creditLine.configureBorrowers(borrowers, configs);

      for (let i = 0; i < borrowers.length; i++) {
        await expect(tx)
          .to.emit(creditLine, EVENT_NAME_BORROWER_CONFIGURED)
          .withArgs(await creditLine.getAddress(), borrowers[i]);
      }
    });

    it("Executes as expected and emits correct events if is called by an admin", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const { borrowers, configs } = await prepareDataForBatchBorrowerConfig(BORROWERS_NUMBER);

      await proveTx(creditLine.configureAdmin(users[0].address, true));

      const tx = (creditLine.connect(users[0]) as Contract).configureBorrowers(borrowers, configs);

      for (let i = 0; i < borrowers.length; i++) {
        await expect(tx)
          .to.emit(creditLine, EVENT_NAME_BORROWER_CONFIGURED)
          .withArgs(await creditLine.getAddress(), borrowers[i]);
      }
    });

    it("Is reverted if the caller is not an admin", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const { borrowers, configs } = await prepareDataForBatchBorrowerConfig(BORROWERS_NUMBER);

      await expect((creditLine.connect(attacker) as Contract).configureBorrowers(borrowers, configs))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is reverted if the contract is paused", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const { borrowers, configs } = await prepareDataForBatchBorrowerConfig(BORROWERS_NUMBER);

      await proveTx(creditLine.pause());

      await expect(creditLine.configureBorrowers(borrowers, configs))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if the length of arrays is different", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const { borrowers, configs } = await prepareDataForBatchBorrowerConfig(BORROWERS_NUMBER);

      borrowers.push(attacker.address);

      await expect(creditLine.configureBorrowers(borrowers, configs))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_ARRAYS_LENGTH_MISMATCH);
    });
  });

  describe("Function 'onBeforeLoanTaken()'", async () => {
    it("Executes as expected if the borrow policy is 'Keep'", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      const borrowerConfig: BorrowerConfig = createDefaultBorrowerConfiguration();

      const creditLineConnectedToMarket = creditLine.connect(market) as Contract;

      await proveTx(creditLineConnectedToMarket.onBeforeLoanTaken(
        borrower.address,
        borrowerConfig.minBorrowAmount,
        borrowerConfig.minDurationInPeriods,
        0 // loanId
      ));

      const onChainBorrowerConfig: BorrowerConfig = await creditLine.getBorrowerConfiguration(borrower.address);

      compareBorrowerConfigs(onChainBorrowerConfig, borrowerConfig);
    });

    it("Executes as expected if the borrow policy is 'Decrease'", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const borrowerConfig: BorrowerConfig = createDefaultBorrowerConfiguration();
      borrowerConfig.borrowPolicy = BorrowPolicy.Decrease;
      const borrowAmount = borrowerConfig.maxBorrowAmount - 1;

      await proveTx(creditLine.configureBorrower(borrower.address, borrowerConfig));

      const creditLineConnectedToMarket = creditLine.connect(market) as Contract;

      await proveTx(creditLineConnectedToMarket.onBeforeLoanTaken(
        borrower.address,
        borrowAmount,
        borrowerConfig.minDurationInPeriods,
        0 // loanId
      ));

      borrowerConfig.maxBorrowAmount -= borrowAmount;

      const onChainBorrowerConfig: BorrowerConfig = await creditLine.getBorrowerConfiguration(borrower.address);

      compareBorrowerConfigs(onChainBorrowerConfig, borrowerConfig);
    });

    it("Executes as expected if the borrow policy is 'Reset'", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const borrowerConfig: BorrowerConfig = createDefaultBorrowerConfiguration();
      borrowerConfig.borrowPolicy = BorrowPolicy.Reset;

      await proveTx(creditLine.configureBorrower(borrower.address, borrowerConfig));

      const creditLineConnectedToMarket = creditLine.connect(market) as Contract;

      await proveTx(creditLineConnectedToMarket.onBeforeLoanTaken(
        borrower.address,
        borrowerConfig.minBorrowAmount,
        borrowerConfig.minDurationInPeriods,
        0 // loanId
      ));

      borrowerConfig.maxBorrowAmount = 0;

      const onChainBorrowerConfig: BorrowerConfig = await creditLine.getBorrowerConfiguration(borrower.address);

      compareBorrowerConfigs(onChainBorrowerConfig, borrowerConfig);
    });

    it("Is reverted if the caller is not the configured market", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      const borrowerConfig: BorrowerConfig = createDefaultBorrowerConfiguration();

      await expect(creditLine.onBeforeLoanTaken(
        borrower.address,
        borrowerConfig.minBorrowAmount,
        borrowerConfig.minDurationInPeriods,
        0 // loanId
      )).to.be.revertedWithCustomError(creditLine, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is reverted if the contract is paused", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      const borrowerConfig: BorrowerConfig = createDefaultBorrowerConfiguration();
      await proveTx(creditLine.pause());

      await expect((creditLine.connect(market) as Contract).onBeforeLoanTaken(
        borrower.address,
        borrowerConfig.minBorrowAmount,
        borrowerConfig.minDurationInPeriods,
        0 // loanId
      )).to.be.revertedWithCustomError(creditLine, ERROR_NAME_ENFORCED_PAUSED);
    });
  });

  describe("Function 'determineLoanTerms()'", async () => {
    it("Executes as expected and returns correct values if the addon recipient address is not zero", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      const creditLineConfig = createDefaultCreditLineConfiguration();
      const borrowerConfig = createDefaultBorrowerConfiguration();
      const borrowAmount = Math.floor((borrowerConfig.minBorrowAmount + borrowerConfig.maxBorrowAmount) / 2);
      const durationInPeriods = Math.floor(
        (borrowerConfig.minDurationInPeriods + borrowerConfig.maxDurationInPeriods) / 2
      );

      const expectedTerms: LoanTerms = createLoanTerms(
        borrowAmount,
        durationInPeriods,
        creditLineConfig,
        borrowerConfig
      );
      const onChainTerms: LoanTerms = await creditLine.determineLoanTerms(
        borrower.address,
        borrowAmount,
        durationInPeriods
      );

      compareLoanTerms(onChainTerms, expectedTerms);
    });

    it("Executes as expected and returns correct values if the addon recipient address is zero", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      const creditLineConfig = createDefaultCreditLineConfiguration();
      const borrowerConfig = createDefaultBorrowerConfiguration();
      const borrowAmount = Math.floor((borrowerConfig.minBorrowAmount + borrowerConfig.maxBorrowAmount) / 2);
      const durationInPeriods = Math.floor(
        (borrowerConfig.minDurationInPeriods + borrowerConfig.maxDurationInPeriods) / 2
      );

      creditLineConfig.addonRecipient = ZERO_ADDRESS;
      await proveTx(creditLine.configureCreditLine(creditLineConfig));

      const expectedTerms: LoanTerms = createLoanTerms(
        borrowAmount,
        durationInPeriods,
        creditLineConfig,
        borrowerConfig
      );
      const onChainTerms: LoanTerms = await creditLine.determineLoanTerms(
        borrower.address,
        borrowAmount,
        durationInPeriods
      );

      compareLoanTerms(onChainTerms, expectedTerms);
    });

    it("Is reverted if the borrower address is zero", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      await expect(creditLine.determineLoanTerms(
        ZERO_ADDRESS, // borrower
        DEFAULT_MIN_BORROW_AMOUNT,
        DEFAULT_MIN_DURATION_IN_PERIODS
      )).to.be.revertedWithCustomError(creditLine, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if the borrow amount is zero", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      await expect(creditLine.determineLoanTerms(
        borrower.address,
        0, // borrowAmount
        DEFAULT_MIN_DURATION_IN_PERIODS // durationInPeriods
      )).to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_AMOUNT);
    });

    it("Is reverted if the borrower configuration has been expired", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const borrowerConfig = createDefaultBorrowerConfiguration();

      borrowerConfig.expiration = 0;
      await proveTx(creditLine.configureBorrower(borrower.address, borrowerConfig));

      await expect(creditLine.determineLoanTerms(
        borrower.address,
        DEFAULT_MIN_BORROW_AMOUNT, // borrowAmount
        DEFAULT_MIN_DURATION_IN_PERIODS // durationInPeriods
      )).to.be.revertedWithCustomError(creditLine, ERROR_NAME_BORROWER_CONFIGURATION_EXPIRED);
    });

    it("Is reverted if the borrow amount is greater than the max allowed one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      await expect(creditLine.determineLoanTerms(
        borrower.address,
        DEFAULT_MAX_BORROW_AMOUNT + 1, // borrowAmount
        DEFAULT_MIN_DURATION_IN_PERIODS // durationInPeriods
      )).to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_AMOUNT);
    });

    it("Is reverted if the borrow amount is less than the min allowed one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      await expect(creditLine.determineLoanTerms(
        borrower.address,
        DEFAULT_MIN_BORROW_AMOUNT - 1, // borrowAmount
        DEFAULT_MIN_DURATION_IN_PERIODS // durationInPeriods
      )).to.be.revertedWithCustomError(creditLine, ERROR_NAME_INVALID_AMOUNT);
    });

    it("Is reverted if the loan duration is less than the min allowed one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      await expect(creditLine.determineLoanTerms(
        borrower.address,
        DEFAULT_MIN_BORROW_AMOUNT, // borrowAmount
        DEFAULT_MIN_DURATION_IN_PERIODS - 1 // durationInPeriods
      )).to.be.revertedWithCustomError(creditLine, ERROR_NAME_LOAN_DURATION_OUT_OF_RANGE);
    });

    it("Is reverted if the loan duration is greater than the max allowed one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      await expect(creditLine.determineLoanTerms(
        borrower.address,
        DEFAULT_MIN_BORROW_AMOUNT, // borrowAmount
        DEFAULT_MAX_DURATION_IN_PERIODS + 1 // durationInPeriods
      )).to.be.revertedWithCustomError(creditLine, ERROR_NAME_LOAN_DURATION_OUT_OF_RANGE);
    });
  });
});
