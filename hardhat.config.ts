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
