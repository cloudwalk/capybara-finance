const { ethers, upgrades } = require("hardhat");

async function main() {
  const CONTRACT_NAME = "";
  const PROXY_ADDRESS = "";

  const factory = await ethers.getContractFactory(CONTRACT_NAME);
  const proxy = await upgrades.upgradeProxy(PROXY_ADDRESS, factory);
  await proxy.waitForDeployment();

  console.log("Proxy upgraded");
}

main();
