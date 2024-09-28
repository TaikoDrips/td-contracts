const { expect } = require("chai");
const { ignition, ethers } = require("hardhat");

const StakingERC20Module = require("../ignition/modules/StakingERC20");

describe("StakingERC20 Proxy", function () {
  describe("Proxy interaction", async function () {
    it("Should be interactable via proxy", async function () {
      const [owner] = await ethers.getSigners();

      const ERC20 = await ethers.getContractFactory("ERC20Mock");
      const token = await ERC20.deploy("Mock", "MCK");
      await token.waitForDeployment();

      const Pauser = await ethers.getContractFactory("Pauser");
      const { pauser: pauserProxy } = await ignition.deploy(
        StakingERC20Module,
        {
          parameters: {
            StakingERC20Module: {
              token: await token.getAddress(),
              minStake: 1,
              maxStakeSupply: 1000000,
            },
          },
        }
      );
      const pauser = Pauser.attach(await pauserProxy.getAddress());

      expect(
        await pauser.hasRole(await pauser.DEFAULT_ADMIN_ROLE(), owner)
      ).to.equal(true);
      expect(await pauser.hasRole(await pauser.PAUSER_ROLE(), owner)).to.equal(
        true
      );
      expect(
        await pauser.hasRole(await pauser.UNPAUSER_ROLE(), owner)
      ).to.equal(true);
    });
  });
});
