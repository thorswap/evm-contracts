import { ethers } from "hardhat";

const CONTRACT_NAME = "Lock";
const CONTRACT_ARGS = [1620000000];

async function main() {
    const contract = await ethers.deployContract(CONTRACT_NAME, CONTRACT_ARGS);

    await contract.waitForDeployment();

    console.log(
        `Contract deployed to ${contract.target}`
    );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});