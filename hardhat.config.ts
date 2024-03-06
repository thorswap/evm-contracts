import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "tsconfig-paths/register";

require('dotenv').config();

export const TS_DEPLOYER_PK = process.env.TS_DEPLOYER_PRIVATE_KEY || "";
export const TS_DEPLOYER_ADDRESS = process.env.TS_DEPLOYER_PUBLIC_ADDRESS || "";
export const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
export const INFURA_API_KEY = process.env.INFURA_API_KEY || "";
export const CMC_API_KEY = process.env.CMC_API_KEY || "";

// helpers
export const HARDHAT_DEPLOYER_ADDRESS = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

export const TTP_AVAX = "0x69ba883Af416fF5501D54D5e27A1f497fBD97156";
export const TTP_BSC = "0x5505BE604dFA8A1ad402A71f8A357fba47F9bf5a";
export const TTP_ETH = "0xF892Fef9dA200d9E84c9b0647ecFF0F34633aBe8";

export const WETH_ETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
export const UNISWAP_V2_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";

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
      gasPrice: 74e9
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [TS_DEPLOYER_PK],
    }
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    noColors: false,
    token: "ETH",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
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
          runs: 200,
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
