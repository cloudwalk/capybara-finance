import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";

const EVENT_NAME_UPGRADED = "Upgraded";

describe("Contract 'LiquidityPoolAccountableUUPS'", async () => {
  let liquidityPoolFactory: ContractFactory;

  let liquidityPool: Contract;

  let deployer: HardhatEthersSigner;
  let market: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;

  before(async () => {
    liquidityPoolFactory = await ethers.getContractFactory("LiquidityPoolAccountableUUPS");

    [deployer, market, attacker] = await ethers.getSigners();
  });

  async function deployLiquidityPool(): Promise<{liquidityPool: Contract}> {
    liquidityPool = await upgrades.deployProxy(
      liquidityPoolFactory,
      [market.address, deployer.address],
      {kind: "uups"}
    );

    liquidityPool = liquidityPool.connect(deployer) as Contract;

    return {
      liquidityPool
    }
  }

  describe("Function 'initialize()'", async () => {
    it("Configures contract as expected", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      expect(await liquidityPool.owner()).to.eq(deployer.address);
      expect(await liquidityPool.lender()).to.eq(deployer.address);
      expect(await liquidityPool.market()).to.eq(market.address);
    });
  });

  describe("Function 'upgradeToAndCall()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      expect(await upgrades.upgradeProxy(liquidityPool, liquidityPoolFactory))
        .to.emit(liquidityPool, EVENT_NAME_UPGRADED);
    });

    it("Is reverted if caller is not the owner", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      liquidityPoolFactory = liquidityPoolFactory.connect(attacker);

      await expect(upgrades.upgradeProxy(liquidityPool, liquidityPoolFactory))
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });
  });
});