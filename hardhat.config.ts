import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "tsconfig-paths/register";

require("dotenv").config();

export const TS_DEPLOYER_PK = process.env.TS_DEPLOYER_PRIVATE_KEY || "";
export const TS_DEPLOYER_ADDRESS = process.env.TS_DEPLOYER_PUBLIC_ADDRESS || "";

export const ARBISCAN_API_KEY = process.env.ARBISCAN_API_KEY || "";
export const BASESCAN_API_KEY = process.env.BASESCAN_API_KEY || "";
export const BSCSCAN_API_KEY = process.env.BSCSCAN_API_KEY || "";
export const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
export const OPSCAN_API_KEY = process.env.OPSCAN_API_KEY || "";
export const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY || "";

export const INFURA_API_KEY = process.env.INFURA_API_KEY || "";
export const CMC_API_KEY = process.env.CMC_API_KEY || "";

// helpers
export const HARDHAT_DEPLOYER_ADDRESS =
  "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
export const E_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

export const AVAX_CONFIG = {
  url: "https://api.avax.network/ext/bc/C/rpc",
  gasPrice: 225000000000,
  chainId: 43114,
  accounts: [TS_DEPLOYER_PK],
};

export const ARB_CONFIG = {
  url: "https://arb1.arbitrum.io/rpc",
  chainId: 42161,
  accounts: [TS_DEPLOYER_PK],
};

export const BASE_CONFIG = {
  url: "https://base.llamarpc.com",
  chainId: 8453,
  accounts: [TS_DEPLOYER_PK],
};

export const BSC_CONFIG = {
  url: "https://bsc-dataseed1.binance.org/",
  chainId: 56,
  accounts: [TS_DEPLOYER_PK],
};

export const ETH_CONFIG = {
  url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
  // url: "https://eth.llamarpc.com",
  chainId: 1,
  accounts: [TS_DEPLOYER_PK],
};

export const POLYGON_CONFIG = {
  url: "https://rpc.ankr.com/polygon",
  chainId: 137,
  accounts: [TS_DEPLOYER_PK],
};

export const OP_CONFIG = {
  url: "https://optimism.llamarpc.com",
  chainId: 10,
  accounts: [TS_DEPLOYER_PK],
};

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  etherscan: {
    apiKey: BASESCAN_API_KEY,
  },
  networks: {
    hardhat: {
      enableTransientStorage: true,
      gasPrice: 10e9,
    },
    mainnet: ETH_CONFIG,
    arbitrum: ARB_CONFIG,
    base: BASE_CONFIG,
    matic: POLYGON_CONFIG,
  },
  gasReporter: {
    enabled: false,
    currency: "USD",
    noColors: false,
    token: "ETH",
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
  },
  solidity: {
    compilers: [
      {
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
      },
      {
        version: "0.8.10",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000,
          },
        },
      },
      {
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
      },
      {
        version: "0.8.22",
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
      },
    ],
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./src/contracts",
    tests: "./test",
  },
};

export default config;
