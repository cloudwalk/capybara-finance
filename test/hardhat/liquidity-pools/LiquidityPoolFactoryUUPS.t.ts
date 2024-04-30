import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { checkContractUupsUpgrading } from "../../../test-utils/eth";

const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";

const LIQUIDITY_POOL_KIND = 1;

describe("Contract 'LiquidityPoolFactoryUUPS'", async () => {
  let factoryForLiquidityPoolFactory: ContractFactory;

  let deployer: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;

  before(async () => {
    [deployer, attacker] = await ethers.getSigners();

    factoryForLiquidityPoolFactory = await ethers.getContractFactory("LiquidityPoolFactoryUUPS");
    // Explicitly specifying the deployer account
    factoryForLiquidityPoolFactory = factoryForLiquidityPoolFactory.connect(deployer);
  });

  async function deployLiquidityPoolFactory(): Promise<{ factory: Contract }> {
    let factory = await upgrades.deployProxy(
      factoryForLiquidityPoolFactory,
      [deployer.address],
      { kind: "uups" }
    );

    factory = factory.connect(deployer) as Contract; // Explicitly specifying the initial account

    return {
      factory
    };
  }

  describe("Function 'initialize()'", async () => {
    it("Configures contract as expected", async () => {
      const { factory } = await loadFixture(deployLiquidityPoolFactory);

      expect(await factory.owner()).to.eq(deployer.address);
      const supportedKinds = await factory.supportedKinds();
      expect(supportedKinds[0]).to.eq(LIQUIDITY_POOL_KIND);
    });
  });

  describe("Upgrading", async () => {
    it("Executes as expected", async () => {
      const { factory } = await loadFixture(deployLiquidityPoolFactory);
      await checkContractUupsUpgrading(factory, factoryForLiquidityPoolFactory);
    });

    it("Is reverted if caller is not the owner", async () => {
      const { factory } = await loadFixture(deployLiquidityPoolFactory);

      factoryForLiquidityPoolFactory = factoryForLiquidityPoolFactory.connect(attacker);

      await expect(upgrades.upgradeProxy(factory, factoryForLiquidityPoolFactory))
        .to.be.revertedWithCustomError(factory, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });
  });
});