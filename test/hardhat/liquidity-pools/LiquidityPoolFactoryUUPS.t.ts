import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { checkContractUupsUpgrading } from "../../../test-utils/eth";

const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";

const LIQUIDITY_POOL_KIND = 1;

describe("Contract 'LiquidityPoolFactoryUUPS'", async () => {
  let liquidityPoolFactory: ContractFactory;

  let factory: Contract;

  let deployer: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;

  before(async () => {
    [deployer, attacker] = await ethers.getSigners();

    liquidityPoolFactory = await ethers.getContractFactory("LiquidityPoolFactoryUUPS");
    liquidityPoolFactory = liquidityPoolFactory.connect(deployer); // Explicitly specifying the deployer account
  });

  async function deployLiquidityPoolFactory(): Promise<{ factory: Contract }> {
    factory = await upgrades.deployProxy(
      liquidityPoolFactory,
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
      const newContract = await liquidityPoolFactory.deploy();
      await checkContractUupsUpgrading(factory, await newContract.getAddress());
    });

    it("Is reverted if caller is not the owner", async () => {
      const { factory } = await loadFixture(deployLiquidityPoolFactory);

      liquidityPoolFactory = liquidityPoolFactory.connect(attacker);

      await expect((factory.connect(attacker) as Contract).upgradeToAndCall(attacker.address, "0x"))
        .to.be.revertedWithCustomError(factory, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });
  });
});