import hre, { ethers } from "hardhat";

import {
    TS_DEPLOYER_ADDRESS,
    HARDHAT_DEPLOYER_ADDRESS,
} from "../hardhat.config";

import { ARB_TTP, ARB_WETH, ARB_UNISWAP_V3_ROUTER, FEE_RECIPIENT_ETH } from "../addresses";

const CONTRACT_NAME = "TSFeeDistributor_V2";
const CONTRACT_ARGS = ["0x849ec611ee47BeE012Fe9274B78E10DDaE167D05", "0xD37BbE5744D730a1d98d8DC97c42F0Ca46aD7146", "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48", "0xC85feF7A1b039A9e080aadf80FF6f1536DADa088"];

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
    // await contract.setFee(15, FEE_RECIPIENT_ETH)
    // await contract.setRevOnAllTokens(false);
    // console.log("Fee set");

    await contract.setMemoTreasury(0, "=:ETH.USDC-B48:0x7D8911eB1C72F0Ba29302bE30301B75Cec81F622:0/1/0:t:0")
    await contract.setMemoCommunity(0, "=:ETH.THOR-044:0x815C23eCA83261b6Ec689b60Cc4a58b54BC24D8D:0/1/0:t:0")
    await contract.setExecutor("0x1996dAff5F5Dc99920Aa5c60303cf9e8a2E5082C", true)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});