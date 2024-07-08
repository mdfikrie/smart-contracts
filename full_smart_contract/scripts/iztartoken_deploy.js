const hre = require("hardhat");

async function main() {
  const token = await hre.ethers.deployContract("IztarToken");
  await token.waitForDeployment();
  console.log("Successfull deployed to: ", token.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
