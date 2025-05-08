require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.30",
  networks: {
    hardhat: {
      chainId: 1337
    },
    polygonZkTestnet: {
      url: "https://rpc.public.zkevm-test.net",
      chainId: 1442,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
    }
  }
};
