import {BuidlerConfig, usePlugin} from "@nomiclabs/buidler/config";

usePlugin("@nomiclabs/buidler-waffle");
usePlugin("@nomiclabs/buidler-etherscan");
usePlugin("buidler-typechain");
usePlugin("solidity-coverage");
usePlugin("buidler-gas-reporter");

const INFURA_API_KEY = "";
const KOVAN_PRIVATE_KEY = "";
const ETHERSCAN_API_KEY = "";

const config: BuidlerConfig = {
  defaultNetwork: "buidlerevm",
  solc: {
    version: "0.6.8"
  },
  networks: {
    kovan: {
      url: `https://kovan.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [KOVAN_PRIVATE_KEY]
    },
    coverage: {
      url: "http://127.0.0.1:8555" // Coverage launches its own ganache-cli client
    }
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: ETHERSCAN_API_KEY
  },
  typechain: {
    outDir: "typechain",
    target: "ethers-v5"
  }
};

export default config;
