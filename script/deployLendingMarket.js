// scripts/create-factory.js
const { ethers, upgrades } = require("hardhat");

async function main() {
    const Factory = await ethers.getContractFactory("LendingMarketUUPS");
    const factory = await upgrades.deployProxy(Factory, ["CapybaraFinance Test", "CAPY_TEST"]);
    await factory.waitForDeployment();
    console.log("Factorytory deployed to:", await factory.getAddress());
}

main();