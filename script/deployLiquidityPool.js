const { ethers, upgrades } = require("hardhat");

async function main() {
  const MARKET = "";
  const LENDER = "";

  const factory = await ethers.getContractFactory("LiquidityPoolAccountableUUPS");
  const proxy = await upgrades.deployProxy(factory, [MARKET, LENDER]);
  await proxy.waitForDeployment();

  console.log("Proxy deployed to:", await proxy.getAddress());
}

main();
