import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { checkContractUupsUpgrading } from "../../../test-utils/eth";

const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";

describe("Contract 'CreditLineFactoryUUPS'", async () => {
  let creditLineFactory: ContractFactory;

  let deployer: HardhatEthersSigner;
  let lender: HardhatEthersSigner;
  let market: HardhatEthersSigner;
  let token: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;

  before(async () => {
    [deployer, lender, market, token, attacker] = await ethers.getSigners();

    creditLineFactory = await ethers.getContractFactory("CreditLineConfigurableUUPS");
    creditLineFactory = creditLineFactory.connect(deployer); // Explicitly specifying the deployer account
  });

  async function deployCreditLine(): Promise<{ creditLine: Contract }> {
    let creditLine = await upgrades.deployProxy(
      creditLineFactory,
      [market.address, lender.address, token.address],
      { kind: "uups" }
    );

    creditLine = creditLine.connect(lender) as Contract; // Explicitly specifying the initial account

    return {
      creditLine
    };
  }

  describe("Function 'initialize()'", async () => {
    it("Configures the contract as expected", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      expect(await creditLine.owner()).to.eq(lender.address);
      expect(await creditLine.lender()).to.eq(lender.address);
      expect(await creditLine.market()).to.eq(market.address);
      expect(await creditLine.token()).to.eq(token.address);
    });
  });

  describe("Upgrading", async () => {
    it("Executes as expected", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);
      await checkContractUupsUpgrading(creditLine, creditLineFactory.connect(lender));
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { creditLine } = await loadFixture(deployCreditLine);

      creditLineFactory = creditLineFactory.connect(attacker);

      await expect(upgrades.upgradeProxy(creditLine, creditLineFactory))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });
  });
});