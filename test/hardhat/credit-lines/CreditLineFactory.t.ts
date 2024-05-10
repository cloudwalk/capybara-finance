import { ethers, upgrades } from "hardhat";
import { expect } from "chai";
import { Contract, ContractFactory } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { getContractAddress } from "@ethersproject/address";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { getAddress } from "../../../test-utils/eth";

const ERROR_NAME_ALREADY_INITIALIZED = "InvalidInitialization";
const ERROR_NAME_OWNABLE_UNAUTHORIZED = "OwnableUnauthorizedAccount";
const ERROR_NAME_UNSUPPORTED_KIND = "UnsupportedKind";

const EVENT_NAME_CREDIT_LINE_CREATED = "CreditLineCreated";

const CREDIT_LINE_KIND = 1;
const UNSUPPORTED_CREDIT_LINE_KIND = 322;
const CREATION_DATA = ethers.encodeBytes32String("random");
const NONCE = 2;

describe("Contract 'CreditLineFactory'", async () => {
  let factoryForCreditLineFactory: ContractFactory;
  let factoryForCreditLine: ContractFactory;

  let deployer: HardhatEthersSigner;
  let registry: HardhatEthersSigner;
  let market: HardhatEthersSigner;
  let lender: HardhatEthersSigner;
  let token: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;

  before(async () => {
    [deployer, registry, market, lender, token, attacker] = await ethers.getSigners();

    factoryForCreditLineFactory = await ethers.getContractFactory("CreditLineFactory");
    // Explicitly specifying the deployer account
    factoryForCreditLineFactory = factoryForCreditLineFactory.connect(deployer);

    factoryForCreditLine = await ethers.getContractFactory("CreditLineConfigurable");
    factoryForCreditLine = factoryForCreditLine.connect(deployer); // Explicitly specifying the deployer account
  });

  async function deployCreditLineFactory(): Promise<{ factory: Contract }> {
    let factory = await upgrades.deployProxy(factoryForCreditLineFactory, [
      registry.address
    ]);

    factory = factory.connect(registry) as Contract; // Explicitly specifying the initial account

    return {
      factory
    };
  }

  describe("Function 'initialize()'", async () => {
    it("Configures the contract as expected", async () => {
      const { factory } = await loadFixture(deployCreditLineFactory);

      expect(await factory.owner()).to.eq(registry.address);
      const supportedKinds = await factory.supportedKinds();
      expect(supportedKinds[0]).to.eq(CREDIT_LINE_KIND);
    });

    it("Is reverted if called a second time", async () => {
      const { factory } = await loadFixture(deployCreditLineFactory);

      await expect(factory.initialize(registry.address))
        .to.be.revertedWithCustomError(factory, ERROR_NAME_ALREADY_INITIALIZED);
    });
  });

  describe("Function 'createCreditLine()'", async () => {
    it("Executes as expected and emits the correct event", async () => {
      const { factory } = await loadFixture(deployCreditLineFactory);

      const expectedCreditLineAddress = getContractAddress({
        from: getAddress(factory),
        nonce: NONCE
      });

      await expect(factory.createCreditLine(
        market.address,
        lender.address,
        token.address,
        CREDIT_LINE_KIND,
        CREATION_DATA
      )).to.emit(
        factory,
        EVENT_NAME_CREDIT_LINE_CREATED
      ).withArgs(
        market.address,
        lender.address,
        token.address,
        CREDIT_LINE_KIND,
        expectedCreditLineAddress
      );

      const creditLine: Contract = factoryForCreditLine.attach(expectedCreditLineAddress) as Contract;
      expect(await creditLine.lender()).to.eq(lender.address);
      expect(await creditLine.owner()).to.eq(lender.address);
      expect(await creditLine.token()).to.eq(token.address);
      expect(await creditLine.market()).to.eq(market.address);
      expect(await creditLine.kind()).to.eq(CREDIT_LINE_KIND);
    });

    it("Is reverted if the caller is not the owner", async () => {
      const { factory } = await loadFixture(deployCreditLineFactory);

      await expect((factory.connect(attacker) as Contract).createCreditLine(
        market.address,
        lender.address,
        token.address,
        CREDIT_LINE_KIND,
        CREATION_DATA
      )).to.be.revertedWithCustomError(factory, ERROR_NAME_OWNABLE_UNAUTHORIZED);
    });

    it("Is reverted if the credit line kind is unsupported", async () => {
      const { factory } = await loadFixture(deployCreditLineFactory);

      await expect(factory.createCreditLine(
        market.address,
        lender.address,
        token.address,
        UNSUPPORTED_CREDIT_LINE_KIND,
        CREATION_DATA
      )).to.be.revertedWithCustomError(factory, ERROR_NAME_UNSUPPORTED_KIND);
    });
  });
});
