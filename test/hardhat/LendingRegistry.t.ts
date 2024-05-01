import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { proveTx } from "../../test-utils/eth";

const ERROR_NAME_ALREADY_CONFIGURED = "AlreadyConfigured";
const ERROR_NAME_ALREADY_INITIALIZED = "InvalidInitialization";
const ERROR_NAME_CREDIT_LINE_FACTORY_NOT_CONFIGURED = "CreditLineFactoryNotConfigured";
const ERROR_NAME_ENFORCED_PAUSED = "EnforcedPause";
const ERROR_NAME_NOT_PAUSED = "ExpectedPause";
const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";
const ERROR_NAME_LIQUIDITY_POOL_FACTORY_NOT_CONFIGURED = "LiquidityPoolFactoryNotConfigured";
const ERROR_NAME_ZERO_ADDRESS = "ZeroAddress";

const EVENT_NAME_PAUSED = "Paused";
const EVENT_NAME_UNPAUSED = "Unpaused";
const EVENT_NAME_CREDIT_LINE_FACTORY_CHANGED = "CreditLineFactoryChanged";
const EVENT_NAME_LIQUIDITY_POOL_FACTORY_CHANGED = "LiquidityPoolFactoryChanged";
const EVENT_NAME_CREATE_CREDIT_LINE_CALLED = "CreateCreditLineCalled";
const EVENT_NAME_CREATE_LIQUIDITY_POOL_CALLED = "CreateLiquidityPoolCalled";
const EVENT_NAME_REGISTER_CREDIT_LINE_CALLED = "RegisterCreditLineCalled";
const EVENT_NAME_REGISTER_LIQUIDITY_POOL_CALLED = "RegisterLiquidityPoolCalled";

const ZERO_ADDRESS = ethers.ZeroAddress;
const KIND = 1;

