import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "tsconfig-paths/register";

require('dotenv').config();

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
export const HARDHAT_DEPLOYER_ADDRESS = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
export const E_ADDRESS = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

export const ARB_TTP = "0x8bAF33E755Ee29E5E37F370a11A0a889DaC5d5f7";
export const AVAX_TTP = "0x69ba883Af416fF5501D54D5e27A1f497fBD97156";
export const BASE_TTP = "0x5505BE604dFA8A1ad402A71f8A357fba47F9bf5a";
export const BSC_TTP = "0x5505BE604dFA8A1ad402A71f8A357fba47F9bf5a";
export const ETH_TTP = "0xF892Fef9dA200d9E84c9b0647ecFF0F34633aBe8";
export const OP_TTP = "0x5505BE604dFA8A1ad402A71f8A357fba47F9bf5a";
export const POL_TTP = "0x542f4FFb7EBBc194cCbFd72ea92199a7f77573d7";

export const ARB_WETH = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1";
export const AVAX_WAVAX = "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7";
export const BASE_WETH = "0x4200000000000000000000000000000000000006";
export const ETH_WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
export const OP_WETH = "0x4200000000000000000000000000000000000006";
export const POL_WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";

export const ETH_UNISWAP_V2_ROUTER = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
export const WOOFI_V2_ROUTER = "0x4c4AF8DBc524681930a27b2F1Af5bcC8062E6fB7"; // verified on arb, avax, base, bsc, eth, op, pol

export const FEE_RECIPIENT_ETH = "0x9F9A7D3e131eD45225396613E383D59a732f7BeB";

export const TC_ROUTER_V4 = "0xD37BbE5744D730a1d98d8DC97c42F0Ca46aD7146";

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

export const ETH_CONFIG = {
  url: `https://mainnet.infura.io/v3/${INFURA_API_KEY}`,
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
    apiKey: ETHERSCAN_API_KEY,
  },
  networks: {
    hardhat: {
      enableTransientStorage: true,
      gasPrice: 74e9
    },
    mainnet: ETH_CONFIG,
    matic: POLYGON_CONFIG,
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
    }, {
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
