import { ethers } from "hardhat";

require('dotenv').config();

async function main() {
    // console.log(process.env.LOCAL_PRIVATE_KEY);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});