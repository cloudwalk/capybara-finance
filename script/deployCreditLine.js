// scripts/create-factory.js
const { ethers, upgrades } = require("hardhat");

async function main() {
    const MARKET = "";
    const LENDER = "";
    const TOKEN = "";
    const Factory = await ethers.getContractFactory("CreditLineConfigurableUUPS");
    const factory = await upgrades.deployProxy(Factory, [MARKET, LENDER, TOKEN]);
    await factory.waitForDeployment();
    console.log("Factory deployed to:", await factory.getAddress());
}

main();