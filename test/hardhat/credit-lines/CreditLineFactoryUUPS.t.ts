import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { checkContractUupsUpgrading } from "../../../test-utils/eth";

const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";

const CREDIT_LINE_KIND = 1;

describe("Contract 'CreditLineFactoryUUPS'", async () => {
  let factoryForCreditLineFactory: ContractFactory;

  let deployer: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;

  before(async () => {
    [deployer, attacker] = await ethers.getSigners();

    factoryForCreditLineFactory = await ethers.getContractFactory("CreditLineFactoryUUPS");
    // Explicitly specifying the deployer account
    factoryForCreditLineFactory = factoryForCreditLineFactory.connect(deployer);
  });

  async function deployCreditLineFactory(): Promise<{ factory: Contract }> {
    let factory = await upgrades.deployProxy(
      factoryForCreditLineFactory,
      [deployer.address],
      { kind: "uups" }
    );

    factory = factory.connect(deployer) as Contract; // Explicitly specifying the initial account

    return {
      factory
    };
  }

  describe("Function 'initialize()'", async () => {
    it("Configures the contract as expected", async () => {
      const { factory } = await loadFixture(deployCreditLineFactory);

      expect(await factory.owner()).to.eq(deployer.address);
      const supportedKinds = await factory.supportedKinds();
      expect(supportedKinds[0]).to.eq(CREDIT_LINE_KIND);
    });
  });

  describe("Function 'upgradeToAndCall()'", async () => {
    it("Executes as expected", async () => {
      const { factory } = await loadFixture(deployCreditLineFactory);
      await checkContractUupsUpgrading(factory, factoryForCreditLineFactory);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { factory } = await loadFixture(deployCreditLineFactory);

      await expect((factory.connect(attacker) as Contract).upgradeToAndCall(attacker.address, "0x"))
        .to.be.revertedWithCustomError(factory, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });
  });
});
