const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("IztarMarketplace", function () {
  let IztarMarketplace;
  let iztarMarketplace;
  let IztarToken;
  let iztarToken;
  let IztarShip;
  let iztarShip;
  let owner;
  let addr1;
  let addr2;
  let addr3;
  let addrs;
  let balance = BigInt(1000 * 1e18);
  let chainId;

  beforeEach(async function () {
    // ===  === //
    // === Generate random address === //
    [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();
    chainId = await ethers.provider.getNetwork().then((network) => {
      return network.chainId;
    });

    // === Deplot iztar token === //
    IztarToken = await ethers.getContractFactory("IztarToken");
    iztarToken = await IztarToken.deploy();
    await iztarToken.waitForDeployment();

    // === Deplot iztar ship nft === //
    IztarShip = await ethers.getContractFactory("IztarShip");
    iztarShip = await IztarShip.deploy();
    await iztarShip.waitForDeployment();

    // === Deploy iztar marketplace === //
    IztarMarketplace = await ethers.getContractFactory("IztarMarketplace");
    const fee = BigInt(450);
    iztarMarketplace = await IztarMarketplace.deploy(
      iztarToken.target,
      owner.address,
      owner.address,
      owner.address,
      fee
    );
    await iztarMarketplace.waitForDeployment();
  });

  beforeEach(async function () {
    // === Adding token iztar === //
    await iztarToken.mint(owner.address, balance);
    await iztarToken.mint(addr1.address, balance);
    await iztarToken.mint(addr2.address, balance);
    await iztarToken.mint(addr3.address, balance);

    // === Adding ship nft === //
    await iztarShip.mint(addr1.address, BigInt(1), "https://www.image.com");
    await iztarShip.mint(addr1.address, BigInt(2), "https://www.image.com");
    await iztarShip.mint(addr1.address, BigInt(3), "https://www.image.com");
  });

  it("Should add admin address", async function () {
    await iztarMarketplace.setAdminAddress(addr1.address);
    expect(await iztarMarketplace.isAdmin(addr1.address)).to.equal(true);
  });

  it("Should remove admin address", async function () {
    await iztarMarketplace.removeAdminAddress(addr1.address);
    expect(await iztarMarketplace.isAdmin(addr1.address)).to.equal(false);
  });

  it("Should change signer address", async function () {
    await iztarMarketplace.setSigner(addr1.address);
    expect(await iztarMarketplace.getSigner()).to.equal(addr1.address);
  });

  it("Should change fee transaction", async function () {
    const _fee = BigInt(50); // 5%
    await iztarMarketplace.setTransactionFee(_fee);
    expect(await iztarMarketplace.transactionFee()).to.equal(_fee);
  });

  it("Should sell nft ship", async function () {
    // === Set signer with random wallet === //
    let wallet = ethers.Wallet.createRandom();
    await iztarMarketplace.setSigner(wallet.address);

    const tokenId = 1;
    const price = BigInt(150 * 1e18);
    const time = 1799792239;

    // === Set approval for all by address1 to marketplace contract === //
    await iztarShip
      .connect(addr1)
      .setApprovalForAll(iztarMarketplace.target, true);

    const nonce = BigInt(1);

    // === Generate message hash === //
    let messageHash = await iztarMarketplace.getMessageHash(
      tokenId,
      addr1.address,
      price,
      iztarShip.target,
      time,
      nonce,
      chainId
    );

    // === Sign message hash === //
    let signature = await wallet.signMessage(ethers.toBeArray(messageHash));

    // === Sell nft ship by address 1 === //
    await iztarMarketplace
      .connect(addr1)
      .sell(
        tokenId,
        addr1.address,
        price,
        iztarShip.target,
        time,
        nonce,
        chainId,
        signature
      );

    // === Expected result === //
    const isExist = await iztarMarketplace.isSell(iztarShip.target, tokenId);
    const ownerNft = await iztarShip.ownerOf(tokenId);
    let nftDetail = await iztarMarketplace.getSellingById(
      iztarShip.target,
      tokenId
    );
    expect(nftDetail[0]).to.equal(addr1.address);
    expect(isExist).to.equal(true);
    expect(ownerNft).to.equal(iztarMarketplace.target);
  });

  it("Should buy nft ship", async function () {
    // === Set signer with random wallet === //
    let wallet = ethers.Wallet.createRandom();
    await iztarMarketplace.setSigner(wallet.address);

    const nonce = BigInt(1);
    const tokenId = 1;
    const price = BigInt(150 * 1e18);
    const time = 1799792239;

    // === Set approval for all by addrs 1 to marketplace contract === //
    await iztarShip
      .connect(addr1)
      .setApprovalForAll(iztarMarketplace.target, true);

    // === Generate message hash === //
    let messageHash = await iztarMarketplace.getMessageHash(
      tokenId,
      addr1.address,
      price,
      iztarShip.target,
      time,
      nonce,
      chainId
    );

    // === Sign message hash === //
    let signature = await wallet.signMessage(ethers.toBeArray(messageHash));

    // === Sell nft by address 1 === //
    await iztarMarketplace
      .connect(addr1)
      .sell(
        tokenId,
        addr1.address,
        price,
        iztarShip.target,
        time,
        nonce,
        chainId,
        signature
      );

    // === Approve the token by address 2 to marketplace contract === //
    await iztarToken.connect(addr2).approve(iztarMarketplace.target, price);

    // === Buy nft from address 1 by address 2 === //
    await iztarMarketplace.connect(addr2).buy(iztarShip.target, tokenId, price);

    // === Expected result === //
    const ownerNft = await iztarShip.ownerOf(tokenId);
    const balanceAddr2 = await iztarToken.balanceOf(addr2.address);
    expect(ownerNft).to.equal(addr2.address);
    expect(balanceAddr2).to.equal(BigInt(1000 * 1e18) - price);
  });

  it("Should cancel sell", async function () {
    // === Set signer with random wallet === //
    let wallet = ethers.Wallet.createRandom();
    await iztarMarketplace.setSigner(wallet.address);

    const nonce = BigInt(1);
    const tokenId = 1;
    const price = BigInt(150 * 1e18);
    const time = 1799792239;

    // === Set approval for all by addrs 1 to marketplace contract === //
    await iztarShip
      .connect(addr1)
      .setApprovalForAll(iztarMarketplace.target, true);

    // === Generate message hash === //
    let messageHash = await iztarMarketplace.getMessageHash(
      tokenId,
      addr1.address,
      price,
      iztarShip.target,
      time,
      nonce,
      chainId
    );

    // === Sign message === //
    let signature = await wallet.signMessage(ethers.toBeArray(messageHash));

    // === Sell nft by address 1 === //
    await iztarMarketplace
      .connect(addr1)
      .sell(
        tokenId,
        addr1.address,
        price,
        iztarShip.target,
        time,
        nonce,
        chainId,
        signature
      );

    // === Cancel sell === //
    await iztarMarketplace.connect(addr1).cancelSell(iztarShip.target, tokenId);

    // === Expected results === //
    const isExist = await iztarMarketplace.isSell(iztarShip.target, tokenId);
    const ownerNft = await iztarShip.ownerOf(tokenId);
    expect(isExist).to.equal(false);
    expect(ownerNft).to.equal(addr1.address);
  });

  it("Should cancel sell by admin", async function () {
    // === Set signer with random wallet === //
    let wallet = ethers.Wallet.createRandom();
    await iztarMarketplace.setSigner(wallet.address);

    const nonce = BigInt(1);
    const tokenId = 1;
    const price = BigInt(150 * 1e18);
    const time = 1799792239;

    // === Set approval for all by addrs 1 to marketplace contract === //
    await iztarShip
      .connect(addr1)
      .setApprovalForAll(iztarMarketplace.target, true);

    // === Generate message hash === //
    let messageHash = await iztarMarketplace.getMessageHash(
      tokenId,
      addr1.address,
      price,
      iztarShip.target,
      time,
      nonce,
      chainId
    );

    // === Sign message hash === //
    let signature = await wallet.signMessage(ethers.toBeArray(messageHash));
    await iztarMarketplace
      .connect(addr1)
      .sell(
        tokenId,
        addr1.address,
        price,
        iztarShip.target,
        time,
        nonce,
        chainId,
        signature
      );

    // === Cancel stake by admin === //
    await iztarMarketplace.cancelSellByAdmin(iztarShip.target, tokenId);

    // === Expected results === //
    const isExist = await iztarMarketplace.isSell(iztarShip.target, tokenId);
    const ownerNft = await iztarShip.ownerOf(tokenId);
    expect(isExist).to.equal(false);
    expect(ownerNft).to.equal(addr1.address);
  });
});
