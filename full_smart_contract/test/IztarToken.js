const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("IztarToken", function () {
  let IztarToken;
  let iztarToken;
  let owner;
  let addr1;
  let addr2;
  let addrs;

  beforeEach(async function () {
    IztarToken = await ethers.getContractFactory("IztarToken");
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    iztarToken = await IztarToken.deploy();
    await iztarToken.waitForDeployment();
  });

  it("Should return the correct name and symbol", async function () {
    expect(await iztarToken.name()).to.equal("IZTAR");
    expect(await iztarToken.symbol()).to.equal("IZTAR");
  });

  it("Should return the correct total supply", async function () {
    const totalSupply = await iztarToken.totalSupply();
    expect(totalSupply).to.equal(0); // Because we haven't minted any tokens yet
  });

  it("Should mint tokens", async function () {
    let amount = BigInt(50 * 1e18);
    await iztarToken.mint(owner.address, amount);
    const balance = await iztarToken.balanceOf(owner.address);
    expect(balance).to.equal(amount);
  });

  it("Should approved tokens", async function () {
    let amount = BigInt(40 * 1e18);
    await iztarToken.mint(owner.address, BigInt(50 * 1e18));
    await iztarToken.approve(addr1.address, amount);
    expect(await iztarToken.allowance(owner.address, addr1.address), true);
  });

  it("Should increase allowance", async function () {
    await iztarToken.mint(owner.address, BigInt(100 * 1e18));
    await iztarToken.approve(addr1.address, BigInt(5 * 1e18));
    await iztarToken.increaseAllowance(addr1.address, BigInt(5 * 1e18));
    let allowance = await iztarToken.allowance(owner.address, addr1.address);
    expect(allowance).to.equal(BigInt(10 * 1e18));
  });

  it("Should decrease allowance", async function () {
    await iztarToken.mint(owner.address, BigInt(100 * 1e18));
    await iztarToken.approve(addr1.address, BigInt(5 * 1e18));
    await iztarToken.decreaseAllowance(addr1.address, BigInt(2 * 1e18));
    let allowance = await iztarToken.allowance(owner.address, addr1.address);
    expect(allowance).to.equal(BigInt(3 * 1e18));
  });

  it("Should transfer tokens", async function () {
    let amountMint = BigInt(50 * 1e18);
    let transferAmount = BigInt(10 * 1e18);
    await iztarToken.mint(owner.address, amountMint);
    await iztarToken.transfer(addr1.address, transferAmount);
    const balanceOwner = await iztarToken.balanceOf(owner.address);
    const balanceAddress1 = await iztarToken.balanceOf(addr1.address);
    expect(balanceOwner).to.equal(BigInt(40 * 1e18));
    expect(balanceAddress1).to.equal(BigInt(10 * 1e18));
  });

  it("Should transferFrom owner to address2 by address1", async function () {
    let amountMint = BigInt(50 * 1e18);
    let transferAmount = BigInt(10 * 1e18);
    await iztarToken.mint(owner.address, amountMint);
    await iztarToken.approve(addr1.address, transferAmount);
    await iztarToken
      .connect(addr1)
      .transferFrom(owner.address, addr2.address, transferAmount);
    const balanceOwner = await iztarToken.balanceOf(owner.address);
    const balanceAddress2 = await iztarToken.balanceOf(addr2.address);
    expect(balanceOwner).to.equal(BigInt(40 * 1e18));
    expect(balanceAddress2).to.equal(BigInt(10 * 1e18));
  });

  it("Should burn tokens", async function () {
    await iztarToken.mint(addr1.address, BigInt(100 * 1e18));
    await iztarToken.connect(addr1).burn(BigInt(50 * 1e18));
    const totalSupply = await iztarToken.totalSupply();
    const balance = await iztarToken.balanceOf(addr1.address);
    expect(totalSupply).to.equal(BigInt(50 * 1e18));
    expect(balance).to.equal(BigInt(50 * 1e18));
  });
});
