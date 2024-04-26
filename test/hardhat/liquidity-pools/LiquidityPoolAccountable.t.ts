import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory} from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { proveTx } from "../../../test-utils/eth";
import { TransactionReceipt } from "@ethersproject/abstract-provider";
import { deploy } from "@openzeppelin/hardhat-upgrades/dist/utils";

const ERROR_NAME_ALREADY_CONFIGURED = "AlreadyConfigured";
const ERROR_NAME_ALREADY_INITIALIZED = "InvalidInitialization";
const ERROR_NAME_ARRAY_LENGTH_MISMATCH = "ArrayLengthMismatch";
const ERROR_NAME_ALREADY_PAUSED = "EnforcedPause";
const ERROR_NAME_INSUFFICIENT_BALANCE = "InsufficientBalance";
const ERROR_NAME_INVALID_AMOUNT = "InvalidAmount";
const ERROR_NAME_NOT_PAUSED = "ExpectedPause";
const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";
const ERROR_NAME_UNAUTHORIZED = "Unauthorized";
const ERROR_NAME_ZERO_ADDRESS = "ZeroAddress";
const ERROR_NAME_ZERO_BALANCE = "ZeroBalance";

const EVENT_NAME_ADMIN_CONFIGURED = "AdminConfigured";
const EVENT_NAME_AUTO_REPAYMENT = "AutoRepayment";
const EVENT_NAME_DEPOSIT = "Deposit";
const EVENT_NAME_HOOK_CALL_RESULT = "HookCallResult";
const EVENT_NAME_PAUSED = "Paused";
const EVENT_NAME_REPAY_LOAN_CALLED = "RepayLoanCalled";
const EVENT_NAME_UNPAUSED = "Unpaused";
const EVENT_NAME_WITHDRAWAL = "Withdrawal";

const ZERO_ADDRESS = ethers.ZeroAddress;
const MINT_AMOUNT = 1000000;
const DEPOSIT_AMOUNT = 1000;
const LIQUIDITY_POOL_KIND = 1;
const DEFAULT_LOAN_ID = 123;
const DEFAULT_REPAY_AMOUNT = 322;
const AUTO_REPAY_LOAN_IDS = [1, 2, 3];
const AUTO_REPAY_AMOUNTS = [4, 5, 6];

