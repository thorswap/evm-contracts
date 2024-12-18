import hre, { ethers } from "hardhat";

import {
    TS_DEPLOYER_ADDRESS,
    HARDHAT_DEPLOYER_ADDRESS,
} from "../hardhat.config";

import { ETH_TTP, ETH_CF_ROUTER, FEE_RECIPIENT_ETH } from "../addresses";

const CONTRACT_NAME = "TSAggregatorChainflip_V1";
const CONTRACT_ARGS = [ETH_TTP, ETH_CF_ROUTER];

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
        await new Promise((resolve) => setTimeout(resolve, 30000));
        await hre.run("verify:verify", {
            address: contract.target,
            constructorArguments: CONTRACT_ARGS,
        });
        console.log("Contract verified");
    }

    // optional: invoke methods
    await contract.setFee(20, FEE_RECIPIENT_ETH)
    await contract.setRevOnAllTokens(true);
    console.log("Fee set");

    await new Promise((resolve) => setTimeout(resolve, 15000));
    await contract.addCfAsset("0xa5f2211B9b8170F694421f2046281775E8468044", 5, 9, false);
    await contract.addCfAsset("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", 5, 10, false);
    await new Promise((resolve) => setTimeout(resolve, 15000));
    await contract.addCfAsset("0x6B175474E89094C44Da98b954EedeAC495271d0F", 4, 6, true);
    await contract.addCfAsset("0xdAC17F958D2ee523a2206206994597C13D831ec7", 4, 7, true);
    await new Promise((resolve) => setTimeout(resolve, 15000));
    await contract.addCfAsset("0x826180541412D574cf1336d22c0C0a287822678A", 1, 2, true);
    await contract.addCfAsset("0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984", 2, 4, false);

    console.log("CF Asset added");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});