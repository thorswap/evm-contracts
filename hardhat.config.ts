import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "tsconfig-paths/register";

require('dotenv').config();

export const TS_DEPLOYER_PK = process.env.TS_DEPLOYER_PRIVATE_KEY || "";
export const TS_DEPLOYER_ADDRESS = process.env.TS_DEPLOYER_PUBLIC_ADDRESS || "";
export const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
export const INFURA_API_KEY = process.env.INFURA_API_KEY || "";

// helpers
export const TTP_AVAX = "0x69ba883Af416fF5501D54D5e27A1f497fBD97156";
export const TTP_BSC = "0x5505BE604dFA8A1ad402A71f8A357fba47F9bf5a";
export const TTP_ETH = "0xF892Fef9dA200d9E84c9b0647ecFF0F34633aBe8";

export const FEE_RECIPIENT_ETH = "0x9F9A7D3e131eD45225396613E383D59a732f7BeB";

export const TC_ROUTER_V4 = "0xD37BbE5744D730a1d98d8DC97c42F0Ca46aD7146";

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
      version: "0.8.17",
      settings: {
        viaIR: true,
        optimizer: {
          enabled: true,
          // details: {
          //   yulDetails: {
          //     optimizerSteps: "u",
          //   },
          // },
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