describe("Contract 'LiquidityPoolAccountable'", async () => {
  let liquidityPoolFactory: ContractFactory;
  let tokenFactory: ContractFactory
  let marketFactory: ContractFactory;
  let creditLineFactory: ContractFactory;

  let market: Contract;
  let token: Contract;
  let creditLine: Contract

  let deployer: HardhatEthersSigner;
  let lender: HardhatEthersSigner;
  let admin: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;

  let tokenAddress: string;
  let marketAddress: string;
  let creditLineAddress: string;
  let liquidityPoolAddress: string;

  before(async () => {
    [deployer, lender, admin, attacker] = await ethers.getSigners();

    // Factories with an explicitly specified deployer account
    liquidityPoolFactory = await ethers.getContractFactory("LiquidityPoolAccountable");
    liquidityPoolFactory = liquidityPoolFactory.connect(deployer);
    tokenFactory = await ethers.getContractFactory("ERC20Mock");
    tokenFactory = tokenFactory.connect(deployer);
    marketFactory = await ethers.getContractFactory("LendingMarketMock");
    marketFactory = marketFactory.connect(deployer);
    creditLineFactory = await ethers.getContractFactory("CreditLineMock");
    creditLineFactory = creditLineFactory.connect(deployer);

    market = await marketFactory.deploy() as Contract;
    await market.waitForDeployment();
    market = market.connect(deployer) as Contract; // Explicitly specifying the initial account
    marketAddress = await market.getAddress();

    token = await tokenFactory.deploy() as Contract;
    await token.waitForDeployment();
    token = token.connect(deployer) as Contract; // Explicitly specifying the initial account
    tokenAddress = await token.getAddress();
    await token.mint(lender.address, MINT_AMOUNT);

    creditLine = await creditLineFactory.deploy() as Contract;
    await creditLine.waitForDeployment()
    creditLine = creditLine.connect(deployer) as Contract; // Explicitly specifying the initial account
    await creditLine.mockTokenAddress(tokenAddress);
    creditLineAddress = await creditLine.getAddress();
  });

  async function deployLiquidityPool(): Promise<{ liquidityPool: Contract }> {
    let liquidityPool = await upgrades.deployProxy(liquidityPoolFactory, [
      marketAddress,
      lender.address
    ])

    await liquidityPool.waitForDeployment();
    liquidityPool = liquidityPool.connect(lender) as Contract; // Explicitly specifying the initial account
    liquidityPoolAddress = await liquidityPool.getAddress();

    await proveTx((token.connect(lender) as Contract).approve(liquidityPoolAddress, MINT_AMOUNT));
    return { liquidityPool }
  }

  describe("Function 'initialize()'", async () => {
    it("Configures the contract as expected", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);
      expect(await liquidityPool.lender()).to.eq(lender.address);
      expect(await liquidityPool.owner()).to.eq(lender.address);
      expect(await liquidityPool.market()).to.eq(marketAddress);
      expect(await liquidityPool.kind()).to.eq(LIQUIDITY_POOL_KIND);
    });

    it("Is reverted if the market address is zero", async () => {
      await expect(upgrades.deployProxy(liquidityPoolFactory, [
        ZERO_ADDRESS, // market
        lender.address
      ])).to.be.revertedWithCustomError(liquidityPoolFactory, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if called second time", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect(liquidityPool.initialize(marketAddress, lender.address))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_ALREADY_INITIALIZED);
    });
  });

  describe("Function 'pause()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect(liquidityPool.pause())
        .to.emit(liquidityPool, EVENT_NAME_PAUSED)
        .withArgs(lender.address);
      expect(await liquidityPool.paused()).to.eq(true);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect((liquidityPool.connect(attacker) as Contract).pause())
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_OWNABLE_UNAUTHORIZED)
        .withArgs(attacker.address);
    });

    it("Is reverted if the contract is already paused", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await proveTx(liquidityPool.pause());
      await expect(liquidityPool.pause())
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_ALREADY_PAUSED);
    });
  });

  describe("Function 'unpause()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await proveTx(liquidityPool.pause());
      expect(await liquidityPool.paused()).to.eq(true);

      await expect(liquidityPool.unpause())
        .to.emit(liquidityPool, EVENT_NAME_UNPAUSED)
        .withArgs(lender.address);

      expect(await liquidityPool.paused()).to.eq(false);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect((liquidityPool.connect(attacker) as Contract).unpause())
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_OWNABLE_UNAUTHORIZED)
        .withArgs(attacker.address);
    });

    it("Is reverted if the contract is not paused yet", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect(liquidityPool.unpause())
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_NOT_PAUSED);
    });
  });

  describe("Function 'configureAdmin()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      expect(await liquidityPool.isAdmin(admin.address)).to.eq(false);

      expect(await liquidityPool.configureAdmin(admin.address, true))
        .to.emit(liquidityPool, EVENT_NAME_ADMIN_CONFIGURED)
        .withArgs(admin.address, true);

      expect(await liquidityPool.isAdmin(admin.address)).to.eq(true);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect((liquidityPool.connect(attacker) as Contract).configureAdmin(attacker.address, true))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_OWNABLE_UNAUTHORIZED)
        .withArgs(attacker.address);
    });

    it("Is reverted if the account address is zero", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect(liquidityPool.configureAdmin(
        ZERO_ADDRESS, // account
        true          // isAdmin
      )).to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if the admin is already configured", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await proveTx(liquidityPool.configureAdmin(admin.address, true));

      await expect(liquidityPool.configureAdmin(admin.address, true))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_ALREADY_CONFIGURED);
    });
  });

  describe("Function 'deposit()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      const tx: TransactionReceipt = await proveTx(liquidityPool.deposit(creditLineAddress, DEPOSIT_AMOUNT));

      expect(tx).to.changeTokenBalances(
        token,
        [lender.address, liquidityPoolAddress],
        [-DEPOSIT_AMOUNT, +DEPOSIT_AMOUNT]
      );

      expect(tx)
        .to.emit(liquidityPool, EVENT_NAME_DEPOSIT)
        .withArgs(creditLineAddress, DEPOSIT_AMOUNT);
    });

    it("Is reverted if caller is not the owner", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect((liquidityPool.connect(attacker) as Contract).deposit(tokenAddress, DEPOSIT_AMOUNT))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });

    it("Is reverted if credit line address is zero", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect(liquidityPool.deposit(ZERO_ADDRESS, DEPOSIT_AMOUNT))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if deposit amount is zero", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect(liquidityPool.deposit(creditLineAddress, 0))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_INVALID_AMOUNT);
    });
  });

  describe("Function 'withdraw()'", async () => {
    it("Executes as expected and emits correct event when withdrawing credit line balance", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);
      await proveTx(liquidityPool.deposit(creditLineAddress, DEPOSIT_AMOUNT));

      const tx: TransactionReceipt = await proveTx(liquidityPool.withdraw(creditLineAddress, DEPOSIT_AMOUNT));

      expect(tx).to.changeTokenBalances(
        token,
        [lender.address, liquidityPoolAddress],
        [+DEPOSIT_AMOUNT, -DEPOSIT_AMOUNT]
      );

      expect(tx)
        .to.emit(liquidityPool, EVENT_NAME_WITHDRAWAL)
        .withArgs(creditLineAddress, DEPOSIT_AMOUNT);
    });

    it("Executes as expected and emits correct event when withdrawing token balance", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);
      await proveTx((token.connect(lender) as Contract).transfer(liquidityPoolAddress, DEPOSIT_AMOUNT));

      const tx: TransactionReceipt = await proveTx(liquidityPool.withdraw(tokenAddress, DEPOSIT_AMOUNT));

      expect(tx).to.changeTokenBalances(
        token,
        [lender.address, liquidityPoolAddress],
        [+DEPOSIT_AMOUNT, -DEPOSIT_AMOUNT]
      );

      expect(tx)
        .to.emit(liquidityPool, EVENT_NAME_WITHDRAWAL)
        .withArgs(tokenAddress, DEPOSIT_AMOUNT);
    });

    it("Is reverted if caller is not the owner", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect((liquidityPool.connect(attacker) as Contract).withdraw(tokenAddress, DEPOSIT_AMOUNT))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });

    it("Is reverted if token source is zero address", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect(liquidityPool.withdraw(ZERO_ADDRESS, DEPOSIT_AMOUNT))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if token amount is zero", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect(liquidityPool.withdraw(creditLineAddress, 0))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_INVALID_AMOUNT);
    });

    it("Is reverted if withdrawing credit line balance with insufficient balance", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);
      await proveTx(liquidityPool.deposit(creditLineAddress, DEPOSIT_AMOUNT));

      await expect(liquidityPool.withdraw(creditLineAddress, DEPOSIT_AMOUNT + 1))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_INSUFFICIENT_BALANCE);
    });

    it("Is reverted if withdrawing token balance with insufficient balance", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);
      await proveTx((token.connect(lender) as Contract).transfer(liquidityPoolAddress, DEPOSIT_AMOUNT));

      await expect(liquidityPool.withdraw(tokenAddress, DEPOSIT_AMOUNT + 1))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_INSUFFICIENT_BALANCE);
    });

    it("Is reverted is balance is zero", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect(liquidityPool.withdraw(creditLineAddress, DEPOSIT_AMOUNT))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_ZERO_BALANCE);
    });
  });

  describe("Function 'autoRepay()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);
      await proveTx(liquidityPool.configureAdmin(admin.address, true));

      const tx: TransactionReceipt = await proveTx((liquidityPool.connect(admin) as Contract)
        .autoRepay(AUTO_REPAY_LOAN_IDS, AUTO_REPAY_AMOUNTS));
      await expect(tx).to.emit(liquidityPool, EVENT_NAME_AUTO_REPAYMENT)
        .withArgs(AUTO_REPAY_LOAN_IDS.length);

      for (let i = 0; i < AUTO_REPAY_LOAN_IDS.length; i++) {
        await expect(tx).to.emit(market, EVENT_NAME_REPAY_LOAN_CALLED)
          .withArgs(AUTO_REPAY_LOAN_IDS[i], AUTO_REPAY_AMOUNTS[i]);
      }
    });

    it("Is reverted if caller is not the admin", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect((liquidityPool.connect(attacker) as Contract)
        .autoRepay(AUTO_REPAY_LOAN_IDS, AUTO_REPAY_AMOUNTS))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_UNAUTHORIZED);
    });

    it("Is reverted if arrays length mismatches", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);
      await proveTx(liquidityPool.configureAdmin(admin.address, true));

      AUTO_REPAY_LOAN_IDS.pop();

      await expect((liquidityPool.connect(admin) as Contract)
        .autoRepay(AUTO_REPAY_LOAN_IDS, AUTO_REPAY_AMOUNTS))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_ARRAY_LENGTH_MISMATCH);
    });
  });

  describe("Function 'onBeforeLoanTaken()'", async () => {
    it("Executes as expected", async () => {
      await expect(market.callOnBeforeLoanTaken(liquidityPoolAddress, DEFAULT_LOAN_ID, creditLineAddress))
        .to.emit(market, EVENT_NAME_HOOK_CALL_RESULT)
        .withArgs(true);
    });

    it("Is reverted if contract is paused", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);
      await proveTx(liquidityPool.pause());

      await expect(market.callOnBeforeLoanTaken(liquidityPoolAddress, DEFAULT_LOAN_ID, creditLineAddress))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_ALREADY_PAUSED);
    });

    it("Is reverted if the caller is not the market", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect(liquidityPool.onBeforeLoanTaken(DEFAULT_LOAN_ID, creditLineAddress))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_UNAUTHORIZED);
    });
  });

  describe("Function 'onAfterLoanTaken()'", async () => {
    it("Executes as expected", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect(market.callOnAfterLoanTaken(liquidityPoolAddress, DEFAULT_LOAN_ID, creditLineAddress))
        .to.emit(market, EVENT_NAME_HOOK_CALL_RESULT)
        .withArgs(true);

      expect(await liquidityPool.getCreditLine(DEFAULT_LOAN_ID)).to.eq(creditLineAddress);
    });

    it("Is reverted if contract is paused", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);
      await proveTx(liquidityPool.pause());

      await expect(market.callOnAfterLoanTaken(liquidityPoolAddress, DEFAULT_LOAN_ID, creditLineAddress))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_ALREADY_PAUSED);
    });

    it("Is reverted if the caller is not the market", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect(liquidityPool.onAfterLoanTaken(DEFAULT_LOAN_ID, creditLineAddress))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_UNAUTHORIZED);
    });
  });

  describe("Function 'onBeforeLoanPayment()'", async () => {
    it("Executes as expected", async () => {
      await expect(market.callOnBeforeLoanPayment(liquidityPoolAddress, DEFAULT_LOAN_ID, DEFAULT_REPAY_AMOUNT))
        .to.emit(market, EVENT_NAME_HOOK_CALL_RESULT)
        .withArgs(true);
    });

    it("Is reverted if contract is paused", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);
      await proveTx(liquidityPool.pause());

      await expect(market.callOnBeforeLoanPayment(liquidityPoolAddress, DEFAULT_LOAN_ID, DEFAULT_REPAY_AMOUNT))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_ALREADY_PAUSED);
    });

    it("Is reverted if the caller is not the market", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect(liquidityPool.onBeforeLoanPayment(DEFAULT_LOAN_ID, DEFAULT_REPAY_AMOUNT))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_UNAUTHORIZED);
    });
  });

  describe("Function 'onAfterLoanPayment()'", async () => {
    it("Executes as expected if loanId is not associated with a credit line", async () => {
      await expect(market.callOnAfterLoanPayment(liquidityPoolAddress, DEFAULT_LOAN_ID, DEFAULT_REPAY_AMOUNT))
        .to.emit(market, EVENT_NAME_HOOK_CALL_RESULT)
        .withArgs(true);
    });

    it("Executes as expected if loanId is associated with a credit line", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await proveTx(market.callOnAfterLoanTaken(liquidityPoolAddress, DEFAULT_LOAN_ID, creditLineAddress));
      await expect(market.callOnAfterLoanPayment(liquidityPoolAddress, DEFAULT_LOAN_ID, DEFAULT_REPAY_AMOUNT))
        .to.emit(market, EVENT_NAME_HOOK_CALL_RESULT)
        .withArgs(true);

      expect(await liquidityPool.getTokenBalance(creditLineAddress)).to.eq(DEFAULT_REPAY_AMOUNT);
    });

    it("Is reverted if contract is paused", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);
      await proveTx(liquidityPool.pause());

      await expect(market.callOnAfterLoanPayment(liquidityPoolAddress, DEFAULT_LOAN_ID, DEFAULT_REPAY_AMOUNT))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_ALREADY_PAUSED);
    });

    it("Is reverted if the caller is not the market", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect(liquidityPool.onAfterLoanPayment(DEFAULT_LOAN_ID, DEFAULT_REPAY_AMOUNT))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_UNAUTHORIZED);
    });
  });

  describe("Function 'getTokenBalance()'", async () => {
    it("Returns correct value for credit line balance", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);
      await proveTx(liquidityPool.deposit(creditLineAddress, DEPOSIT_AMOUNT));

      expect(await liquidityPool.getTokenBalance(creditLineAddress)).to.eq(DEPOSIT_AMOUNT);
    });

    it("Returns correct value for toke balance", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);
      await proveTx((token.connect(lender) as Contract).transfer(liquidityPoolAddress, DEPOSIT_AMOUNT));

      expect(await liquidityPool.getTokenBalance(tokenAddress)).to.eq(DEPOSIT_AMOUNT);
    });

    it("Returns correct value if balance is zero", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      expect(await liquidityPool.getTokenBalance(ZERO_ADDRESS)).to.eq(0);
    });
  });
});