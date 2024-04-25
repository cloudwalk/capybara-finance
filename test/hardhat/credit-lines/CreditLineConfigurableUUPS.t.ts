import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";

const EVENT_NAME_UPGRADED = "Upgraded";

describe("Contract 'CreditLineFactoryUUPS'", async () => {
  let creditLineFactory: ContractFactory;

  let creditLine: Contract;

  let lender: HardhatEthersSigner;
  let market: HardhatEthersSigner;
  let token: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;

  before(async () => {
    creditLineFactory = await ethers.getContractFactory("CreditLineConfigurableUUPS");

    [lender, market, token, attacker] = await ethers.getSigners();
  });

  async function deployCreditLine(): Promise<{creditLine: Contract}> {
    creditLine = await upgrades.deployProxy(
      creditLineFactory,
      [market.address, lender.address, token.address],
      {kind: "uups"}
    );

    creditLine = creditLine.connect(lender) as Contract;

    return {
      creditLine
    }
  }

  describe("Function 'initialize()'", async () => {
    it("Configures contract as expected", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      expect(await creditLine.owner()).to.eq(lender.address);
      expect(await creditLine.lender()).to.eq(lender.address);
      expect(await creditLine.market()).to.eq(market.address);
      expect(await creditLine.token()).to.eq(token.address);
    });
  });

  describe("Function 'upgradeToAndCall()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      expect(await upgrades.upgradeProxy(creditLine, creditLineFactory))
        .to.emit(creditLine, EVENT_NAME_UPGRADED);
    });

    it("Is reverted if caller is not the owner", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      creditLineFactory = creditLineFactory.connect(attacker);

      await expect(upgrades.upgradeProxy(creditLine, creditLineFactory))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });
  });
});