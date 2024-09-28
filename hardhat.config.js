require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-solhint");
require("@openzeppelin/hardhat-upgrades");
require("solidity-coverage");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  networks: {
    taiko: {
      url: "https://rpc.mainnet.taiko.xyz/",
      chainId: 167000,
      accounts: process.env.TAIKO_PRIVATE_KEY
        ? [process.env.TAIKO_PRIVATE_KEY]
        : undefined,
      loggingEnabled: true,
    },
  },
  etherscan: {
    apiKey: process.env.TAIKOSCAN_API_KEY,
  },
};