describe("Contract 'LendingRegistry'", async () => {
  let marketFactory: ContractFactory;
  let creditLineFactory: ContractFactory;
  let liquidityPoolFactory: ContractFactory;
  let registryFactory: ContractFactory;

  let market: Contract;
  let lineFactory: Contract;
  let poolFactory: Contract;

  let owner: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;
  let token: HardhatEthersSigner;

  let marketAddress: string;
  let lineFactoryAddress: string;
  let poolFactoryAddress: string;

  before(async () => {
    [owner, attacker, token] = await ethers.getSigners();

    // Factories with an explicitly specified deployer account
    marketFactory = await ethers.getContractFactory("LendingMarketMock");
    marketFactory = marketFactory.connect(owner);
    creditLineFactory = await ethers.getContractFactory("CreditLineFactoryMock");
    creditLineFactory = creditLineFactory.connect(owner);
    liquidityPoolFactory = await ethers.getContractFactory("LiquidityPoolFactoryMock");
    liquidityPoolFactory = liquidityPoolFactory.connect(owner);
    registryFactory = await ethers.getContractFactory("LendingRegistry");
    registryFactory = registryFactory.connect(owner);

    market = await marketFactory.deploy() as Contract;
    await market.waitForDeployment();
    market = market.connect(owner) as Contract; // Explicitly specifying the initial account
    marketAddress = await market.getAddress();

    lineFactory = await creditLineFactory.deploy() as Contract;
    await lineFactory.waitForDeployment();
    lineFactory = lineFactory.connect(owner) as Contract; // Explicitly specifying the initial account
    lineFactoryAddress = await lineFactory.getAddress();

    poolFactory = await liquidityPoolFactory.deploy() as Contract;
    await poolFactory.waitForDeployment();
    poolFactory = poolFactory.connect(owner) as Contract; // Explicitly specifying the initial account
    poolFactoryAddress = await poolFactory.getAddress();
  });

  async function deployLendingRegistry(): Promise<{ registry: Contract }> {
    let registry: Contract = await upgrades.deployProxy(registryFactory, [
      marketAddress
    ]);

    await registry.waitForDeployment();
    registry = registry.connect(owner) as Contract; // Explicitly specifying the initial account

    return {
      registry
    };
  }

  describe("Function 'initialize()'", async () => {
    it("Configures the contract as expected", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      expect(await registry.owner()).to.eq(owner.address);
      expect(await registry.market()).to.eq(marketAddress);
    });

    it("Is reverted if the market address is zero", async () => {
      await expect(upgrades.deployProxy(registryFactory, [
        ZERO_ADDRESS
      ])).to.be.revertedWithCustomError(registryFactory, ERROR_NAME_ZERO_ADDRESS);
    });

    it("Is reverted if called a second time", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      await expect(registry.initialize(marketAddress))
        .to.be.revertedWithCustomError(registry, ERROR_NAME_ALREADY_INITIALIZED);
    });
  });

  describe("Function 'pause()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      await expect(registry.pause())
        .to.emit(registry, EVENT_NAME_PAUSED)
        .withArgs(owner.address);
      expect(await registry.paused()).to.eq(true);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      await expect((registry.connect(attacker) as Contract).pause())
        .to.be.revertedWithCustomError(registry, ERROR_NAME_OWNABLE_UNAUTHORIZED)
        .withArgs(attacker.address);
    });

    it("Is reverted if the contract is already paused", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      await proveTx(registry.pause());
      await expect(registry.pause())
        .to.be.revertedWithCustomError(registry, ERROR_NAME_ENFORCED_PAUSED);
    });
  });

  describe("Function 'unpause()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      await proveTx(registry.pause());
      expect(await registry.paused()).to.eq(true);

      await expect(registry.unpause())
        .to.emit(registry, EVENT_NAME_UNPAUSED)
        .withArgs(owner.address);

      expect(await registry.paused()).to.eq(false);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      await expect((registry.connect(attacker) as Contract).unpause())
        .to.be.revertedWithCustomError(registry, ERROR_NAME_OWNABLE_UNAUTHORIZED)
        .withArgs(attacker.address);
    });

    it("Is reverted if the contract is not paused yet", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      await expect(registry.unpause())
        .to.be.revertedWithCustomError(registry, ERROR_NAME_NOT_PAUSED);
    });
  });

  describe("Function 'setCreditLineFactory()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      await expect(registry.setCreditLineFactory(lineFactoryAddress))
        .to.emit(registry, EVENT_NAME_CREDIT_LINE_FACTORY_CHANGED);

      expect(await registry.creditLineFactory()).to.eq(lineFactoryAddress);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      await expect((registry.connect(attacker) as Contract).setCreditLineFactory(lineFactoryAddress))
        .to.be.revertedWithCustomError(registry, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });

    it("Is reverted if credit line factory is already configured", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      await proveTx(registry.setCreditLineFactory(lineFactoryAddress));

      await expect(registry.setCreditLineFactory(lineFactoryAddress))
        .to.be.revertedWithCustomError(registry, ERROR_NAME_ALREADY_CONFIGURED);
    });
  });

  describe("Function 'setLiquidityPoolFactory()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      await expect(registry.setLiquidityPoolFactory(poolFactoryAddress))
        .to.emit(registry, EVENT_NAME_LIQUIDITY_POOL_FACTORY_CHANGED);

      expect(await registry.liquidityPoolFactory()).to.eq(poolFactoryAddress);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      await expect((registry.connect(attacker) as Contract).setLiquidityPoolFactory(poolFactoryAddress))
        .to.be.revertedWithCustomError(registry, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });

    it("Is reverted if the liquidity pool factory is already configured", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      await proveTx(registry.setLiquidityPoolFactory(poolFactoryAddress));

      await expect(registry.setLiquidityPoolFactory(poolFactoryAddress))
        .to.be.revertedWithCustomError(registry, ERROR_NAME_ALREADY_CONFIGURED);
    });
  });

  describe("Function 'createCreditLine()'", async () => {
    it("Executes as expected and emits correct events", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);
      await proveTx(registry.setCreditLineFactory(lineFactoryAddress));

      await expect(registry.createCreditLine(KIND, token.address))
        .to.emit(lineFactory, EVENT_NAME_CREATE_CREDIT_LINE_CALLED)
        .and.to.emit(market, EVENT_NAME_REGISTER_CREDIT_LINE_CALLED);
    });

    it("Is reverted if the contract is paused", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);
      await proveTx(registry.setCreditLineFactory(lineFactoryAddress));
      await proveTx(registry.pause());

      await expect(registry.createCreditLine(KIND, token.address))
        .to.be.revertedWithCustomError(registry, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if a credit line factory is not configured", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      await expect(registry.createCreditLine(KIND, token.address))
        .to.be.revertedWithCustomError(registry, ERROR_NAME_CREDIT_LINE_FACTORY_NOT_CONFIGURED);
    });
  });

  describe("Function 'createLiquidityPool()'", async () => {
    it("Executes as expected and emits correct events", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);
      await proveTx(registry.setLiquidityPoolFactory(poolFactoryAddress));

      await expect(registry.createLiquidityPool(KIND))
        .to.emit(poolFactory, EVENT_NAME_CREATE_LIQUIDITY_POOL_CALLED)
        .and.to.emit(market, EVENT_NAME_REGISTER_LIQUIDITY_POOL_CALLED);
    });

    it("Is reverted if the contract is paused", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);
      await proveTx(registry.setLiquidityPoolFactory(lineFactoryAddress));
      await proveTx(registry.pause());

      await expect(registry.createLiquidityPool(KIND))
        .to.be.revertedWithCustomError(registry, ERROR_NAME_ENFORCED_PAUSED);
    });

    it("Is reverted if a liquidity pool factory is not configured", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      await expect(registry.createLiquidityPool(KIND))
        .to.be.revertedWithCustomError(registry, ERROR_NAME_LIQUIDITY_POOL_FACTORY_NOT_CONFIGURED);
    });
  });
});

