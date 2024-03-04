import { ethers } from "hardhat";
import { TTP_AVAX } from "../hardhat.config"

async function main() {
    console.log(TTP_AVAX);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});