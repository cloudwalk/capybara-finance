const { ethers, upgrades } = require("hardhat");

async function main() {
  const MARKET = "";

  const factory = await ethers.getContractFactory("LendingRegistryUUPS");
  const proxy = await upgrades.deployProxy(factory, [MARKET]);
  await proxy.waitForDeployment();

  console.log("Proxy deployed to:", await proxy.getAddress());
}

main();
