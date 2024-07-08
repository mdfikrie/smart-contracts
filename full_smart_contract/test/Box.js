const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("IztarBox", function () {
  let iztarToken;
  let iztarBox;
  let owner;
  let addr1;
  let recipient;
  let addrs;
  let chainId;

  let balance = BigInt(1000 * 1e18);
  beforeEach(async function () {
    [owner, addr1, recipient, ...addrs] = await ethers.getSigners();
    chainId = await ethers.provider.getNetwork().then((network) => {
      return network.chainId;
    });
    let IztarToken = await ethers.getContractFactory("IztarToken");
    iztarToken = await IztarToken.deploy();
    await iztarToken.waitForDeployment();

    let IztarBox = await ethers.getContractFactory("IztarBox");
    iztarBox = await IztarBox.deploy(owner.address, owner.address);
    await iztarBox.waitForDeployment();

    await iztarToken.mint(owner.address, balance);
    await iztarToken.mint(addr1.address, balance);

    await iztarBox.setBox(BigInt(1), "Free", "Ini adalah box Free");
    await iztarBox.setBox(BigInt(2), "Common", "Ini adalah box Common");
  });

  it("Should remove box", async function () {
    await iztarBox.removeBox(BigInt(1));
    try {
      await iztarBox.getBox(BigInt(1));
    } catch (error) {
      // Expect the error message to contain the expected revert reason
      expect(error.message).to.contain("Box id not found");
    }
  });

  it("Should buy free box and Paid Box", async function () {
    let wallet = ethers.Wallet.createRandom();
    let time = 1799792239;
    await iztarBox.setSigner(wallet.address);
    let boxId = BigInt(1);
    let id = BigInt(1);
    let price = BigInt(0);
    let messageHash = await iztarBox.getBuyBoxMessage(
      id,
      boxId,
      addr1.address,
      price,
      iztarToken.target,
      time,
      chainId
    );
    let signature = wallet.signMessage(ethers.toBeArray(messageHash));
    await iztarBox
      .connect(addr1)
      .buyFreeBox(
        id,
        boxId,
        addr1.address,
        price,
        iztarToken.target,
        time,
        chainId,
        signature
      );
    expect(await iztarBox.ids(id)).to.equal(true);

    let pricePaidBox = BigInt(10 * 1e18);
    let paidBoxId = BigInt(2);
    let paidId = BigInt(2);
    let messageHashPaidBox = await iztarBox.getBuyBoxMessage(
      paidId,
      paidBoxId,
      addr1.address,
      pricePaidBox,
      iztarToken.target,
      time,
      chainId
    );
    let signaturePaidBox = wallet.signMessage(
      ethers.toBeArray(messageHashPaidBox)
    );
    await iztarToken.connect(addr1).approve(iztarBox.target, pricePaidBox);
    await iztarBox
      .connect(addr1)
      .buyPaidBox(
        paidId,
        paidBoxId,
        addr1.address,
        pricePaidBox,
        iztarToken.target,
        time,
        chainId,
        signaturePaidBox
      );
    expect(await iztarBox.ids(paidId)).to.equal(true);
  });
});
