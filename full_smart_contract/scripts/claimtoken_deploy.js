const hre = require("hardhat");

async function main() {
  const admin = "0xDD53a6681EB233cAD5BA72447161671a56eBa0Cf";
  const signer = "0x307b0C9E88F625bEC47b94ea76D8C1f131d99B1F";
  const paymentAddress = "0x3D9A8D241b89AC72b83198CD1F419B7D0c72FAd0";
  const claimToken = await hre.ethers.deployContract("ClaimToken", [
    admin,
    signer,
    paymentAddress,
  ]);
  await claimToken.waitForDeployment();
  console.log("Successfull deployed to: ", claimToken.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
