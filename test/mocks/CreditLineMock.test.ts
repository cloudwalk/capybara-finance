import { ethers } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { setUpFixture } from "../../test-utils/common";
import { connect } from "../../test-utils/eth";

const ERROR_NAME_NOT_IMPLEMENTED = "NotImplemented";

describe("Contract 'CreditLineMock'", async () => {
  let creditLineFactory: ContractFactory;

  let deployer: HardhatEthersSigner;

  before(async () => {
    [deployer] = await ethers.getSigners();

    creditLineFactory = await ethers.getContractFactory("CreditLineMock");
    creditLineFactory = creditLineFactory.connect(deployer); // Explicitly specifying the deployer account
  });

  async function deployCreditLine(): Promise<{ creditLine: Contract }> {
    let creditLine = await creditLineFactory.deploy() as Contract;
    await creditLine.waitForDeployment();
    creditLine = connect(creditLine, deployer); // Explicitly specifying the initial account

    return {
      creditLine
    };
  }

  describe("Cover unused functions", async () => {
    it("Function 'token()'", async () => {
      const { creditLine } = await setUpFixture(deployCreditLine);

      expect(await creditLine.token()).to.eq(ethers.ZeroAddress);
    });

    it("Function 'proveCreditLine()'", async () => {
      const { creditLine } = await setUpFixture(deployCreditLine);

      expect(await creditLine.proveCreditLine()).to.exist;
    });
  });

  describe("Unimplemented mock functions are reverted as expected", async () => {
    it("Function 'market()'", async () => {
      const { creditLine } = await setUpFixture(deployCreditLine);

      await expect(creditLine.market())
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_NOT_IMPLEMENTED);
    });

    it("Function 'lender()'", async () => {
      const { creditLine } = await setUpFixture(deployCreditLine);

      await expect(creditLine.lender())
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_NOT_IMPLEMENTED);
    });
  });
});
