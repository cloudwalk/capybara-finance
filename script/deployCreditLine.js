const { ethers, upgrades } = require("hardhat");

async function main() {
  const MARKET = "";
  const LENDER = "";
  const TOKEN = "";

  const factory = await ethers.getContractFactory("CreditLineConfigurableUUPS");
  const proxy = await upgrades.deployProxy(factory, [MARKET, LENDER, TOKEN]);
  await proxy.waitForDeployment();

  console.log("Proxy deployed to:", await proxy.getAddress());
}

main();
