import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { checkContractUupsUpgrading, connect } from "../../test-utils/eth";
import { setUpFixture } from "../../test-utils/common";

const ERROR_NAME_ACCESS_CONTROL_UNAUTHORIZED = "AccessControlUnauthorizedAccount";

const OWNER_ROLE = ethers.id("OWNER_ROLE");

describe("Contract 'CreditLineConfigurableUUPS'", async () => {
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
      [lender.address, market.address, token.address],
      { kind: "uups" }
    );

    creditLine = connect(creditLine, lender); // Explicitly specifying the initial account

    return {
      creditLine
    };
  }

  describe("Function 'initialize()'", async () => {
    it("Configures the contract as expected", async () => {
      const { creditLine } = await setUpFixture(deployCreditLine);

      expect(await creditLine.hasRole(OWNER_ROLE, lender.address)).to.eq(true);
      expect(await creditLine.market()).to.eq(market.address);
      expect(await creditLine.token()).to.eq(token.address);
    });
  });

  describe("Function 'upgradeToAndCall()'", async () => {
    it("Executes as expected", async () => {
      const { creditLine } = await setUpFixture(deployCreditLine);
      await checkContractUupsUpgrading(creditLine, creditLineFactory);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { creditLine } = await setUpFixture(deployCreditLine);

      await expect(connect(creditLine, attacker).upgradeToAndCall(attacker.address, "0x"))
        .to.be.revertedWithCustomError(creditLine, ERROR_NAME_ACCESS_CONTROL_UNAUTHORIZED)
        .withArgs(attacker.address, OWNER_ROLE);
    });
  });
});