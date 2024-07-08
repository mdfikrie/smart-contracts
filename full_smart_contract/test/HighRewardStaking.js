const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("HighRewardStaking", function () {
  let StakingShip;
  let stakingShip;
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
    // === generate address === //
    [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();
    chainId = await ethers.provider.getNetwork().then((network) => {
      return network.chainId;
    });

    // === deploy iztar token == //
    IztarToken = await ethers.getContractFactory("IztarToken");
    iztarToken = await IztarToken.deploy();
    await iztarToken.waitForDeployment();

    // === deploy iztar ship == //
    IztarShip = await ethers.getContractFactory("IztarShip");
    iztarShip = await IztarShip.deploy();
    await iztarShip.waitForDeployment();

    // === deploy high reward staking == //
    StakingShip = await ethers.getContractFactory("HighRewardStaking");
    stakingShip = await StakingShip.deploy(
      owner.address,
      owner.address,
      BigInt(100000000000000000000),
      BigInt(10)
    );
    await stakingShip.waitForDeployment();
  });

  beforeEach(async function () {
    // === mint token to every address === ///
    await iztarToken.mint(owner.address, balance);
    await iztarToken.mint(addr1.address, balance);
    await iztarToken.mint(addr2.address, balance);
    await iztarToken.mint(stakingShip.target, balance);

    // === mint nft to address === //
    await iztarShip.mint(addr1.address, BigInt(1), "https://uri_url");
    await iztarShip.mint(addr1.address, BigInt(2), "https://uri_url");
    await iztarShip.mint(addr1.address, BigInt(3), "https://uri_url");
  });

  async function stakeShip() {
    // ==== set plan staking ==== //
    let id = BigInt(1);
    let duration = BigInt(86400);
    let apr = BigInt(360);
    await stakingShip.setPlan(id, duration, apr, iztarShip.target);

    // === set signer === //
    let wallet = ethers.Wallet.createRandom();
    await stakingShip.setSigner(wallet.address);

    let tokenIds = [BigInt(1), BigInt(2)];
    let amount = BigInt(200 * 1e18);
    let time = 1799792239;
    let nonce = BigInt(1);

    // === generate signature === //
    let messageHash = await stakingShip.getMessageHash(
      addr1.address,
      tokenIds,
      amount,
      iztarShip.target,
      iztarToken.target,
      id,
      time,
      nonce,
      chainId
    );

    // === Sign message hash === //
    let signature = await wallet.signMessage(ethers.toBeArray(messageHash));

    // === approve token and nft to stake === //
    await iztarToken
      .connect(addr1)
      .approve(stakingShip.target, BigInt(200 * 1e18));
    await iztarShip.connect(addr1).setApprovalForAll(stakingShip.target, true);

    // === stake ==== //
    await stakingShip
      .connect(addr1)
      .stake(
        addr1.address,
        tokenIds,
        amount,
        iztarShip.target,
        iztarToken.target,
        id,
        time,
        nonce,
        chainId,
        signature
      );

    // === expected results === //
    let staking = await stakingShip.getStaking(addr1.address, id);
    expect(staking[1]).to.greaterThanOrEqual(0);
  }

  it("Should stake nft + token", async function () {
    await stakeShip();
  });

  it("Set staking plan", async function () {
    // === create plan === //
    let id = BigInt(1);
    let duration = BigInt(86400);
    let apr = BigInt(20);
    await stakingShip.setPlan(id, duration, apr, iztarShip.target);

    const plan = await stakingShip.getPlan(id);
    expect(plan[1]).to.equal(apr);
  });

  it("Should claim reward", async function () {
    // === create staking === //
    await stakeShip();

    // === time manipulation so 1 day passed === //
    await ethers.provider.send("evm_increaseTime", [86500]);
    await ethers.provider.send("evm_mine");

    // === claim reward === //
    let id = BigInt(1);
    let balanceBeforeClaim = await iztarToken.balanceOf(addr1.address);
    await stakingShip.connect(addr1).claimReward(id, iztarToken.target);
    let balanceAfterClaim = await iztarToken.balanceOf(addr1.address);
    expect(balanceAfterClaim).to.greaterThanOrEqual(balanceBeforeClaim);
  });

  it("Should unstake staking", async function () {
    // === create staking === //
    await stakeShip();

    // === time manipulation so 1 day passed === //
    await ethers.provider.send("evm_increaseTime", [86500]);
    await ethers.provider.send("evm_mine");

    // === unstake === //
    let id = BigInt(1);
    let balanceBeforeClaim = await iztarToken.balanceOf(addr1.address);
    await stakingShip.connect(addr1).unstake(id, iztarToken.target);
    let balanceAfterClaim = await iztarToken.balanceOf(addr1.address);
    expect(balanceAfterClaim).to.greaterThanOrEqual(balanceBeforeClaim);
  });

  it("Should cancel stake by admin", async function () {
    // === create staking === //
    await stakeShip();

    // === cancel stake === //
    let id = BigInt(1);
    let balanceBeforeClaim = await iztarToken.balanceOf(addr1.address);
    await stakingShip.cancelStakeByAdmin(addr1.address, id, iztarToken.target);
    let balanceAfterClaim = await iztarToken.balanceOf(addr1.address);
    expect(balanceAfterClaim).to.greaterThanOrEqual(balanceBeforeClaim);
  });

  it("Should be withdraw token", async function () {
    const amount = BigInt(100 * 1e18);
    await stakingShip.withDraw(amount, iztarToken.target);
    expect(await iztarToken.balanceOf(stakingShip.target)).to.equal(
      balance - amount
    );
  });
});
