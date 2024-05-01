import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { checkContractUupsUpgrading } from "../../test-utils/eth";

const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";

const TOKEN_NAME = "TEST";
const TOKEN_SYMBOL = "TST"

describe("Contract 'LendingMarketUUPS'", async () => {
  let marketFactory: ContractFactory;

  let market: Contract;

  let deployer: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;

  before(async () => {
    [deployer, attacker] = await ethers.getSigners();

    marketFactory = await ethers.getContractFactory("LendingMarketUUPS");
    marketFactory = marketFactory.connect(deployer); // Factories with an explicitly specified deployer account
  });

  async function deployLendingMarket(): Promise<{ market: Contract }> {
    market = await upgrades.deployProxy(
      marketFactory,
      [TOKEN_NAME, TOKEN_SYMBOL],
      { kind: "uups" }
    );

    market = market.connect(deployer) as Contract; // Explicitly specifying the initial account

    return {
      market
    };
  }

  describe("Function 'initialize()'", async () => {
    it("Configures contract as expected", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      expect(await market.name()).to.eq(TOKEN_NAME);
      expect(await market.symbol()).to.eq(TOKEN_SYMBOL);
    });
  });

  describe("Upgrading", async () => {
    it("Executes as expected", async () => {
      const { market } = await loadFixture(deployLendingMarket);
      const newContract = await marketFactory.deploy();
      await checkContractUupsUpgrading(market, await newContract.getAddress());
    });

    it("Is reverted if caller is not the owner", async () => {
      const { market } = await loadFixture(deployLendingMarket);

      marketFactory = marketFactory.connect(attacker);

      await expect((market.connect(attacker) as Contract).upgradeToAndCall(attacker.address, "0x"))
        .to.be.revertedWithCustomError(market, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });
  });
});