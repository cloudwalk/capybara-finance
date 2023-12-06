// scripts/create-factory.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const REGISTRY = "";
  const Factory = await ethers.getContractFactory("LiquidityPoolFactoryUUPS");
  const factory = await upgrades.deployProxy(Factory, [REGISTRY]);
  await factory.waitForDeployment();
  console.log("Factory deployed to:", await factory.getAddress());
}

main();