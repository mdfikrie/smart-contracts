const { ethers } = require("ethers");

const privateKey = "";
const wallet = new ethers.Wallet(privateKey);

const messageHash = "";

async function signMessage() {
  const signature = await wallet.signMessage(ethers.toBeArray(messageHash));
  console.log("Signature:", signature);
}

signMessage();
