import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { getContractAddress } from "@ethersproject/address";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

const ERROR_NAME_ALREADY_INITIALIZED = "InvalidInitialization";
const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";
const ERROR_NAME_UNSUPPORTED_KIND = "UnsupportedKind";

const EVENT_NAME_LIQUIDITY_POOL_CREATED = "LiquidityPoolCreated";

const LIQUIDITY_POOL_KIND = 1;
const UNSUPPORTED_LIQUIDITY_POOL_KIND = 322;
const CREATION_DATA = ethers.encodeBytes32String("random");

describe("Contract 'LiquidityPoolFactory'", async () => {
  let liquidityPoolFactory: ContractFactory;

  let deployer: HardhatEthersSigner;
  let registry: HardhatEthersSigner;
  let market: HardhatEthersSigner;
  let lender: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;

  before(async () => {
    [deployer, registry, market, lender, attacker] = await ethers.getSigners();

    liquidityPoolFactory = await ethers.getContractFactory("LiquidityPoolFactory");
    liquidityPoolFactory = liquidityPoolFactory.connect(deployer); // Explicitly specifying the deployer account
  });

  async function deployLiquidityPoolFactory(): Promise<{ factory: Contract }> {
    let factory = await upgrades.deployProxy(liquidityPoolFactory, [
      registry.address
    ]);

    factory = factory.connect(registry) as Contract; // Explicitly specifying the initial account

    return {
      factory
    };
  }

  describe("Function 'initialize()'", async () => {
    it("Configures the contract as expected", async () => {
      const { factory } = await loadFixture(deployLiquidityPoolFactory);

      expect(await factory.owner()).to.eq(registry.address);
      const supportedKinds = await factory.supportedKinds();
      expect(supportedKinds).to.deep.eq([LIQUIDITY_POOL_KIND]);
    });

    it("Is reverted if called a second time", async () => {
      const { factory } = await loadFixture(deployLiquidityPoolFactory);

      await expect(factory.initialize(registry.address))
        .to.be.revertedWithCustomError(factory, ERROR_NAME_ALREADY_INITIALIZED);
    });
  });

  describe("Function 'createLiquidityPool()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { factory } = await loadFixture(deployLiquidityPoolFactory);
      const factoryAddress = await factory.getAddress();
      const nextNonce = await ethers.provider.getTransactionCount(factoryAddress);

      const expectedLiquidityPoolAddress = getContractAddress({
        from: factoryAddress,
        nonce: nextNonce
      });

      await expect(factory.createLiquidityPool(
        market.address,
        lender.address,
        LIQUIDITY_POOL_KIND,
        CREATION_DATA
      )).to.emit(
        factory,
        EVENT_NAME_LIQUIDITY_POOL_CREATED
      ).withArgs(
        market.address,
        lender.address,
        LIQUIDITY_POOL_KIND,
        expectedLiquidityPoolAddress
      );
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { factory } = await loadFixture(deployLiquidityPoolFactory);

      await expect((factory.connect(attacker) as Contract).createLiquidityPool(
        market.address,
        lender.address,
        LIQUIDITY_POOL_KIND,
        CREATION_DATA
      )).to.be.revertedWithCustomError(factory, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });

    it("Is reverted if the liquidity pool kind is unsupported", async () => {
      const { factory } = await loadFixture(deployLiquidityPoolFactory);

      await expect(factory.createLiquidityPool(
        market.address,
        lender.address,
        UNSUPPORTED_LIQUIDITY_POOL_KIND,
        CREATION_DATA
      )).to.be.revertedWithCustomError(factory, ERROR_NAME_UNSUPPORTED_KIND);
    });
  });
});
