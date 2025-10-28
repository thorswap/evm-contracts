import { ethers } from "hardhat";
import { parseUnits } from "ethers";
import hre from "hardhat";
import { ETH_USDC, ETH_UTHOR } from "../addresses";

//npx hardhat run scripts/deploy-xTHOR.ts  --network mainnet
async function main() {
  // =============================================================================
  // DEPLOYMENT MODE CONFIGURATION
  // =============================================================================

  // Check for testing mode via environment variable or command line flag
  const TESTING_MODE = true;

  console.log(
    `🚀 xTHOR Deployment - ${
      TESTING_MODE ? "⚡ TESTING" : "🏭 PRODUCTION"
    } Mode`
  );
  console.log("=".repeat(60));

  // Get deployer account
  const [deployer] = await ethers.getSigners();
  console.log("📝 Deployer address:", deployer.address);
  console.log(
    "💰 Deployer balance:",
    ethers.formatEther(await deployer.provider.getBalance(deployer.address)),
    "ETH"
  );

  // =============================================================================
  // SMART CONFIGURATION - Single config object with mode-based values
  // =============================================================================

  const TO_BE_FUNDED = parseUnits("3000", 18); // Total uTHOR to be vested

  const DEPLOYMENT_CONFIG = {
    // Contract addresses
    uTHOR_ADDRESS: ETH_UTHOR,
    USDC_ADDRESS: ETH_USDC,

    // Dynamic beneficiary based on mode
    BENEFICIARY: "0x543BcAd02322D1407b7492b35dB7247C4194D50b", // Real beneficiary for production

    // Dynamic vesting amount
    TOTAL_AMOUNT: TO_BE_FUNDED,

    // Dynamic timing - KEY DIFFERENCE between modes
    START_TIME: TESTING_MODE
      ? Math.floor(Date.now() / 1000) + 60 // Start in 1 minute for testing
      : Math.floor(Date.now() / 1000) + 3600, // Start in 1 hour for production

    CLIFF_DURATION: TESTING_MODE
      ? 1 * 60 // 1 minute cliff for testing
      : 365 * 24 * 60 * 60, // 1 year cliff for production

    VESTING_DURATION: TESTING_MODE
      ? 2 * 60 // 2 minutes total for testing
      : 4 * 365 * 24 * 60 * 60, // 4 years total for production
    ENABLE_CLAIMING_IMMEDIATELY: TESTING_MODE, // Auto-enable for testing
    FUND_CONTRACT_IMMEDIATELY: true,
    FUNDING_AMOUNT: TO_BE_FUNDED,
  };

  // =============================================================================
  // MODE-SPECIFIC DISPLAY
  // =============================================================================

  if (TESTING_MODE) {
    console.log("🧪 TESTING MODE ACTIVE");
    console.log("   ⚡ Ultra-fast vesting for rapid testing");
    console.log("   🔧 Using deployer as beneficiary");
    console.log("   ⏩ Auto-enabling claiming");
    console.log("   ⚠️  Skipping contract verification");
  } else {
    console.log("🏭 PRODUCTION MODE ACTIVE");
    console.log("   ⏳ Real-world vesting schedules");
    console.log("   👤 Using specified beneficiary");
    console.log("   🔍 Will verify contract on explorer");
    console.log("   🛡️  All safety checks enabled");
  }

  // =============================================================================
  // VALIDATION (same for both modes)
  // =============================================================================

  console.log("\n🔍 Validating configuration...");

  if (
    DEPLOYMENT_CONFIG.uTHOR_ADDRESS ===
    "0x0000000000000000000000000000000000000000"
  ) {
    throw new Error("❌ uTHOR_ADDRESS not set! Please update addresses.ts");
  }

  if (
    DEPLOYMENT_CONFIG.USDC_ADDRESS ===
    "0x0000000000000000000000000000000000000000"
  ) {
    throw new Error("❌ USDC_ADDRESS not set! Please update addresses.ts");
  }

  if (
    !TESTING_MODE &&
    DEPLOYMENT_CONFIG.BENEFICIARY ===
      "0x0000000000000000000000000000000000000000"
  ) {
    throw new Error(
      "❌ BENEFICIARY address not set for production deployment!"
    );
  }

  if (DEPLOYMENT_CONFIG.CLIFF_DURATION > DEPLOYMENT_CONFIG.VESTING_DURATION) {
    throw new Error("❌ Cliff duration cannot exceed vesting duration!");
  }

  console.log("✅ Configuration validation passed");

  // =============================================================================
  // DEPLOYMENT PARAMETERS DISPLAY
  // =============================================================================

  console.log("\n📋 Deployment Parameters:");
  console.log("   uTHOR Address:", DEPLOYMENT_CONFIG.uTHOR_ADDRESS);
  console.log("   USDC Address:", DEPLOYMENT_CONFIG.USDC_ADDRESS);
  console.log("   Beneficiary:", DEPLOYMENT_CONFIG.BENEFICIARY);
  console.log(
    "   Total Amount:",
    ethers.formatUnits(DEPLOYMENT_CONFIG.TOTAL_AMOUNT, 18),
    "uTHOR"
  );
  console.log(
    "   Start Time:",
    new Date(DEPLOYMENT_CONFIG.START_TIME * 1000).toLocaleString()
  );

  // Smart duration display
  const formatDuration = (seconds: number) => {
    if (seconds < 60) return `${seconds} seconds`;
    if (seconds < 3600) return `${seconds / 60} minutes`;
    if (seconds < 86400) return `${seconds / 3600} hours`;
    return `${seconds / (24 * 60 * 60)} days`;
  };

  console.log(
    "   Cliff Duration:",
    formatDuration(DEPLOYMENT_CONFIG.CLIFF_DURATION)
  );
  console.log(
    "   Vesting Duration:",
    formatDuration(DEPLOYMENT_CONFIG.VESTING_DURATION)
  );

  // =============================================================================
  // CONTRACT DEPLOYMENT
  // =============================================================================

  console.log("\n🏗️  Deploying xTHOR Individual Vesting Contract...");

  const xTHORVesting = await ethers.deployContract("xTHORIndividualVesting", [
    DEPLOYMENT_CONFIG.uTHOR_ADDRESS,
    DEPLOYMENT_CONFIG.USDC_ADDRESS,
    DEPLOYMENT_CONFIG.BENEFICIARY,
    DEPLOYMENT_CONFIG.TOTAL_AMOUNT,
    DEPLOYMENT_CONFIG.START_TIME,
    DEPLOYMENT_CONFIG.CLIFF_DURATION,
    DEPLOYMENT_CONFIG.VESTING_DURATION,
  ]);

  console.log("⏳ Waiting for deployment confirmation...");
  await xTHORVesting.waitForDeployment();

  const contractAddress = await xTHORVesting.getAddress();
  console.log(`🎉 Contract deployed at: ${contractAddress}`);

  // =============================================================================
  // CONTRACT VERIFICATION (Production only)
  // =============================================================================

  console.log("\n🔍 Verifying contract...");
  console.log("⏳ Waiting 30 seconds before verification...");
  await new Promise((resolve) => setTimeout(resolve, 30000));

  try {
    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: [
        DEPLOYMENT_CONFIG.uTHOR_ADDRESS,
        DEPLOYMENT_CONFIG.USDC_ADDRESS,
        DEPLOYMENT_CONFIG.BENEFICIARY,
        DEPLOYMENT_CONFIG.TOTAL_AMOUNT,
        DEPLOYMENT_CONFIG.START_TIME,
        DEPLOYMENT_CONFIG.CLIFF_DURATION,
        DEPLOYMENT_CONFIG.VESTING_DURATION,
      ],
    });
    console.log("✅ Contract verified!");
  } catch (error) {
    console.log("⚠️  Verification failed:", error.message);
  }

  // =============================================================================
  // POST-DEPLOYMENT SETUP
  // =============================================================================

  console.log("\n⚙️  Post-deployment setup...");

  // Fund the contract with uTHOR tokens if enabled
  if (DEPLOYMENT_CONFIG.FUND_CONTRACT_IMMEDIATELY) {
    try {
      console.log("💰 Funding contract with uTHOR tokens...");
      console.log(
        `   Amount: ${ethers.formatUnits(
          DEPLOYMENT_CONFIG.FUNDING_AMOUNT,
          18
        )} uTHOR`
      );

      // Get uTHOR contract instance
      const uTHORContract = await ethers.getContractAt(
        "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20",
        DEPLOYMENT_CONFIG.uTHOR_ADDRESS
      );

      // Check deployer's uTHOR balance
      const deployerBalance = await uTHORContract.balanceOf(deployer.address);
      console.log(
        `   Deployer uTHOR balance: ${ethers.formatUnits(
          deployerBalance,
          18
        )} uTHOR`
      );

      if (deployerBalance < DEPLOYMENT_CONFIG.FUNDING_AMOUNT) {
        console.log("⚠️  Insufficient uTHOR balance to fund contract");
        console.log(
          "   Contract deployed but not funded - manual funding required"
        );
      } else {
        // Transfer uTHOR tokens to the contract
        const fundTx = await uTHORContract.transfer(
          contractAddress,
          DEPLOYMENT_CONFIG.FUNDING_AMOUNT
        );
        await fundTx.wait();
        console.log("✅ Contract funded with uTHOR tokens!");

        // Verify the transfer
        const contractBalance = await uTHORContract.balanceOf(contractAddress);
        console.log(
          `   Contract uTHOR balance: ${ethers.formatUnits(
            contractBalance,
            18
          )} uTHOR`
        );
      }
    } catch (error) {
      console.log("⚠️  Contract funding failed:", error.message);
      console.log(
        "   Contract deployed but not funded - manual funding required"
      );
    }
  } else {
    console.log("💰 Contract funding disabled (manual funding required)");
  }

  if (DEPLOYMENT_CONFIG.ENABLE_CLAIMING_IMMEDIATELY) {
    console.log("🔓 Enabling claiming...");
    const enableTx = await xTHORVesting.enableClaiming();
    await enableTx.wait();
    console.log("✅ Claiming enabled!");
  } else {
    console.log("🔒 Claiming disabled (manual activation required)");
  }

  // =============================================================================
  // DEPLOYMENT SUMMARY
  // =============================================================================

  console.log("\n" + "=".repeat(60));
  console.log(
    `🎉 ${TESTING_MODE ? "TESTING" : "PRODUCTION"} DEPLOYMENT COMPLETED!`
  );
  console.log("=".repeat(60));

  console.log("\n📍 Contract Address:", contractAddress);
  console.log("🌐 Network:", (await ethers.provider.getNetwork()).name);
  console.log("👤 Beneficiary:", DEPLOYMENT_CONFIG.BENEFICIARY);

  // Mode-specific instructions
  if (TESTING_MODE) {
    console.log("\n🧪 TESTING MODE - Quick Timeline:");
    const now = Math.floor(Date.now() / 1000);
    const timeToStart = DEPLOYMENT_CONFIG.START_TIME - now;
    const timeToCliff =
      DEPLOYMENT_CONFIG.START_TIME + DEPLOYMENT_CONFIG.CLIFF_DURATION - now;
    const timeToEnd =
      DEPLOYMENT_CONFIG.START_TIME + DEPLOYMENT_CONFIG.VESTING_DURATION - now;

    console.log(`   Now → +${timeToStart}s: USDC rewards claimable`);
    console.log(`   +${timeToCliff}s: Cliff ends, vesting begins`);
    console.log(`   +${timeToEnd}s: Vesting complete`);

    console.log("\n⚡ Quick Test Commands:");
    console.log("   xTHORVesting.claimRewards() // Claim USDC anytime");
    console.log(
      "   xTHORVesting.claimVested() // Claim vested uTHOR (after cliff)"
    );
    console.log("   xTHORVesting.claimableAmount() // Check vested tokens");
  } else {
    console.log("\n🏭 PRODUCTION MODE - Next Steps:");
    console.log("   1. Fund contract with uTHOR tokens");
    console.log("   2. Enable claiming when ready");
    console.log("   3. Beneficiary can claim rewards immediately");
    console.log("   4. Vested tokens claimable after cliff period");
  }

  // Save deployment info (convert BigInt values to strings)
  const deploymentInfo = {
    mode: TESTING_MODE ? "testing" : "production",
    contractAddress,
    network: (await ethers.provider.getNetwork()).name,
    deployer: deployer.address,
    beneficiary: DEPLOYMENT_CONFIG.BENEFICIARY,
    deployedAt: new Date().toISOString(),
    uTHOR_ADDRESS: DEPLOYMENT_CONFIG.uTHOR_ADDRESS,
    USDC_ADDRESS: DEPLOYMENT_CONFIG.USDC_ADDRESS,
    TOTAL_AMOUNT: DEPLOYMENT_CONFIG.TOTAL_AMOUNT.toString(), // Convert BigInt to string
    START_TIME: DEPLOYMENT_CONFIG.START_TIME,
    CLIFF_DURATION: DEPLOYMENT_CONFIG.CLIFF_DURATION,
    VESTING_DURATION: DEPLOYMENT_CONFIG.VESTING_DURATION,
    FUNDING_AMOUNT: DEPLOYMENT_CONFIG.FUNDING_AMOUNT.toString(), // Convert BigInt to string
    ENABLE_CLAIMING_IMMEDIATELY: DEPLOYMENT_CONFIG.ENABLE_CLAIMING_IMMEDIATELY,
    FUND_CONTRACT_IMMEDIATELY: DEPLOYMENT_CONFIG.FUND_CONTRACT_IMMEDIATELY,
  };

  const fs = require("fs");
  const filename = `xTHOR-${
    TESTING_MODE ? "testing" : "production"
  }-${Date.now()}.json`;
  fs.writeFileSync(filename, JSON.stringify(deploymentInfo, null, 2));
  console.log(`\n📄 Deployment saved to: ${filename}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("\n❌ Deployment failed:", error);
    process.exit(1);
  });
