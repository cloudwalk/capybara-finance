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

const ZERO_ADDRESS_ERROR_NAME = "ZeroAddress";
const OWNABLE_UNAUTHORIZED_ERROR_NAME = "OwnableUnauthorizedAccount";
const UNAUTHORIZED_ERROR_NAME = "Unauthorized";
const PAUSED_ERROR_NAME = "EnforcedPause";
const NOT_PAUSED_ERROR_NAME = "ExpectedPause";
const ALREADY_CONFIGURED_ERROR_NAME = "AlreadyConfigured";
const INVALID_CREDIT_LINE_CONFIGURATION_ERROR_NAME = "InvalidCreditLineConfiguration";
const INVALID_BORROWER_CONFIGURATION_ERROR_NAME = "InvalidBorrowerConfiguration";
const ARRAYS_LENGTH_MISMATCH_ERROR_NAME = "ArrayLengthMismatch";
const INVALID_AMOUNT_ERROR_NAME = "InvalidAmount";
const BORROWER_CONFIGURATION_EXPIRED_ERROR_NAME = "BorrowerConfigurationExpired";
const LOAN_DURATION_OUT_OF_RANGE_ERROR_NAME = "LoanDurationOutOfRange";

const PAUSED_EVENT_NAME = "Paused";
const UNPAUSED_EVENT_NAME = "Unpaused";
const ADMIN_CONFIGURED_EVENT_NAME = "AdminConfigured";
const CREDIT_LINE_CONFIGURED_EVENT_NAME = "CreditLineConfigured";
const BORROWER_CONFIGURED_EVENT_NAME = "BorrowerConfigured";

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
const DEFAULT_INTEREST_RATE_FACTOR = 10;
const DEFAULT_MIN_ADDON_FIXED_RATE = 1;
const DEFAULT_MAX_ADDON_FIXED_RATE = 10;
const DEFAULT_MIN_ADDON_PERIOD_RATE = 1;
const DEFAULT_MAX_ADDON_PERIOD_RATE = 10;
const DEFAULT_EXPIRATION_TIME = 4294967295;
const BORROWERS_NUMBER = 3;

