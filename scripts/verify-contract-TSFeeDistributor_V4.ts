import hre, { ethers } from "hardhat";

import {
  TS_DEPLOYER_ADDRESS,
  HARDHAT_DEPLOYER_ADDRESS,
} from "../hardhat.config";

// Set the deployed contract address here
const CONTRACT_ADDRESS = "0x771fc437CA3c5EC8D4880bA8efDCaD7d75a713Aa";

const deployerAddress =
  hre.network.name !== "hardhat"
    ? TS_DEPLOYER_ADDRESS
    : HARDHAT_DEPLOYER_ADDRESS;

async function main() {
  if (!CONTRACT_ADDRESS) {
    throw new Error("Please set CONTRACT_ADDRESS in the script");
  }

  console.log("Verifying TSFeeDistributor_V4 contract...");
  console.log("Network:", hre.network.name);
  console.log("Contract Address:", CONTRACT_ADDRESS);

  // Get signer
  const accounts = await ethers.getSigners();
  const signer = accounts.find(
    (account) => account.address.toLowerCase() === deployerAddress.toLowerCase()
  );

  if (!signer) {
    throw new Error("Signer not found");
  }

  // Check if contract exists at address
  const code = await signer.provider.getCode(CONTRACT_ADDRESS);
  if (code === "0x") {
    console.log("❌ No contract found at address:", CONTRACT_ADDRESS);
    console.log("   Make sure you've deployed the contract first using:");
    console.log("   npx hardhat run --network", hre.network.name, "./scripts/deploy-TSFeeDistributor_V4.ts");
    return;
  }

  console.log("✅ Contract exists at address:", CONTRACT_ADDRESS);
  console.log("   Bytecode length:", code.length, "bytes");

  // Try to connect and read basic info
  try {
    const contract = await ethers.getContractAt("TSFeeDistributor_V4", CONTRACT_ADDRESS, signer);
    
    console.log("\n📊 Contract Information:");
    
    // Test basic read operations (V4 doesn't have rewardAmountThreshold)

    try {
      const treasuryBps = await contract.treasuryPreciseBps();
      console.log("  ✅ Treasury BPS:", treasuryBps.toString());
    } catch (e) {
      console.log("  ❌ Could not read treasuryPreciseBps()");
    }

    try {
      const communityBps = await contract.communityPreciseBps();
      console.log("  ✅ Community BPS:", communityBps.toString());
    } catch (e) {
      console.log("  ❌ Could not read communityPreciseBps()");
    }

    try {
      const treasuryWallet = await contract.treasuryWallet();
      console.log("  ✅ Treasury Wallet:", treasuryWallet);
    } catch (e) {
      console.log("  ❌ Could not read treasuryWallet()");
    }

    try {
      const feeAsset = await contract.feeAsset();
      console.log("  ✅ Fee Asset:", feeAsset);
    } catch (e) {
      console.log("  ❌ Could not read feeAsset()");
    }

    try {
      const isOwner = await contract.isOwner(signer.address);
      console.log("  ✅ Is Owner:", isOwner);
    } catch (e) {
      console.log("  ❌ Could not check ownership");
    }

    try {
      const isExecutor = await contract.isExecutor(signer.address);
      console.log("  ✅ Is Executor:", isExecutor);
    } catch (e) {
      console.log("  ❌ Could not check executor status");
    }

    try {
      const pendingDist = await contract.getPendingDistribution();
      console.log("  ✅ Pending Distribution Active:", pendingDist.isActive);
    } catch (e) {
      console.log("  ❌ Could not read pending distribution");
    }

  } catch (error) {
    console.log("❌ Failed to connect to contract as TSFeeDistributor_V4:");
    console.log("   Error:", error.message);
    
    // Try to get contract interface
    try {
      const genericContract = new ethers.Contract(CONTRACT_ADDRESS, [], signer);
      console.log("   Contract exists but interface mismatch");
      console.log("   This might be a different contract or wrong ABI");
    } catch (e) {
      console.log("   Contract connection failed entirely");
    }
  }
}

main()
  .then(() => {
    console.log("\n🔍 Contract verification completed");
  })
  .catch((error) => {
    console.error("\n❌ Verification failed:");
    console.error(error);
    process.exitCode = 1;
  });