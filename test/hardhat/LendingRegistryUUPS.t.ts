import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";

const EVENT_NAME_UPGRADED = "Upgraded";

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
    it("Executes as expected and emits correct event", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      expect(await upgrades.upgradeProxy(registry, registryFactory))
        .to.emit(registry, EVENT_NAME_UPGRADED);
    });

    it("Is reverted if caller is not the owner", async () => {
      const { registry } = await loadFixture(deployLendingRegistry);

      registryFactory = registryFactory.connect(attacker);

      await expect(upgrades.upgradeProxy(registry, registryFactory))
        .to.be.revertedWithCustomError(registry, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });
  });
});