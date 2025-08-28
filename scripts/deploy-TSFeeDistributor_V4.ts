import hre, { ethers } from "hardhat";

import {
  TS_DEPLOYER_ADDRESS,
  HARDHAT_DEPLOYER_ADDRESS,
} from "../hardhat.config";

import {
  ETH_TC_ROUTER_V4,
  ETH_USDC,
  ETH_TS_TREASURY,
  ETH_THOR,
  ETH_UTHOR,
  ETH_VTHOR,
  ETH_YTHOR,
} from "../addresses";

// Executor addresses that can call swapToRune() and distribute()
// add addresses here as needed or don't if you plan to set them later
const OtherExecutorAddresses: string[] = [];

const CONTRACT_NAME = "TSFeeDistributor_V4";
const CONTRACT_ARGS = [
  ETH_TC_ROUTER_V4, // _tcRouterAddress
  ETH_USDC, // _feeAsset (USDC)
  ETH_TS_TREASURY, // _treasuryWallet
  ETH_THOR, // _thorToken
  ETH_UTHOR, // _uThorToken
  ETH_VTHOR, // _vThorToken
  ETH_YTHOR, // _yThorToken
];

const deployerAddress =
  hre.network.name !== "hardhat"
    ? TS_DEPLOYER_ADDRESS
    : HARDHAT_DEPLOYER_ADDRESS;

async function main() {
  // get deployer
  const accounts = await ethers.getSigners();
  const deployer = accounts.find(
    (account) => account.address.toLowerCase() === deployerAddress.toLowerCase()
  );

  if (!deployer) {
    throw new Error("Deployer not found");
  }

  console.log("Deploying TSFeeDistributor_V4...");
  console.log("Network:", hre.network.name);
  console.log("Deployer:", deployerAddress);
  const EXECUTOR_ADDRESSES = [deployerAddress, ...OtherExecutorAddresses];

  // deploy contract
  const contract = await ethers.deployContract(CONTRACT_NAME, CONTRACT_ARGS);
  await contract.waitForDeployment();

  console.log(`Contract deployed to ${contract.target}`);

  // verify contract
  if (hre.network.name !== "hardhat") {
    // wait a couple of blocks + time for indexing
    await new Promise((resolve) => setTimeout(resolve, 10000));
    await hre.run("verify:verify", {
      address: contract.target,
      constructorArguments: CONTRACT_ARGS,
    });
    console.log("Contract verified");
  }

  // Set executor addresses
  console.log("\nSetting executor addresses...");
  for (let i = 0; i < EXECUTOR_ADDRESSES.length; i++) {
    const executorAddress = EXECUTOR_ADDRESSES[i];
    console.log(
      `Setting executor ${i + 1}/${
        EXECUTOR_ADDRESSES.length
      }: ${executorAddress}`
    );

    const tx = await contract.setExecutor(executorAddress, true);
    await tx.wait();
    console.log(`✅ Executor ${executorAddress} set successfully`);
  }

  // Display initial configuration
  console.log("\nInitial Configuration:");
  console.log("Treasury BPS:", await contract.treasuryPreciseBps());
  console.log("Community BPS:", await contract.communityPreciseBps());

  // Display executor status
  console.log("\nExecutor Status:");
  for (const executorAddress of EXECUTOR_ADDRESSES) {
    const isExecutor = await contract.executors(executorAddress);
    console.log(
      `${executorAddress}: ${isExecutor ? "✅ Executor" : "❌ Not Executor"}`
    );
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