describe("Contract 'CreditLineConfigurable'", async () => {
  let creditLineFactory: ContractFactory;

  let lender: HardhatEthersSigner;
  let market: HardhatEthersSigner;
  let token: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;
  let treasury: HardhatEthersSigner;
  let addonRecipient: HardhatEthersSigner;
  let users: HardhatEthersSigner[];

  before(async () => {
    creditLineFactory = await ethers.getContractFactory("CreditLineConfigurable");

    [lender, market, token, attacker, treasury, addonRecipient, ...users] = await ethers.getSigners();
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

  function createLoanTerms(borrowerConfiguration: BorrowerConfig, addonAmount: number): LoanTerms {
    return {
      token: token.address,
      interestRatePrimary: borrowerConfiguration.interestRatePrimary,
      interestRateSecondary: borrowerConfiguration.interestRateSecondary,
      interestRateFactor: DEFAULT_INTEREST_RATE_FACTOR,
      treasury: treasury.address,
      periodInSeconds: DEFAULT_PERIOD_IN_SECONDS,
      durationInPeriods: borrowerConfiguration.minDurationInPeriods,
      interestFormula: borrowerConfiguration.interestFormula,
      autoRepayment: borrowerConfiguration.autoRepayment,
      addonRecipient: addonRecipient.address,
      addonAmount: addonAmount
    };
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
    creditLine = creditLine.connect(lender) as Contract;

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
    await proveTx(creditLine.configureBorrower(lender.address, borrowerConfig));

    return { creditLine };
  }

  describe("Function 'initialize()'", async () => {
    it("Configures contract as expected", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      expect(await creditLine.lender()).to.eq(lender.address);
      expect(await creditLine.owner()).to.eq(lender.address);
      expect(await creditLine.token()).to.eq(token.address);
      expect(await creditLine.market()).to.eq(market.address);
      expect(await creditLine.kind()).to.eq(CREDIT_LINE_KIND);
      expect(await creditLine.paused()).to.eq(false);
    });

    it("Is reverted if market address is zero", async () => {
      await expect(upgrades.deployProxy(creditLineFactory, [
        ZERO_ADDRESS, // market
        lender.address,
        token.address
      ])).to.be.revertedWithCustomError(creditLineFactory, ZERO_ADDRESS_ERROR_NAME);
    });

    it("Is reverted if token address is zero", async () => {
      await expect(upgrades.deployProxy(creditLineFactory, [
        market.address,
        lender.address,
        ZERO_ADDRESS // token
      ])).to.be.revertedWithCustomError(creditLineFactory, ZERO_ADDRESS_ERROR_NAME);
    });
  });

  describe("Function 'pause()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      expect(await creditLine.pause())
        .to.emit(creditLine, PAUSED_EVENT_NAME)
        .withArgs(lender.address);
      expect(await creditLine.paused()).to.eq(true);
    });

    it("Is reverted if caller is not an owner", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await expect((creditLine.connect(attacker) as Contract).pause())
        .to.be.revertedWithCustomError(creditLineFactory, OWNABLE_UNAUTHORIZED_ERROR_NAME)
        .withArgs(attacker.address);
    });

    it("Is reverted if contract is paused", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await proveTx(await creditLine.pause());
      await expect(creditLine.pause())
        .to.be.revertedWithCustomError(creditLine, PAUSED_ERROR_NAME);
    });
  });

  describe("Function 'unpause", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await proveTx(creditLine.pause());
      expect(await creditLine.paused()).to.eq(true);

      expect(creditLine.unpause())
        .to.emit(creditLine, UNPAUSED_EVENT_NAME)
        .withArgs(lender.address);

      expect(await creditLine.paused()).to.eq(false);
    });

    it("Is reverted if caller if caller is not an owner", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await expect((creditLine.connect(attacker) as Contract).unpause())
        .to.be.revertedWithCustomError(creditLineFactory, OWNABLE_UNAUTHORIZED_ERROR_NAME)
        .withArgs(attacker.address);
    });

    it("Is reverted if contract is not paused", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await expect(creditLine.unpause())
        .to.be.revertedWithCustomError(creditLine, NOT_PAUSED_ERROR_NAME);
    });
  });

  describe("Function 'configureAdmin()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      expect(await creditLine.isAdmin(lender.address)).to.eq(false);

      expect(await creditLine.configureAdmin(lender.address, true))
        .to.emit(creditLine, ADMIN_CONFIGURED_EVENT_NAME)
        .withArgs(lender.address, true);

      expect(await creditLine.isAdmin(lender.address)).to.eq(true);
    });

    it("Is reverted if caller is not the owner", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await expect((creditLine.connect(attacker) as Contract).configureAdmin(attacker.address, true))
        .to.be.revertedWithCustomError(creditLine, OWNABLE_UNAUTHORIZED_ERROR_NAME)
        .withArgs(attacker.address);
    });

    it("Is reverted if account is zero address", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await expect(creditLine.configureAdmin(
        ZERO_ADDRESS, // account
        true // isAdmin
      )).to.be.revertedWithCustomError(creditLine, ZERO_ADDRESS_ERROR_NAME);
    });

    it("Is reverted if the admin is already configured", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await proveTx(await creditLine.configureAdmin(lender.address, true));

      await expect(creditLine.configureAdmin(lender.address, true))
        .to.be.revertedWithCustomError(creditLine, ALREADY_CONFIGURED_ERROR_NAME);
    });
  });

  describe("Function 'configureCreditLine()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      expect(await creditLine.configureCreditLine(config))
        .to.emit(creditLine, CREDIT_LINE_CONFIGURED_EVENT_NAME)
        .withArgs(await creditLine.getAddress());

      const onChainConfig: CreditLineConfig = await creditLine.creditLineConfiguration();

      compareCreditLineConfigs(onChainConfig, config);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      await expect((creditLine.connect(attacker) as Contract).configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, OWNABLE_UNAUTHORIZED_ERROR_NAME)
        .withArgs(attacker.address);
    });

    it("Is reverted if period in seconds is zero", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      config.periodInSeconds = 0;

      await expect(creditLine.configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, INVALID_CREDIT_LINE_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if interest rate factor is zero", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      config.interestRateFactor = 0;

      await expect(creditLine.configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, INVALID_CREDIT_LINE_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if min borrow amount is bigger than max borrow amount", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      config.minBorrowAmount = config.maxBorrowAmount + 1;

      await expect(creditLine.configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, INVALID_CREDIT_LINE_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if min duration in periods is bigger than max duration in periods", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      config.minDurationInPeriods = config.maxDurationInPeriods + 1;

      await expect(creditLine.configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, INVALID_CREDIT_LINE_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if min interest rate primary is bigger than max interest rate primary", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      config.minInterestRatePrimary = config.maxInterestRatePrimary + 1;

      await expect(creditLine.configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, INVALID_CREDIT_LINE_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if min interest rate secondary is bigger than max interest rate secondary", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      config.minInterestRateSecondary = config.maxInterestRateSecondary + 1;

      await expect(creditLine.configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, INVALID_CREDIT_LINE_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if min addon fixed rate is bigger than max addon fixed rate", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      config.minAddonFixedRate = config.maxAddonFixedRate + 1;

      await expect(creditLine.configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, INVALID_CREDIT_LINE_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if min addon period rate is bigger than max addon period rate", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      const config = createDefaultCreditLineConfiguration();

      config.minAddonPeriodRate = config.maxAddonPeriodRate + 1;

      await expect(creditLine.configureCreditLine(config))
        .to.be.revertedWithCustomError(creditLine, INVALID_CREDIT_LINE_CONFIGURATION_ERROR_NAME);
    });
  });

  describe("Function 'configureBorrower()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      await expect(await creditLine.configureBorrower(lender.address, config))
        .to.emit(creditLine, BORROWER_CONFIGURED_EVENT_NAME)
        .withArgs(await creditLine.getAddress(), lender.address);

      const onChainConfig: BorrowerConfig = await creditLine.getBorrowerConfiguration(lender.address);

      compareBorrowerConfigs(onChainConfig, config);
    });

    it("Is reverted if the caller is not an admin", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      await expect((creditLine.connect(attacker) as Contract).configureBorrower(attacker.address, config))
        .to.be.revertedWithCustomError(creditLine, UNAUTHORIZED_ERROR_NAME);
    });

    it("Is reverted if contract is paused", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      await proveTx(creditLine.pause());

      await expect(creditLine.configureBorrower(lender.address, config))
        .to.be.revertedWithCustomError(creditLine, PAUSED_ERROR_NAME);
    });

    it("Is reverted if borrower address is zero", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      await expect(creditLine.configureBorrower(
        ZERO_ADDRESS, // borrower
        config
      )).to.be.revertedWithCustomError(creditLine, ZERO_ADDRESS_ERROR_NAME);
    });

    it("Is reverted if borrower`s min borrow amount is bigger than max borrow amount", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.minBorrowAmount = DEFAULT_MAX_BORROW_AMOUNT + 1;

      await expect(creditLine.configureBorrower(lender.address, config))
        .to.be.revertedWithCustomError(creditLine, INVALID_BORROWER_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if borrower`s min borrow amount is less than credit line`s one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.minBorrowAmount = DEFAULT_MIN_BORROW_AMOUNT - 1;

      await expect(creditLine.configureBorrower(lender.address, config))
        .to.be.revertedWithCustomError(creditLine, INVALID_BORROWER_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if borrower`s max borrow amount is bigger than credit line`s one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.maxBorrowAmount = DEFAULT_MAX_BORROW_AMOUNT + 1;

      await expect(creditLine.configureBorrower(lender.address, config))
        .to.be.revertedWithCustomError(creditLine, INVALID_BORROWER_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if borrower`s min duration in periods is bigger than max duration in periods", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.minDurationInPeriods = DEFAULT_MAX_DURATION_IN_PERIODS + 1;

      await expect(creditLine.configureBorrower(lender.address, config))
        .to.be.revertedWithCustomError(creditLine, INVALID_BORROWER_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if borrower`s min duration in periods is les than credit line`s one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.minDurationInPeriods = DEFAULT_MIN_DURATION_IN_PERIODS - 1;

      await expect(creditLine.configureBorrower(lender.address, config))
        .to.be.revertedWithCustomError(creditLine, INVALID_BORROWER_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if borrower`s max duration in periods is bigger than credit line`s one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.maxDurationInPeriods = DEFAULT_MAX_DURATION_IN_PERIODS + 1;

      await expect(creditLine.configureBorrower(lender.address, config))
        .to.be.revertedWithCustomError(creditLine, INVALID_BORROWER_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if borrower`s interest rate primary is less than credit line`s minimum one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.interestRatePrimary = DEFAULT_MIN_INTEREST_RATE_PRIMARY - 1;

      await expect(creditLine.configureBorrower(lender.address, config))
        .to.be.revertedWithCustomError(creditLine, INVALID_BORROWER_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if borrower`s interest rate primary is bigger than credit line`s maximum one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.interestRatePrimary = DEFAULT_MAX_INTEREST_RATE_PRIMARY + 1;

      await expect(creditLine.configureBorrower(lender.address, config))
        .to.be.revertedWithCustomError(creditLine, INVALID_BORROWER_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if borrower`s interest rate secondary is less than credit line`s minimum one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.interestRateSecondary = DEFAULT_MIN_INTEREST_RATE_SECONDARY - 1;

      await expect(creditLine.configureBorrower(lender.address, config))
        .to.be.revertedWithCustomError(creditLine, INVALID_BORROWER_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if borrower`s interest rate secondary is bigger than credit line`s maximum one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.interestRateSecondary = DEFAULT_MAX_INTEREST_RATE_SECONDARY + 1;

      await expect(creditLine.configureBorrower(lender.address, config))
        .to.be.revertedWithCustomError(creditLine, INVALID_BORROWER_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if borrower`s addon fixed rate is less than credit line`s minimum one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.addonFixedRate = DEFAULT_MIN_ADDON_FIXED_RATE - 1;

      await expect(creditLine.configureBorrower(lender.address, config))
        .to.be.revertedWithCustomError(creditLine, INVALID_BORROWER_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if borrower`s addon fixed rate is bigger than credit line`s maximum one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.addonFixedRate = DEFAULT_MAX_ADDON_FIXED_RATE + 1;

      await expect(creditLine.configureBorrower(lender.address, config))
        .to.be.revertedWithCustomError(creditLine, INVALID_BORROWER_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if borrower`s addon period rate is less than credit line`s minimum one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.addonPeriodRate = DEFAULT_MIN_ADDON_PERIOD_RATE - 1;

      await expect(creditLine.configureBorrower(lender.address, config))
        .to.be.revertedWithCustomError(creditLine, INVALID_BORROWER_CONFIGURATION_ERROR_NAME);
    });

    it("Is reverted if borrower`s addon period rate is bigger than credit line`s maximum one", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const config = createDefaultBorrowerConfiguration();

      config.addonPeriodRate = DEFAULT_MAX_ADDON_PERIOD_RATE + 1;

      await expect(creditLine.configureBorrower(lender.address, config))
        .to.be.revertedWithCustomError(creditLine, INVALID_BORROWER_CONFIGURATION_ERROR_NAME);
    });
  });

  describe("Function 'configureBorrowers()'", async () => {
    it("Executes as expected and emits correct events", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const { borrowers, configs } = await prepareDataForBatchBorrowerConfig(BORROWERS_NUMBER);

      const tx = await creditLine.configureBorrowers(borrowers, configs);

      for (let i = 0; i < borrowers.length; i++) {
        await expect(tx)
          .to.emit(creditLine, BORROWER_CONFIGURED_EVENT_NAME)
          .withArgs(await creditLine.getAddress(), borrowers[i]);
      }
    });

    it("Is reverted if the caller is not an admin", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const { borrowers, configs } = await prepareDataForBatchBorrowerConfig(BORROWERS_NUMBER);

      await expect((creditLine.connect(attacker) as Contract).configureBorrowers(borrowers, configs))
        .to.be.revertedWithCustomError(creditLine, UNAUTHORIZED_ERROR_NAME);
    });

    it("Is reverted if the contract is paused", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const { borrowers, configs } = await prepareDataForBatchBorrowerConfig(BORROWERS_NUMBER);

      await proveTx(creditLine.pause());

      await expect(creditLine.configureBorrowers(borrowers, configs))
        .to.be.revertedWithCustomError(creditLine, PAUSED_ERROR_NAME);
    });

    it("Is reverted if the length of arrays is different", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const { borrowers, configs } = await prepareDataForBatchBorrowerConfig(BORROWERS_NUMBER);

      borrowers.push(attacker.address);

      await expect(creditLine.configureBorrowers(borrowers, configs))
        .to.be.revertedWithCustomError(creditLine, ARRAYS_LENGTH_MISMATCH_ERROR_NAME);
    });
  });

  describe("Function 'onBeforeLoanTaken()'", async () => {
    it("Executes as expected if the borrow policy is 'Keep'", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      const borrowerConfig: BorrowerConfig = createDefaultBorrowerConfiguration();

      const creditLineConnectedToMarket = creditLine.connect(market) as Contract;

      await proveTx(creditLineConnectedToMarket.onBeforeLoanTaken(
        lender.address,
        borrowerConfig.minBorrowAmount,
        borrowerConfig.minDurationInPeriods,
        0 // loanId
      ));

      const onChainBorrowerConfig: BorrowerConfig = await creditLine.getBorrowerConfiguration(lender.address);

      compareBorrowerConfigs(onChainBorrowerConfig, borrowerConfig);
    });

    it("Executes as expected if the borrow policy is 'Decrease'", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const borrowerConfig: BorrowerConfig = createDefaultBorrowerConfiguration();
      borrowerConfig.borrowPolicy = BorrowPolicy.Decrease;

      await proveTx(creditLine.configureBorrower(lender.address, borrowerConfig));

      const creditLineConnectedToMarket = creditLine.connect(market) as Contract;

      await proveTx(creditLineConnectedToMarket.onBeforeLoanTaken(
        lender.address,
        borrowerConfig.minBorrowAmount,
        borrowerConfig.minDurationInPeriods,
        0 // loanId
      ));

      borrowerConfig.maxBorrowAmount -= borrowerConfig.minBorrowAmount;

      const onChainBorrowerConfig: BorrowerConfig = await creditLine.getBorrowerConfiguration(lender.address);

      compareBorrowerConfigs(onChainBorrowerConfig, borrowerConfig);
    });

    it("Executes as expected if the borrow policy is 'Reset'", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const borrowerConfig: BorrowerConfig = createDefaultBorrowerConfiguration();
      borrowerConfig.borrowPolicy = BorrowPolicy.Reset;

      await proveTx(creditLine.configureBorrower(lender.address, borrowerConfig));

      const creditLineConnectedToMarket = creditLine.connect(market) as Contract;

      await proveTx(creditLineConnectedToMarket.onBeforeLoanTaken(
        lender.address,
        borrowerConfig.minBorrowAmount,
        borrowerConfig.minDurationInPeriods,
        0 // loanId
      ));

      borrowerConfig.maxBorrowAmount = 0;

      const onChainBorrowerConfig: BorrowerConfig = await creditLine.getBorrowerConfiguration(lender.address);

      compareBorrowerConfigs(onChainBorrowerConfig, borrowerConfig);
    });

    it("Is reverted if the caller is not a market", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      const borrowerConfig: BorrowerConfig = createDefaultBorrowerConfiguration();

      await expect(creditLine.onBeforeLoanTaken(
        lender.address,
        borrowerConfig.minBorrowAmount,
        borrowerConfig.minDurationInPeriods,
        0 // loanId
      )).to.be.revertedWithCustomError(creditLine, UNAUTHORIZED_ERROR_NAME);
    });
  });

  describe("Function 'determineLoanTerms()'", async () => {
    it("Executes as expected and returns correct values", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      const addonAmount = await creditLine.calculateAddonAmount(
        DEFAULT_MIN_BORROW_AMOUNT,
        DEFAULT_MIN_DURATION_IN_PERIODS,
        DEFAULT_MIN_ADDON_FIXED_RATE,
        DEFAULT_MIN_ADDON_PERIOD_RATE
      );

      const expectedTerms: LoanTerms = createLoanTerms(createDefaultBorrowerConfiguration(), addonAmount);
      const onChainTerms: LoanTerms = await creditLine.determineLoanTerms(
        lender.address,
        DEFAULT_MIN_BORROW_AMOUNT,
        DEFAULT_MIN_DURATION_IN_PERIODS
      );

      compareLoanTerms(onChainTerms, expectedTerms);
    });

    it("Is reverted if the borrower address is zero", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      await expect(creditLine.determineLoanTerms(
        ZERO_ADDRESS, // borrower
        DEFAULT_MIN_BORROW_AMOUNT,
        DEFAULT_MIN_DURATION_IN_PERIODS
      )).to.be.revertedWithCustomError(creditLine, ZERO_ADDRESS_ERROR_NAME);
    });

    it("Is reverted if the borrow amount is zero", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      await expect(creditLine.determineLoanTerms(
        lender.address,
        0, // borrowAmount
        DEFAULT_MIN_DURATION_IN_PERIODS)
      ).to.be.revertedWithCustomError(creditLine, INVALID_AMOUNT_ERROR_NAME);
    });

    it("Is reverted if the borrower configuration expired", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLine);
      const borrowerConfig = createDefaultBorrowerConfiguration();

      borrowerConfig.expiration = 0;
      await proveTx(creditLine.configureBorrower(lender.address, borrowerConfig));

      await expect(creditLine.determineLoanTerms(
        lender.address,
        DEFAULT_MIN_BORROW_AMOUNT,
        DEFAULT_MIN_DURATION_IN_PERIODS
      )).to.be.revertedWithCustomError(creditLine, BORROWER_CONFIGURATION_EXPIRED_ERROR_NAME);
    });

    it("Is reverted if the borrow amount is bigger than max borrow amount", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      await expect(creditLine.determineLoanTerms(
        lender.address,
        DEFAULT_MAX_BORROW_AMOUNT + 1,
        DEFAULT_MIN_DURATION_IN_PERIODS)
      ).to.be.revertedWithCustomError(creditLine, INVALID_AMOUNT_ERROR_NAME);
    });

    it("Is reverted if the borrow amount is less than min borrow amount", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      await expect(creditLine.determineLoanTerms(
        lender.address,
        DEFAULT_MIN_BORROW_AMOUNT - 1,
        DEFAULT_MIN_DURATION_IN_PERIODS)
      ).to.be.revertedWithCustomError(creditLine, INVALID_AMOUNT_ERROR_NAME);
    });

    it("Is reverted if the duration in periods is less than min duration in periods", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      await expect(creditLine.determineLoanTerms(
        lender.address,
        DEFAULT_MIN_BORROW_AMOUNT,
        DEFAULT_MIN_DURATION_IN_PERIODS - 1)
      ).to.be.revertedWithCustomError(creditLine, LOAN_DURATION_OUT_OF_RANGE_ERROR_NAME);
    });

    it("Is reverted if the duration in periods is bigger than max duration in periods", async () => {
      const { creditLine } = await loadFixture(deployAndConfigureCreditLineWithBorrower);
      await expect(creditLine.determineLoanTerms(
        lender.address,
        DEFAULT_MIN_BORROW_AMOUNT,
        DEFAULT_MAX_DURATION_IN_PERIODS + 1)
      ).to.be.revertedWithCustomError(creditLine, LOAN_DURATION_OUT_OF_RANGE_ERROR_NAME);
    });
  });
});