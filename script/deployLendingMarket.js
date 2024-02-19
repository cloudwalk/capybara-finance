const { ethers, upgrades } = require("hardhat");

async function main() {
  const NAME = "";
  const SYMBOL = "";

  const factory = await ethers.getContractFactory("LendingMarketUUPS");
  const proxy = await upgrades.deployProxy(factory, [NAME, SYMBOL]);
  await proxy.waitForDeployment();

  console.log("Proxy deployed to:", await proxy.getAddress());
}

main();
