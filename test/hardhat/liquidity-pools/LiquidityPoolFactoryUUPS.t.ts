import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";

const EVENT_NAME_UPGRADED = "Upgraded";

const LIQUIDITY_POOL_KIND = 1;

describe("Contract 'LiquidityPoolFactoryUUPS'", async () => {
  let liquidityPoolFactory: ContractFactory;

  let factory: Contract;

  let deployer: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;

  before(async () => {
    liquidityPoolFactory = await ethers.getContractFactory("LiquidityPoolFactoryUUPS");

    [deployer, attacker] = await ethers.getSigners();
  });

  async function deployLiquidityPoolFactory(): Promise<{factory: Contract}> {
    factory = await upgrades.deployProxy(
      liquidityPoolFactory,
      [deployer.address],
      {kind: "uups"}
    );

    factory = factory.connect(deployer) as Contract;

    return {
      factory
    }
  }

  describe("Function 'initialize()'", async () => {
    it("Configures contract as expected", async () => {
      const { factory } = await loadFixture(deployLiquidityPoolFactory);

      expect(await factory.owner()).to.eq(deployer.address);
      const supportedKinds = await factory.supportedKinds();
      expect(supportedKinds[0]).to.eq(LIQUIDITY_POOL_KIND);
    });
  });

  describe("Function 'upgradeToAndCall()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { factory } = await loadFixture(deployLiquidityPoolFactory);

      expect(await upgrades.upgradeProxy(factory, liquidityPoolFactory))
        .to.emit(factory, EVENT_NAME_UPGRADED);
    });

    it("Is reverted if caller is not the owner", async () => {
      const { factory } = await loadFixture(deployLiquidityPoolFactory);

      liquidityPoolFactory = liquidityPoolFactory.connect(attacker);

      await expect(upgrades.upgradeProxy(factory, liquidityPoolFactory))
        .to.be.revertedWithCustomError(factory, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });
  });
});