import hre, { ethers } from "hardhat";

import {
    TS_DEPLOYER_ADDRESS,
    FEE_RECIPIENT_ETH,
    HARDHAT_DEPLOYER_ADDRESS,
    WOOFI_V2_ROUTER,
    OP_TTP,
    OP_WETH
} from "../hardhat.config";

const CONTRACT_NAME = "TSAggregatorWoofi";
const CONTRACT_ARGS = [OP_TTP, OP_WETH, WOOFI_V2_ROUTER];

// const CONTRACT_NAME = "TSAggregatorTokenTransferProxy";
// const CONTRACT_ARGS: any[] = [];

const deployerAddress = hre.network.name !== "hardhat" ? TS_DEPLOYER_ADDRESS : HARDHAT_DEPLOYER_ADDRESS;

async function main() {
    // get deployer
    const accounts = await ethers.getSigners();
    const deployer = accounts.find(account => account.address.toLowerCase() === deployerAddress.toLowerCase());

    if (!deployer) {
        throw new Error("Deployer not found");
    }

    // deploy contract
    const contract = await ethers.deployContract(CONTRACT_NAME, CONTRACT_ARGS);
    await contract.waitForDeployment();

    console.log(
        `Contract deployed to ${contract.target}`
    );

    // verify contract
    if (hre.network.name !== "hardhat") {
        // wait a couple of blocks + time for indexing
        await new Promise((resolve) => setTimeout(resolve, 15000));
        await hre.run("verify:verify", {
            address: contract.target,
            constructorArguments: CONTRACT_ARGS,
        });
        console.log("Contract verified");
    }

    // optional: invoke methods
    await contract.setFee(15, FEE_RECIPIENT_ETH)
    console.log("Fee set");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});