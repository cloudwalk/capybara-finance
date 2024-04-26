import { ethers, upgrades } from "hardhat";
import { Contract, ContractFactory } from "ethers";
import { expect } from "chai";
import { TransactionReceipt, TransactionResponse } from "@ethersproject/abstract-provider";

export async function proveTx(txResponsePromise: Promise<TransactionResponse>): Promise<TransactionReceipt> {
  const txReceipt = await txResponsePromise;
  return txReceipt.wait();
}

export async function checkContractUupsUpgrading(
  contract: Contract,
  contractFactory: ContractFactory
) {
  const contractAddress = await contract.getAddress();
  const oldImplementationAddress = await upgrades.erc1967.getImplementationAddress(contractAddress);

  const contractUpgraded: Contract = await upgrades.upgradeProxy(
    contract,
    contractFactory,
    { kind: "uups", redeployImplementation: "always" }
  );
  await contractUpgraded.waitForDeployment();

  const newImplementationAddress = await upgrades.erc1967.getImplementationAddress(contractAddress);
  expect(newImplementationAddress).not.to.eq(ethers.ZeroAddress);
  expect(newImplementationAddress.length).to.eq(ethers.ZeroAddress.length);
  expect(newImplementationAddress).not.to.eq(oldImplementationAddress);
}