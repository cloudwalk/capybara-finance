// scripts/create-factorytory.js
const { ethers, upgrades } = require("hardhat");

async function main() {
    const MARKET = "";
    const LENDER = "";
    const Factory = await ethers.getContractFactory("LiquidityPoolAccountableUUPS");
    const factorytory = await upgrades.deployProxy(Factory, [MARKET, LENDER]);
    await factorytory.waitForDeployment();
    console.log("Factorytory deployed to:", await factorytory.getAddress());
}

main();