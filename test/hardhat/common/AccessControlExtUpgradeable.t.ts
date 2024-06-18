import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { connect, proveTx } from "../../../test-utils/eth";

const ERROR_NAME_ALREADY_INITIALIZED = "InvalidInitialization";
const ERROR_NAME_ACCESS_CONTROL_UNAUTHORIZED = "AccessControlUnauthorizedAccount";

const ADMIN_ROLE = ethers.id("ADMIN_ROLE");
const TEST_ROLE = ethers.id("TEST_ROLE");

describe("Contract 'AccessControlExtUpgradeable'", async () => {
  let accessControlFactory: ContractFactory;

  let deployer: HardhatEthersSigner;
  let user1: HardhatEthersSigner;
  let user2: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;

  before( async () => {
    [deployer, user1, user2, attacker] = await ethers.getSigners();

    accessControlFactory = await ethers.getContractFactory("AccessControlExtUpgradeableMock");
    accessControlFactory = accessControlFactory.connect(deployer);
  });

  async function deployAccessControl(): Promise<{ accessControl: Contract }> {
    let accessControl = await upgrades.deployProxy(
      accessControlFactory,
      [],
      { kind: "uups" }
    );

    accessControl = connect(accessControl, deployer); // Explicitly specifying the initial account

    return {
      accessControl: accessControl
    };
  }

  describe("Function 'initialize()'", async () => {
    it("Configures contract as expected", async () => {
      const { accessControl } = await loadFixture(deployAccessControl);

      expect(await accessControl.hasRole(ADMIN_ROLE, deployer.address)).to.eq(false);
    });

    it("Is reverted if called second time", async () => {
      const { accessControl } = await loadFixture(deployAccessControl);

      await expect(accessControl.initialize()).to.be.revertedWithCustomError(
        accessControl, ERROR_NAME_ALREADY_INITIALIZED
      );
    });
  });

  describe("Function 'grantRoleBatch'", async () => {
    it("Executes as expected", async () => {
      const { accessControl } = await loadFixture(deployAccessControl);
      const admins = [user1.address, user2.address];

      await proveTx(accessControl.mockRoleAdmin(TEST_ROLE, ADMIN_ROLE));
      await proveTx(accessControl.mockRole(deployer.address, ADMIN_ROLE));

      await proveTx(accessControl.grantRoleBatch(TEST_ROLE, admins));

      for (let i = 0; i < admins.length; i++) {
        expect(await accessControl.hasRole(TEST_ROLE, admins[i])).to.eq(true);
      }
    });

    it("Is reverted if caller is not the role admin", async () => {
      const { accessControl } = await loadFixture(deployAccessControl);
      const admins = [user1.address, user2.address];

      await expect(connect(accessControl, attacker).grantRoleBatch(TEST_ROLE, admins))
        .to.be.revertedWithCustomError(accessControl, ERROR_NAME_ACCESS_CONTROL_UNAUTHORIZED);
    });
  });

  describe("Function 'revokeRoleBatch'", async () => {
    it("Executes as expected", async () => {
      const { accessControl } = await loadFixture(deployAccessControl);
      const admins = [user1.address, user2.address];

      await proveTx(accessControl.mockRoleAdmin(TEST_ROLE, ADMIN_ROLE));
      await proveTx(accessControl.mockRole(deployer.address, ADMIN_ROLE));

      await proveTx(accessControl.grantRoleBatch(TEST_ROLE, admins));

      for (let i = 0; i < admins.length; i++) {
        expect(await accessControl.hasRole(TEST_ROLE, admins[i])).to.eq(true);
      }

      await proveTx(accessControl.revokeRoleBatch(TEST_ROLE, admins));

      for (let i = 0; i < admins.length; i++) {
        expect(await accessControl.hasRole(TEST_ROLE, admins[i])).to.eq(false);
      }
    });

    it("Is reverted if caller is not the role admin", async () => {
      const { accessControl } = await loadFixture(deployAccessControl);
      const admins = [user1.address, user2.address];

      await expect(connect(accessControl, attacker).revokeRoleBatch(TEST_ROLE, admins))
        .to.be.revertedWithCustomError(accessControl, ERROR_NAME_ACCESS_CONTROL_UNAUTHORIZED);
    });
  });
});