import hre, { ethers } from "hardhat";

import { TS_DEPLOYER_ADDRESS } from "../hardhat.config";

async function main() {
  // get deployer
  const accounts = await ethers.getSigners();
  const deployer = accounts.find(
    (account) =>
      account.address.toLowerCase() === TS_DEPLOYER_ADDRESS.toLowerCase()
  );

  if (!deployer) {
    throw new Error("Deployer not found");
}

  // deploy contract
  const CONTRACT_NAME = "yTHOR";
  const CONTRACT_ARGS = [
    "0xa5f2211b9b8170f694421f2046281775e8468044",
    "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    "0xE30c6b39c91A4bb6fD734dae898B63985213032e",
  ];

  const contract = await ethers.deployContract(CONTRACT_NAME, CONTRACT_ARGS);
  await contract.waitForDeployment();
  console.log(`Contract deployed to ${contract.target}`);

  // wait a couple of blocks + time for indexing
  //await new Promise((resolve) => setTimeout(resolve, 15000));
  await hre.run("verify:verify", {
    //contract: "src/contracts/tokens/uTHOR.sol:uTHOR",
    // address: "0xc01eB1392f6d27015105A2Bc60eFf180b01e3D7f", //contract.target,
    address: contract.target, //contract.target,
    constructorArguments: CONTRACT_ARGS,
  });

  console.log("Contract verified");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
