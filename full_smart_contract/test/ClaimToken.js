const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ClaimToken", function () {
  let IztarToken;
  let iztarToken;
  let ClaimToken;
  let claimToken;
  let owner;
  let addr1;
  let addrs;
  let balance = BigInt(1000 * 1e18);
  let chainId;

  beforeEach(async function () {
    // === generate address === //
    [owner, addr1, ...addrs] = await ethers.getSigners();
    chainId = await ethers.provider.getNetwork().then((network) => {
      return network.chainId;
    });
    // === deploy iztar token === //
    IztarToken = await ethers.getContractFactory("IztarToken");
    iztarToken = await IztarToken.deploy();
    // === deploy claim token === //
    ClaimToken = await ethers.getContractFactory("ClaimToken");
    claimToken = await ClaimToken.deploy(owner.address, owner.address);
    // === Added token to address === //
    await iztarToken.mint(owner.address, balance);
    await iztarToken.mint(claimToken.target, balance);
  });

  it("Should get balance", async function () {
    let balance = await claimToken.getBalance(iztarToken.target);
    expect(balance).to.equal(BigInt(1000 * 1e18));
  });

  it("Should with draw", async function () {
    // === Run withdraw === //
    await claimToken.withDraw(iztarToken.target, BigInt(500 * 1e18));

    // === Expected result === //
    let claimTokenBalance = await claimToken.getBalance(iztarToken.target);
    let balanceOwner = await iztarToken.balanceOf(owner.address);
    expect(claimTokenBalance).to.equal(BigInt(500 * 1e18));
    expect(balanceOwner).to.equal(BigInt(1500 * 1e18));
  });

  it("Should return the correct admin", async function () {
    await claimToken.setAdminAddress(addr1.address, true);
    let isAdmin = await claimToken.isAdmin(addr1.address);
    expect(isAdmin).to.equal(true);
  });

  it("Should claim token", async function () {
    // === Generate signer with random wallet === //
    const wallet = ethers.Wallet.createRandom();
    await claimToken.setSigner(wallet.address);

    const nonce = BigInt(1);

    // === Generate message hash === //
    let messageHash = await claimToken.getMessageHash(
      addr1.address,
      BigInt(100 * 1e18),
      iztarToken.target,
      1799792239,
      nonce,
      chainId
    );

    // === Sign message hash === //
    let signature = await wallet.signMessage(ethers.toBeArray(messageHash));

    // === Run claim token === //
    await claimToken.claimToken(
      addr1.address,
      BigInt(100 * 1e18),
      iztarToken.target,
      1799792239,
      nonce,
      chainId,
      signature
    );

    // === Expected results === //
    let balanceAddr1 = await iztarToken.balanceOf(addr1.address);
    let balanceContract = await iztarToken.balanceOf(claimToken.target);
    expect(balanceAddr1).to.equal(BigInt(100 * 1e18));
    expect(balanceContract).to.equal(balance - BigInt(100 * 1e18));
  });
});
