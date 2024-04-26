import { ethers } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

const ERROR_NAME_NOT_IMPLEMENTED = "NotImplemented";

describe("Contract 'LiquidityPoolMock'", async () => {
  let liquidityPoolFactory: ContractFactory;

  let deployer: HardhatEthersSigner;

  before(async () => {
    [deployer] = await ethers.getSigners();

    liquidityPoolFactory = await ethers.getContractFactory("LiquidityPoolMock");
    liquidityPoolFactory = liquidityPoolFactory.connect(deployer); // Explicitly specifying the deployer account
  });

  async function deployLiquidityPool(): Promise<{ liquidityPool: Contract }> {
    let liquidityPool = await liquidityPoolFactory.deploy() as Contract;
    await liquidityPool.waitForDeployment();
    liquidityPool = liquidityPool.connect(deployer) as Contract; // Explicitly specifying the initial account

    return {
      liquidityPool
    };
  }

  describe("Mock functions", async () => {
    it("Function 'market()'", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect(liquidityPool.market())
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_NOT_IMPLEMENTED);
    });

    it("Function 'lender()'", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect(liquidityPool.lender())
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_NOT_IMPLEMENTED);
    });

    it("Function 'kind()'", async () => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);

      await expect(liquidityPool.kind())
        .to.be.revertedWithCustomError(liquidityPool, ERROR_NAME_NOT_IMPLEMENTED);
    });
  });
});