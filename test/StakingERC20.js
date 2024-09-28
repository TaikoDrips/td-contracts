const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");
const { ZeroAddress } = require("ethers");

describe("StakingERC20", function () {
  async function deployFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, ...accounts] = await ethers.getSigners();
    const minStake = 1;
    const maxStakeSupply = 1000000;

    const ERC20 = await ethers.getContractFactory("ERC20Mock");
    const Pauser = await ethers.getContractFactory("Pauser");
    const StakingERC20 = await ethers.getContractFactory("StakingERC20");

    const token = await ERC20.deploy("Mock", "MCK");

    const ownerAddress = await owner.getAddress();
    const pauserProxy = await upgrades.deployProxy(Pauser, [
      [ownerAddress, ownerAddress, ownerAddress],
    ]);
    await pauserProxy.waitForDeployment();

    const stakingProxy = await upgrades.deployProxy(StakingERC20, [
      [
        ownerAddress,
        ownerAddress,
        await pauserProxy.getAddress(),
        await token.getAddress(),
        0,
        minStake,
        maxStakeSupply,
        ZeroAddress,
      ],
    ]);

    return {
      token,
      pauser: pauserProxy,
      staking: stakingProxy,
      owner,
      accounts,
      minStake,
      maxStakeSupply,
    };
  }

  describe("Deployment", function () {
    it("should deploy protocol", async function () {
      const { token, pauser, staking, owner } = await loadFixture(
        deployFixture
      );

      // pauser
      expect(
        await pauser.hasRole(await pauser.DEFAULT_ADMIN_ROLE(), owner)
      ).to.equal(true);
      expect(await pauser.hasRole(await pauser.PAUSER_ROLE(), owner)).to.equal(
        true
      );
      expect(
        await pauser.hasRole(await pauser.UNPAUSER_ROLE(), owner)
      ).to.equal(true);

      // staking
      expect(
        await staking.hasRole(await staking.DEFAULT_ADMIN_ROLE(), owner)
      ).to.equal(true);
      expect(
        await staking.hasRole(await staking.STAKING_OPERATOR_ROLE(), owner)
      ).to.equal(true);
      expect(await staking.pauser()).to.equal(pauser);
      expect(await staking.asset()).to.equal(token);
    });
  });

  describe("Deposit", function () {
    it("revert deposit without duration", async function () {
      const { staking } = await loadFixture(deployFixture);
      await expect(staking.deposit(1000)).to.be.revertedWith("Not Allowed");
    });

    it("revert deposit with wrong duration", async function () {
      const { token, staking, accounts } = await loadFixture(deployFixture);

      const [depositor] = accounts;
      await token.connect(depositor).mint(await depositor.getAddress(), 1000);

      await expect(
        staking["deposit(uint256,uint256)"](1000, 10)
      ).to.be.revertedWithCustomError(staking, "DurationNotExpected");
    });

    it("revert deposit with zero amount", async function () {
      const { staking } = await loadFixture(deployFixture);

      await expect(
        staking["deposit(uint256,uint256)"](0, 91)
      ).to.be.revertedWithCustomError(staking, "DepositAmountTooSmall");
    });

    it("revert deposit with high supply amount", async function () {
      const { staking, maxStakeSupply } = await loadFixture(deployFixture);

      await expect(
        staking["deposit(uint256,uint256)"](maxStakeSupply + 1, 91)
      ).to.be.revertedWithCustomError(staking, "DepositOverBond");
    });

    it("should deposit", async function () {
      const duration = 91;
      const amount = 1000;
      const { token, staking, accounts } = await loadFixture(deployFixture);

      const [depositor] = accounts;
      await token.connect(depositor).mint(await depositor.getAddress(), amount);
      await token.connect(depositor).approve(staking, amount);

      await staking
        .connect(depositor)
        ["deposit(uint256,uint256)"](amount, duration);

      const balance = await token.balanceOf(await depositor.getAddress());
      expect(balance).to.equal(0);

      const deposit = await staking.deposited(await depositor.getAddress());
      expect(deposit).to.equal(amount);
    });
  });

  describe("Withdraw", function () {
    it("revert withdrawal of locked assets", async function () {
      const duration = 91;
      const amount = 1000;
      const { token, staking, accounts } = await loadFixture(deployFixture);

      const [depositor] = accounts;
      await token.connect(depositor).mint(await depositor.getAddress(), amount);
      await token.connect(depositor).approve(staking, amount);

      await staking
        .connect(depositor)
        ["deposit(uint256,uint256)"](amount, duration);

      await expect(
        staking
          .connect(depositor)
          ["withdraw(uint256,address)"](amount, depositor)
      ).to.be.revertedWithCustomError(
        staking,
        "InsufficientWithdrawableBalance"
      );
    });

    it("should withdraw", async function () {
      const duration = 91;
      const amount = 1000;
      const { token, staking, accounts } = await loadFixture(deployFixture);

      const [depositor] = accounts;
      await token.connect(depositor).mint(await depositor.getAddress(), amount);
      await token.connect(depositor).approve(staking, amount);

      await staking
        .connect(depositor)
        ["deposit(uint256,uint256)"](amount, duration);

      const latestTime = await time.latest();
      const lockDuration = duration * 24 * 3600;
      await time.increaseTo(latestTime + lockDuration);

      await staking
        .connect(depositor)
        ["withdraw(uint256,address)"](amount, depositor);

      const balance = await token.balanceOf(await depositor.getAddress());
      expect(balance).to.equal(amount);

      const deposit = await staking.deposited(await depositor.getAddress());
      expect(deposit).to.equal(0);
    });
  });
});
