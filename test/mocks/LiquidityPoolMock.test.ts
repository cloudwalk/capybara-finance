import { ethers } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import {proveTx} from "../../test-utils/eth";

const ERROR_NAME_NOT_IMPLEMENTED = "NotImplemented";

describe("Contract 'LiquidityPoolMock'", async () => {
  let liquidityPoolFactory: ContractFactory;

  let deployer: HardhatEthersSigner;
  let token: HardhatEthersSigner;

  before(async () => {
    [deployer, token] = await ethers.getSigners();

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

  describe("Unimplemented mock functions are reverted as expected", async () => {
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
  });

  describe("Interface compatibility functions", async () => {
    it("Function 'token()'", async()  => {
      const { liquidityPool } = await loadFixture(deployLiquidityPool);
      await proveTx(liquidityPool.mockTokenAddress(token.address));

      expect(await liquidityPool.token()).to.eq(token.address);
    });
  });
});
