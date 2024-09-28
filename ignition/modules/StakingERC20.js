const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");
const { ZeroAddress } = require("ethers");

// npx hardhat ignition deploy ignition/modules/StakingERC20.js --network localhost --parameters ignition/parameters.json
module.exports = buildModule("StakingERC20Module", (m) => {
  const token = m.getParameter("token");
  const minStake = m.getParameter("minStake");
  const maxStakeSupply = m.getParameter("maxStakeSupply");
  const allocator = m.getParameter("allocator", ZeroAddress);

  const proxyAdminOwner = m.getAccount(0);

  const pauser = m.contract("Pauser");
  const encodedPauserInitCall = m.encodeFunctionCall(pauser, "initialize", [
    [proxyAdminOwner, proxyAdminOwner, proxyAdminOwner],
  ]);
  const pauserProxy = m.contract(
    "TransparentUpgradeableProxy",
    [pauser, proxyAdminOwner, encodedPauserInitCall],
    { id: "PauserProxy", after: [pauser] }
  );

  const proxyAdminAddress = m.readEventArgument(
    pauserProxy,
    "AdminChanged",
    "newAdmin"
  );
  const proxyAdmin = m.contractAt("ProxyAdmin", proxyAdminAddress);

  const staking = m.contract("StakingERC20");
  const encodedStakingInitCall = m.encodeFunctionCall(staking, "initialize", [
    [
      proxyAdminOwner, // admin
      proxyAdminOwner, // oparetor
      pauserProxy, // pauser
      token, // token
      0, // cooldown
      minStake, // minStake
      maxStakeSupply, // maxStakeSupply
      allocator, // allocator
    ],
  ]);
  const stakingProxy = m.contract(
    "TransparentUpgradeableProxy",
    [staking, proxyAdminOwner, encodedStakingInitCall],
    { id: "StakingERC20Proxy", after: [pauser, staking] }
  );

  return {
    proxyAdmin,
    pauser: pauserProxy,
    pauserImpl: pauser,
    staking: stakingProxy,
    stakingImpl: staking,
  };
});
