import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { checkContractUupsUpgrading } from "../../test-utils/eth";

const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";

describe("Contract 'LendingRegistryUUPS'", async () => {
  let registryFactory: ContractFactory;

  let registry: Contract;

  let deployer: HardhatEthersSigner;
  let market: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;

  before(async () => {
    [deployer, market, attacker] = await ethers.getSigners();

    registryFactory = await ethers.getContractFactory("LendingRegistryUUPS");
    registryFactory = registryFactory.connect(deployer); // Factories with an explicitly specified deployer account
  });

  async function deployLendingRegistry(): Promise<{ registry: Contract }> {
    registry = await upgrades.deployProxy(
      registryFactory,
      [market.address],
      { kind: "uups" }
    );

    registry = registry.connect(deployer) as Contract; // Explicitly specifying the initial account

    return {
      registry
    };
  }

  describe("Function 'initialize()'", async () => {
    it("Configures contract as expected", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      expect(await registry.owner()).to.eq(deployer.address);
      expect(await registry.market()).to.eq(market.address);
    });
  });

  describe("Function 'upgradeToAndCall()'", async () => {
    it("Executes as expected", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);
      await checkContractUupsUpgrading(registry, registryFactory);
    });

    it("Is reverted if caller is not the owner", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      await expect((registry.connect(attacker) as Contract).upgradeToAndCall(attacker.address, "0x"))
        .to.be.revertedWithCustomError(registry, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });
  });
});