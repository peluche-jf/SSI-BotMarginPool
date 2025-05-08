const hre = require("hardhat");

async function main() {
  const LPManager = await hre.ethers.getContractFactory("LPManager");
  const lpManager = await LPManager.deploy();

  await lpManager.waitForDeployment();

  console.log("LPManager deployed to:", await lpManager.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 