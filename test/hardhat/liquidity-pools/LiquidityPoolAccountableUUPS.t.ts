import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { checkContractUupsUpgrading } from "../../../test-utils/eth";

const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";

describe("Contract 'LiquidityPoolAccountableUUPS'", async () => {
  let liquidityPoolFactory: ContractFactory;

  let deployer: HardhatEthersSigner;
  let market: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;

  before(async () => {
    [deployer, market, attacker] = await ethers.getSigners();

    liquidityPoolFactory = await ethers.getContractFactory("LiquidityPoolAccountableUUPS");
    liquidityPoolFactory = liquidityPoolFactory.connect(deployer); // Explicitly specifying the deployer account
  });

  async function deployLiquidityPool(): Promise<{ liquidityPool: Contract }> {
    let liquidityPool = await upgrades.deployProxy(
      liquidityPoolFactory,
      [market.address, deployer.address],
      { kind: "uups" }
    );

    liquidityPool = liquidityPool.connect(deployer) as Contract; // Explicitly specifying the initial account

    return {
      liquidityPool
    };
  }

  describe("Function 'initialize()'", async () => {
    it("Configures the contract as expected", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      expect(await liquidityPool.owner()).to.eq(deployer.address);
      expect(await liquidityPool.lender()).to.eq(deployer.address);
      expect(await liquidityPool.market()).to.eq(market.address);
    });
  });

  describe("Function 'upgradeToAndCall()'", async () => {
    it("Executes as expected", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);
      await checkContractUupsUpgrading(liquidityPool, liquidityPoolFactory);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect((liquidityPool.connect(attacker) as Contract).upgradeToAndCall(attacker.address, "0x"))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });
  });
});
