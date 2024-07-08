const hre = require("hardhat");

async function main() {
  const tokenContract = "0x3D9A8D241b89AC72b83198CD1F419B7D0c72FAd0";
  const apr = BigInt(250);
  const minStake = BigInt(100000000000000000000);
  const maxStake = BigInt(1000000000000000000000);
  const admin = "0xDD53a6681EB233cAD5BA72447161671a56eBa0Cf";
  const signer = "0x307b0C9E88F625bEC47b94ea76D8C1f131d99B1F";

  const staking = await hre.ethers.deployContract("FlexibleStaking", [
    tokenContract,
    apr,
    minStake,
    maxStake,
    admin,
    signer,
  ]);
  await staking.waitForDeployment();
  console.log("Staking token has been deployed to: ", staking.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
