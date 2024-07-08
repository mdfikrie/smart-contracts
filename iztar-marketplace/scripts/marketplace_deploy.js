const hre = require("hardhat");

async function main() {
  const paymentContract = "0x3D9A8D241b89AC72b83198CD1F419B7D0c72FAd0";
  const admin = "0xDD53a6681EB233cAD5BA72447161671a56eBa0Cf";
  const feeRecipient = "0xDD53a6681EB233cAD5BA72447161671a56eBa0Cf";
  const signer = "0x307b0C9E88F625bEC47b94ea76D8C1f131d99B1F";
  const fee = BigInt(450);
  const token = await hre.ethers.deployContract("IztarMarketplace", [
    paymentContract,
    admin,
    feeRecipient,
    signer,
    fee,
  ]);
  await token.waitForDeployment();
  console.log("Successfull deployed to: ", token.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
