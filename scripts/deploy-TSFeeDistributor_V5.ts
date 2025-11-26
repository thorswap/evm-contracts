import { network } from "hardhat";
import hre from "hardhat";
import { verifyContract } from "@nomicfoundation/hardhat-verify/verify";
import type { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/types";
import type { TSFeeDistributor_V5 } from "../src/types/index.js";

import {
  TS_DEPLOYER_ADDRESS,
  HARDHAT_DEPLOYER_ADDRESS,
} from "../hardhat.config.js";

import {
  ETH_TC_ROUTER_V4,
  ETH_USDC,
  ETH_TS_TREASURY,
  ETH_THOR,
  ETH_UTHOR,
  ETH_VTHOR,
  ETH_YTHOR,
} from "../addresses.js";

/**
 * Hardhat v3 deployment script for TSFeeDistributor_V5
 *
 * Features:
 * - ESM-compatible imports and exports
 * - Modern async/await patterns
 * - Network-aware deployment address selection
 * - Comprehensive error handling with proper TypeScript typing
 * - Automated executor setup
 * - Deployment verification info (manual verification required)
 *
 * Usage:
 *   npx hardhat run --network mainnet --build-profile production ./scripts/deploy-TSFeeDistributor_V5.ts
 *   (Use production profile to ensure verification compatibility)
 */

// Executor addresses that can call swapToRune() and distribute()
// Add addresses here as needed or set them later via setExecutor()
const ADDITIONAL_EXECUTOR_ADDRESSES: string[] = [];

const CONTRACT_NAME = "TSFeeDistributor_V5" as const;
const CONSTRUCTOR_ARGS = [
  ETH_TC_ROUTER_V4, // _tcRouterAddress
  ETH_USDC, // _feeAsset (USDC)
  ETH_TS_TREASURY, // _treasuryWallet
  ETH_THOR, // _thorToken
  ETH_UTHOR, // _uThorToken
  ETH_VTHOR, // _vThorToken
  ETH_YTHOR, // _yThorToken
] as const;

async function main(): Promise<void> {
  // Connect to network and get ethers instance
  const { ethers, networkName } = await network.connect();


  // Get deployer address based on network
  const networkInfo = await ethers.provider.getNetwork();
  const deployerAddress =
    networkInfo.chainId !== 31337n
      ? TS_DEPLOYER_ADDRESS
      : HARDHAT_DEPLOYER_ADDRESS;

  // Get available signers
  const signers = await ethers.getSigners();
  const deployer = signers.find(
    (signer: HardhatEthersSigner) =>
      signer.address.toLowerCase() === deployerAddress.toLowerCase()
  );

  if (!deployer) {
    throw new Error(`Deployer account not found: ${deployerAddress}`);
  }

  // Network info already available from above

  console.log("🚀 Deploying TSFeeDistributor_V5...");
  console.log(
    "📡 Network:",
    networkName || networkInfo.name || "Unknown",
    `(Chain ID: ${networkInfo.chainId})`
  );
  console.log("👤 Deployer:", deployer.address);
  console.log(
    "💰 Balance:",
    ethers.formatEther(await ethers.provider.getBalance(deployer.address)),
    "ETH"
  );

  const executorAddresses = [deployerAddress, ...ADDITIONAL_EXECUTOR_ADDRESSES];

  // Deploy contract using Hardhat v3 pattern
  const contractFactory = await ethers.getContractFactory(
    CONTRACT_NAME,
    deployer
  );
  const contract = await contractFactory.deploy(...CONSTRUCTOR_ARGS) as unknown as TSFeeDistributor_V5;

  // Wait for deployment transaction to be mined
  await contract.waitForDeployment();
  const contractAddress = await contract.getAddress();

  console.log(`✅ Contract deployed to: ${contractAddress}`);

  // Contract verification (skip for local hardhat network)
  if (networkInfo.chainId !== 31337n) {
    console.log("⏳ Waiting for block confirmations before verification...");
    await new Promise((resolve) => setTimeout(resolve, 15000));

    try {
      console.log("🔍 Verifying contract on Etherscan...");

      await verifyContract(
        {
          address: contractAddress,
          constructorArgs: [...CONSTRUCTOR_ARGS],
          provider: "etherscan",
        },
        hre
      );

      console.log("✅ Contract verified on Etherscan");
      console.log(`🔗 View at: https://etherscan.io/address/${contractAddress}#code`);
    } catch (error) {
      console.warn(
        "⚠️ Verification failed:",
        error instanceof Error ? error.message : String(error)
      );
      console.log(`📋 Contract Address: ${contractAddress}`);
      console.log(`📋 Constructor Args: ${JSON.stringify(CONSTRUCTOR_ARGS)}`);
      console.log("💡 You can verify manually using the above information");
    }
  }

  // Set executor permissions
  console.log("\n🔐 Setting executor permissions...");
  for (let i = 0; i < executorAddresses.length; i++) {
    const executorAddress = executorAddresses[i];
    console.log(
      `⚙️ Setting executor ${i + 1}/${
        executorAddresses.length
      }: ${executorAddress}`
    );

    try {
      const tx = await contract.setExecutor(executorAddress, true);
      await tx.wait();
      console.log(`✅ Executor ${executorAddress} set successfully`);
    } catch (error) {
      console.error(
        `❌ Failed to set executor ${executorAddress}:`,
        error instanceof Error ? error.message : String(error)
      );
    }
  }

  // Display deployment summary
  console.log("\n📊 Deployment Summary:");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log(`📍 Contract Address: ${contractAddress}`);
  console.log(`🌐 Network: Chain ID ${networkInfo.chainId}`);

  try {
    console.log("\n⚙️ Initial Configuration:");
    const treasuryBps = await contract.treasuryPreciseBps();
    const communityBps = await contract.communityPreciseBps();
    const burnBps = await contract.burnPreciseBps();

    console.log(
      `💰 Treasury BPS: ${treasuryBps.toString()} (${
        Number(treasuryBps) / 100000
      }%)`
    );
    console.log(
      `👥 Community BPS: ${communityBps.toString()} (${
        Number(communityBps) / 100000
      }%)`
    );
    console.log(
      `🔥 Burn BPS: ${burnBps.toString()} (${Number(burnBps) / 100000}%)`
    );

    console.log("\n👤 Executor Status:");
    for (const executorAddress of executorAddresses) {
      const isExecutor = await contract.executors(executorAddress);
      const status = isExecutor ? "✅ Active" : "❌ Inactive";
      console.log(`${executorAddress}: ${status}`);
    }
  } catch (error) {
    console.warn(
      "⚠️ Could not fetch contract configuration:",
      error instanceof Error ? error.message : String(error)
    );
  }

  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log("🎉 Deployment completed successfully!");
}

// Execute main function with proper error handling
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(
      "💥 Deployment failed:",
      error instanceof Error ? error.message : String(error)
    );
    process.exit(1);
  });
