// scripts/create-factory.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const MARKET = "";
  const Factory = await ethers.getContractFactory("LendingRegistryUUPS");
  const factory = await upgrades.deployProxy(Factory, [MARKET]);
  await factory.waitForDeployment();
  console.log("Factory deployed to:", await factory.getAddress());
}

main();