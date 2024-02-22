import { ethers } from "hardhat";
import { expect } from "chai";

describe("TSAggregatorTokenTransferProxy", function () {
  it("Should deploy and be able to call setOwner", async function () {
    const [owner] = await ethers.getSigners();

    const creatorAddress = await owner.address;
    const proxyContract = await ethers.deployContract("TSAggregatorTokenTransferProxy");

    expect(await proxyContract.setOwner(creatorAddress, true)).to.emit(proxyContract, "OwnerSet").withArgs(creatorAddress, true);
  });
});