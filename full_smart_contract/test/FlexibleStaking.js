const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("FlexibleStaking", function () {
  let StakingToken;
  let stakingToken;
  let IztarToken;
  let iztarToken;
  let owner;
  let addr1;
  let addr2;
  let addr3;
  let addrs;
  let balance = BigInt(1000 * 1e18);
  let balance2 = BigInt(2000 * 1e18);
  const minStake = BigInt(100 * 1e18);
  const maxStake = BigInt(1000 * 1e18);
  const apr = BigInt(365);
  let chainId;

  beforeEach(async function () {
    // === generate address === //
    [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();
    chainId = await ethers.provider.getNetwork().then((network) => {
      return network.chainId;
    });

    // === Deplot iztar token === //
    IztarToken = await ethers.getContractFactory("IztarToken");
    iztarToken = await IztarToken.deploy();
    await iztarToken.waitForDeployment();

    // === Deploy flexible staking === //
    StakingToken = await ethers.getContractFactory("FlexibleStaking");
    stakingToken = await StakingToken.deploy(
      apr,
      iztarToken.target,
      balance,
      minStake,
      maxStake,
      owner.address,
      owner.address
    );
    await stakingToken.waitForDeployment();

    // === Adding amount to the address === //
    await iztarToken.mint(owner.address, balance);
    await iztarToken.mint(addr1.address, balance);
    await iztarToken.mint(addr2.address, balance);
    await iztarToken.mint(stakingToken.target, balance2);
    await iztarToken.approve(stakingToken.target, balance);
  });

  async function stake() {
    let amount = BigInt(500 * 1e18);
    let time = 1799792239;

    // === Set signer with random wallet === //
    let wallet = ethers.Wallet.createRandom();
    await stakingToken.setSigner(wallet.address);
    let nonce = BigInt(1);

    // === Get message hash === //
    let messageHash = await stakingToken.getMessageHash(
      addr1.address,
      amount,
      iztarToken.target,
      time,
      nonce,
      chainId
    );

    // === Sign message hash === //
    let signature = await wallet.signMessage(ethers.toBeArray(messageHash));

    // === Run stake with address 1 === //
    await iztarToken.connect(addr1).approve(stakingToken.target, amount);
    await stakingToken
      .connect(addr1)
      .stake(
        addr1.address,
        amount,
        iztarToken.target,
        time,
        nonce,
        chainId,
        signature
      );
    // === Expected results === //
    const balanceAddr1 = await iztarToken.balanceOf(addr1.address);
    const totalStakedAddr1 = await stakingToken.balanceOf(
      iztarToken.target,
      addr1.address
    );
    expect(balanceAddr1).to.equal(balance - amount);
    expect(totalStakedAddr1).to.equal(amount);
  }

  it("Should always withdraw staked", async function () {
    let amount = BigInt(500 * 1e18);
    let time = 1799792239;

    // === Set signer with random wallet === //
    let wallet = ethers.Wallet.createRandom();
    await stakingToken.setSigner(wallet.address);
    let nonce = BigInt(1);

    // === Get message hash === //
    let messageHash = await stakingToken.getMessageHash(
      addr1.address,
      amount,
      iztarToken.target,
      time,
      nonce,
      chainId
    );

    // === Sign message hash === //
    let signature = await wallet.signMessage(ethers.toBeArray(messageHash));

    // === Run stake with address 1 === //
    await iztarToken.connect(addr1).approve(stakingToken.target, amount);
    await stakingToken
      .connect(addr1)
      .stake(
        addr1.address,
        amount,
        iztarToken.target,
        time,
        nonce,
        chainId,
        signature
      );

    let messageHash2 = await stakingToken.getMessageHash(
      addr2.address,
      amount,
      iztarToken.target,
      time,
      nonce,
      chainId
    );
    let signature2 = await wallet.signMessage(ethers.toBeArray(messageHash2));
    await iztarToken.connect(addr2).approve(stakingToken.target, amount);
    await stakingToken
      .connect(addr2)
      .stake(
        addr2.address,
        amount,
        iztarToken.target,
        time,
        nonce,
        chainId,
        signature2
      );

    const availableReward = await stakingToken.getRewardPool(iztarToken.target);

    try {
      await stakingToken.withDraw(iztarToken.target, availableReward);
    } catch (error) {
      // Expect the error message to contain the expected revert reason
      expect(error.message).to.contain(
        "Amount exceeds the balance limit for withdrawal"
      );
    }

    // === time manipulation so 1 day passed === //
    await ethers.provider.send("evm_increaseTime", [86400]);
    await ethers.provider.send("evm_mine");

    // === Run claim reward === //
    await stakingToken.connect(addr1).claimReward(iztarToken.target);
    // === Expected result === //
    const reward = await stakingToken.rewardClaimed(
      iztarToken.target,
      addr1.address
    );
    expect(reward).to.greaterThanOrEqual(0);

    await stakingToken.connect(addr1).unstake(iztarToken.target, amount);
    await stakingToken.connect(addr2).unstake(iztarToken.target, amount);
  });

  it("Should stake token", async function () {
    await stake();
  });

  it("Should set total reward", async function () {
    await stakingToken.setRewardPool(iztarToken.target, balance);
    expect(await stakingToken.getRewardPool(iztarToken)).to.equals(balance);
  });

  it("Should change signer", async function () {
    // change signer to address 1
    await stakingToken.setSigner(addr1.address);
    // expected result
    expect(await stakingToken.getSigner()).to.equal(addr1.address);
  });

  it("Should get total reward", async function () {
    expect(await stakingToken.getRewardPool(iztarToken.target)).to.equal(
      balance
    );
  });

  it("Should add admin address", async function () {
    await stakingToken.setAdminAddress(addr1.address);
    expect(await stakingToken.isAdmin(addr1.address)).to.equal(true);
  });

  it("Should remove admin address", async function () {
    await stakingToken.removeAdminAddress(addr1.address);
    expect(await stakingToken.isAdmin(addr1.address)).to.equal(false);
  });

  it("Should change minimal stake", async function () {
    const _minStake = BigInt(20 * 1e18);
    await stakingToken.setMinStake(iztarToken.target, _minStake);
    expect(await stakingToken.getMinStake(iztarToken.target)).to.equal(
      _minStake
    );
  });

  it("Should change maximal stake", async function () {
    const _maxStake = BigInt(200 * 1e18);
    await stakingToken.setMaxStake(iztarToken.target, _maxStake);
    expect(await stakingToken.getMaxStake(iztarToken.target)).to.equal(
      _maxStake
    );
  });

  it("Should change apr", async function () {
    const _apr = BigInt(400);
    await stakingToken.setApr(iztarToken.target, _apr);
    expect(await stakingToken.getAPR(iztarToken.target)).to.equal(_apr);
  });

  it("Should with draw token", async function () {
    const amount = BigInt(500 * 1e18);
    await stakingToken.withDraw(iztarToken.target, amount);
    expect(await stakingToken.getRewardPool(iztarToken.target)).to.equal(
      balance
    );
  });

  it("Should unstake token", async function () {
    // user stake 500 token
    await stake();

    // === time manipulation so 1 day passed === //
    await ethers.provider.send("evm_increaseTime", [86400]);
    await ethers.provider.send("evm_mine");

    // === Unstake 25 token by address1 === //
    await stakingToken
      .connect(addr1)
      .unstake(iztarToken.target, BigInt(250 * 1e18));

    // === Expected results === //
    const balanceAddr1 = await iztarToken.balanceOf(addr1.address);
    const totalStakedAddr1 = await stakingToken.balanceOf(
      iztarToken.target,
      addr1.address
    );

    // balance address1 = 500
    // unstake 250 token
    // reward after 1 day = 5
    // so total balance user after unstake is 755
    // and total stake so 250
    expect(balanceAddr1).to.equal(BigInt(755 * 1e18));
    expect(totalStakedAddr1).to.equal(BigInt(250 * 1e18));
  });

  it("Should cancel stake by admin", async function () {
    await stake();

    // === Cancel stake by admin === //
    await stakingToken.cancelStakeByAdmin(
      iztarToken.target,
      addr1.address,
      BigInt(500 * 1e18)
    );

    // === Expected result === //
    expect(
      await stakingToken.balanceOf(iztarToken.target, addr1.address)
    ).to.equal(0);
  });

  it("Should claim reward after 1 day", async function () {
    await stake();

    // === time manipulation so 1 day passed === //
    await ethers.provider.send("evm_increaseTime", [86400]);
    await ethers.provider.send("evm_mine");

    // === Run claim reward === //
    await stakingToken.connect(addr1).claimReward(iztarToken.target);
    // === Expected result === //
    const reward = await stakingToken.rewardClaimed(
      iztarToken.target,
      addr1.address
    );
    expect(reward).to.greaterThanOrEqual(0);
  });

  it("Should claim reward after 2 day", async function () {
    await stake();

    // === time manipulation so 1 day passed === //
    await ethers.provider.send("evm_increaseTime", [172800]);
    await ethers.provider.send("evm_mine");

    // === Run claim reward === //
    await stakingToken.connect(addr1).claimReward(iztarToken.target);
    // === Expected result === //
    const reward = await stakingToken.rewardClaimed(
      iztarToken.target,
      addr1.address
    );
    expect(reward).to.greaterThanOrEqual(0);
  });

  it("Should unstake without reward", async function () {
    let amount = BigInt(500 * 1e18);

    await stake();
    // === time manipulation so 1 day passed === //
    await ethers.provider.send("evm_increaseTime", [172800]);
    await ethers.provider.send("evm_mine");

    // === Run claim reward === //
    await stakingToken
      .connect(addr1)
      .unstakeWithoutRewards(iztarToken.target, amount);
    // === Expected result === //
    const reward = await stakingToken.rewardClaimed(
      iztarToken.target,
      addr1.address
    );
    expect(reward).to.equal(0);
  });

  it("Should restake reward", async function () {
    await stake();

    // === time manipulation so 1 day passed === //
    await ethers.provider.send("evm_increaseTime", [86400]);
    await ethers.provider.send("evm_mine");

    // === Run restake === //
    await stakingToken.connect(addr1).restake(iztarToken.target);

    // === Expected result === //
    const reward = await stakingToken.rewardClaimed(
      iztarToken.target,
      addr1.address
    );
    expect(reward).to.greaterThanOrEqual(0);
  });
});
