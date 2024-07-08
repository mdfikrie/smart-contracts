const hre = require("hardhat");

async function main() {
  const tokenContract = "0x3D9A8D241b89AC72b83198CD1F419B7D0c72FAd0";
  const nftContract = "0x91C449C0515f5Cd47d9e850DA36AC1E07122a113";
  const admin = "0xDD53a6681EB233cAD5BA72447161671a56eBa0Cf";
  const signer = "0x307b0C9E88F625bEC47b94ea76D8C1f131d99B1F";
  const tokenPairPership = BigInt(100000000000000000000);
  const maxShip = BigInt(10000000000000000000);
  const staking = await hre.ethers.deployContract("HighRewardStaking", [
    tokenContract,
    nftContract,
    admin,
    signer,
    tokenPairPership,
    maxShip,
  ]);

  await staking.waitForDeployment();
  console.log("Staking ship has been deployed to: ", staking.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
