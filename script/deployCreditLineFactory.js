const { ethers, upgrades } = require("hardhat");

async function main() {
  const REGISTRY = "";

  const factory = await ethers.getContractFactory("CreditLineFactoryUUPS");
  const proxy = await upgrades.deployProxy(factory, [REGISTRY]);
  await proxy.waitForDeployment();

  console.log("Proxy deployed to:", await proxy.getAddress());
}

main();
