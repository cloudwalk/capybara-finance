import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";

const EVENT_NAME_UPGRADED = "Upgraded";

const CREDIT_LINE_KIND = 1;

describe("Contract 'CreditLineFactoryUUPS'", async () => {
  let creditLineFactory: ContractFactory;

  let factory: Contract;

  let deployer: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;

  before(async () => {
    [deployer, attacker] = await ethers.getSigners();

    creditLineFactory = await ethers.getContractFactory("CreditLineFactoryUUPS");
    creditLineFactory = creditLineFactory.connect(deployer); // Explicitly specifying the deployer account
  });

  async function deployCreditLineFactory(): Promise<{ factory: Contract }> {
    factory = await upgrades.deployProxy(
      creditLineFactory,
      [deployer.address],
      { kind: "uups" }
    );

    factory = factory.connect(deployer) as Contract; // Explicitly specifying the initial account

    return {
      factory
    };
  }

  describe("Function 'initialize()'", async () => {
    it("Configures contract as expected", async () => {
      const { factory } = await loadFixture(deployCreditLineFactory);

      expect(await factory.owner()).to.eq(deployer.address);
      const supportedKinds = await factory.supportedKinds();
      expect(supportedKinds[0]).to.eq(CREDIT_LINE_KIND);
    });
  });

  describe("Function 'upgradeToAndCall()'", async () => {
    it("Executes as expected and emits correct event", async () => {
      const { factory } = await loadFixture(deployCreditLineFactory);

      expect(await upgrades.upgradeProxy(factory, creditLineFactory))
        .to.emit(factory, EVENT_NAME_UPGRADED);
    });

    it("Is reverted if caller is not the owner", async () => {
      const { factory } = await loadFixture(deployCreditLineFactory);

      creditLineFactory = creditLineFactory.connect(attacker);

      await expect(upgrades.upgradeProxy(factory, creditLineFactory))
        .to.be.revertedWithCustomError(factory, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });
  });
});