const hre = require("hardhat");

async function main() {
  const box = await hre.ethers.deployContract("IztarBox");
  await box.waitForDeployment();
  console.log("Successfull deployed to: ", box.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
