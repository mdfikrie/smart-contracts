const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MDToken", function () {
  let MDToken;
  let mdToken;
  let owner;
  let addr1;
  let addr2;
  let addrs;

  beforeEach(async function () {
    MDToken = await ethers.getContractFactory("MDToken");
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    mdToken = await MDToken.deploy();
    await mdToken.waitForDeployment();
  });

  it("Should return the correct name and symbol", async function () {
    expect(await mdToken.name()).to.equal("MD Token");
    expect(await mdToken.symbol()).to.equal("MD");
  });

  it("Should return the correct total supply", async function () {
    const totalSupply = await mdToken.totalSupply();
    expect(totalSupply).to.equal(0); // Because we haven't minted any tokens yet
  });

  it("Should mint tokens", async function () {
    let amount = BigInt(50 * 1e18);
    await mdToken.mint(owner.address, amount);
    const balance = await mdToken.balanceOf(owner.address);
    expect(balance).to.equal(amount);
  });

  it("Should approved tokens", async function () {
    let amount = BigInt(40 * 1e18);
    await mdToken.mint(owner.address, BigInt(50 * 1e18));
    await mdToken.approve(addr1.address, amount);
    expect(await mdToken.allowance(owner.address, addr1.address), true);
  });

  it("Should increase allowance", async function () {
    await mdToken.mint(owner.address, BigInt(100 * 1e18));
    await mdToken.approve(addr1.address, BigInt(5 * 1e18));
    await mdToken.increaseAllowance(addr1.address, BigInt(5 * 1e18));
    let allowance = await mdToken.allowance(owner.address, addr1.address);
    expect(allowance).to.equal(BigInt(10 * 1e18));
  });

  it("Should decrease allowance", async function () {
    await mdToken.mint(owner.address, BigInt(100 * 1e18));
    await mdToken.approve(addr1.address, BigInt(5 * 1e18));
    await mdToken.decreaseAllowance(addr1.address, BigInt(2 * 1e18));
    let allowance = await mdToken.allowance(owner.address, addr1.address);
    expect(allowance).to.equal(BigInt(3 * 1e18));
  });

  it("Should transfer tokens", async function () {
    let amountMint = BigInt(50 * 1e18);
    let transferAmount = BigInt(10 * 1e18);
    await mdToken.mint(owner.address, amountMint);
    await mdToken.transfer(addr1.address, transferAmount);
    const balanceOwner = await mdToken.balanceOf(owner.address);
    const balanceAddress1 = await mdToken.balanceOf(addr1.address);
    expect(balanceOwner).to.equal(BigInt(40 * 1e18));
    expect(balanceAddress1).to.equal(BigInt(10 * 1e18));
  });

  it("Should transferFrom owner to address2 by address1", async function () {
    let amountMint = BigInt(50 * 1e18);
    let transferAmount = BigInt(10 * 1e18);
    await mdToken.mint(owner.address, amountMint);
    await mdToken.approve(addr1.address, transferAmount);
    await mdToken
      .connect(addr1)
      .transferFrom(owner.address, addr2.address, transferAmount);
    const balanceOwner = await mdToken.balanceOf(owner.address);
    const balanceAddress2 = await mdToken.balanceOf(addr2.address);
    expect(balanceOwner).to.equal(BigInt(40 * 1e18));
    expect(balanceAddress2).to.equal(BigInt(10 * 1e18));
  });

  it("Should burn tokens", async function () {
    await mdToken.mint(addr1.address, BigInt(100 * 1e18));
    await mdToken.connect(addr1).burn(BigInt(50 * 1e18));
    const totalSupply = await mdToken.totalSupply();
    const balance = await mdToken.balanceOf(addr1.address);
    expect(totalSupply).to.equal(BigInt(50 * 1e18));
    expect(balance).to.equal(BigInt(50 * 1e18));
  });
});
