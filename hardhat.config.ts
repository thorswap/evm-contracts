import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "tsconfig-paths/register";

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
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
      version: "0.8.6",
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
        optimizer: {
          enabled: true,
          runs: 1000,
        },
      },
    }]
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./src/contracts",
    tests: "./tests",
  },
};

export default config;
