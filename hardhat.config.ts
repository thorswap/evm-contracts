import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "tsconfig-paths/register";

require('dotenv').config();

const TS_DEPLOYER_PK = process.env.TS_DEPLOYER_PRIVATE_KEY || "";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
const INFURA_API_KEY = process.env.INFURA_API_KEY || "";

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
  networks: {
    hardhat: {
      enableTransientStorage: true,
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [TS_DEPLOYER_PK],
    }
  },
  solidity: {
    compilers: [{
      version: "0.8.4",
      settings: {
        metadata: {
          bytecodeHash: "none",
        },
        optimizer: {
          enabled: true,
          runs: 800,
        },
      },
    }, {
      version: "0.8.10",
      settings: {
        optimizer: {
          enabled: true,
          runs: 1000,
        },
      },
    }, {
      version: "0.8.23",
      settings: {
        viaIR: true,
        optimizer: {
          enabled: true,
          details: {
            yulDetails: {
              optimizerSteps: "u",
            },
          },
        },
      },
    }]
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./src/contracts",
    tests: "./test",
  },
};

export default config;
