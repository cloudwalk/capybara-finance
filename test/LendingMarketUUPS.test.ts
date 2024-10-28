import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { checkContractUupsUpgrading, connect } from "../test-utils/eth";
import { setUpFixture } from "../test-utils/common";

const ERROR_NAME_ACCESS_CONTROL_UNAUTHORIZED = "AccessControlUnauthorizedAccount";

const OWNER_ROLE = ethers.id("OWNER_ROLE");

describe("Contract 'LendingMarketUUPS'", async () => {
  let lendingMarketFactory: ContractFactory;

  let deployer: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;

  before(async () => {
    [deployer, attacker] = await ethers.getSigners();

    lendingMarketFactory = await ethers.getContractFactory("LendingMarketUUPS");
    lendingMarketFactory = lendingMarketFactory.connect(deployer); // Explicitly specifying the deployer account
  });

  async function deployLendingMarket(): Promise<{ lendingMarket: Contract }> {
    let lendingMarket = await upgrades.deployProxy(
      lendingMarketFactory,
      [deployer.address],
      { kind: "uups" }
    );

    lendingMarket = connect(lendingMarket, deployer); // Explicitly specifying the initial account

    return {
      lendingMarket: lendingMarket
    };
  }

  describe("Function 'initialize()'", async () => {
    it("Configures the contract as expected", async () => {
      const { lendingMarket } = await setUpFixture(deployLendingMarket);

      expect(await lendingMarket.hasRole(OWNER_ROLE, deployer.address)).to.eq(true);
    });
  });

  describe("Function 'upgradeToAndCall()'", async () => {
    it("Executes as expected", async () => {
      const { lendingMarket } = await setUpFixture(deployLendingMarket);
      await checkContractUupsUpgrading(lendingMarket, lendingMarketFactory);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { lendingMarket } = await setUpFixture(deployLendingMarket);

      await expect(connect(lendingMarket, attacker).upgradeToAndCall(attacker.address, "0x"))
        .to.be.revertedWithCustomError(lendingMarket, ERROR_NAME_ACCESS_CONTROL_UNAUTHORIZED)
        .withArgs(attacker.address, OWNER_ROLE);
    });
  });
});
