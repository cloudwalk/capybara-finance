import { ethers } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory} from "ethers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

const ERROR_NAME_NOT_IMPLEMENTED = "NotImplemented";

describe("Contract 'CreditLineMock'", async () => {
  let creditLineFactory: ContractFactory;

  before(async () => {
    creditLineFactory = await ethers.getContractFactory("CreditLineMock");
  });

  async function deployCreditLine(): Promise<{ creditLine: Contract }> {
    const creditLine = await creditLineFactory.deploy() as Contract;
    await creditLine.waitForDeployment();

    return  {
      creditLine
    }
  }

  describe("Mock functions", async () => {
    it("Function 'market()'", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await expect(creditLine.market())
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_NOT_IMPLEMENTED);
    });

    it("Function 'lender()'", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await expect(creditLine.lender())
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_NOT_IMPLEMENTED);
    });

    it("Function 'kind()'", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      await expect(creditLine.kind())
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_NOT_IMPLEMENTED);
    });
  });
})