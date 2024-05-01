import { ethers, upgrades } from "hardhat";
import { Contract } from "ethers";
import { expect } from "chai";
import { TransactionReceipt, TransactionResponse } from "@ethersproject/abstract-provider";

export async function proveTx(txResponsePromise: Promise<TransactionResponse>): Promise<TransactionReceipt> {
  const txReceipt = await txResponsePromise;
  return txReceipt.wait();
}

export async function checkContractUupsUpgrading(
  contract: Contract,
  newAddress: string
) {
  const contractAddress = await contract.getAddress();
  const oldImplementationAddress = await upgrades.erc1967.getImplementationAddress(contractAddress);

  await proveTx(contract.upgradeToAndCall(newAddress, "0x"));

  const newImplementationAddress = await upgrades.erc1967.getImplementationAddress(contractAddress);
  expect(newImplementationAddress).not.to.eq(ethers.ZeroAddress);
  expect(newImplementationAddress.length).to.eq(ethers.ZeroAddress.length);
  expect(newImplementationAddress).not.to.eq(oldImplementationAddress);
}