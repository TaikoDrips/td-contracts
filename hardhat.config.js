require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-solhint");
require("@openzeppelin/hardhat-upgrades");
require("solidity-coverage");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  networks: {
    mantle: {
      url: "https://rpc-tob.mantle.xyz/v1/ZTZiMWQyNTEwYzU4OTI3MmE4N2MxNzU0",
      chainId: 5000,
      accounts: process.env.TT_TESTNET_PRIVATE_KEY
        ? [process.env.TT_TESTNET_PRIVATE_KEY]
        : undefined,
      loggingEnabled: true,
    },
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
    apiKey: {
      mantle: process.env.MANTLESCAN_API_KEY,
      taiko: process.env.TAIKOSCAN_API_KEY,
    },
    customChains: [
      {
        network: "mantle",
        chainId: 5000,
        urls: {
          apiURL: "https://api.mantlescan.xyz/api",
          browserURL: "https://mantlescan.xyz",
        },
      },
      {
        network: "taiko",
        chainId: 167000,
        urls: {
          apiURL: "https://api.taikoscan.io/api",
          browserURL: "https://taikoscan.io",
        },
      },
    ],
  },
};
