const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("TSAggregatorChainflip_V1", function () {
  let tsAggregatorChainflip: { deployed: () => any; addRouter: (arg0: any) => any; connect: (arg0: any) => { (): any; new(): any; cfReceive: { (arg0: number, arg1: any, arg2: any, arg3: any, arg4: any, arg5: { value: any; }): any; new(): any; }; }; };
  let owner, addr1: any;
  let routerContract: { deployed: () => any; address: any; };

  before(async function () {
    // Get signers
    [owner, addr1] = await ethers.getSigners();

    // Deploy a mock router that implements IThorchainRouterV4
    routerContract = await ethers.deployContract("THORChain_Router", ["0x3155ba85d5f96b2d030a4966af206230e46849cb"]);

    // Deploy the TSAggregatorChainflip_V1 contract
    tsAggregatorChainflip = await ethers.deployContract("TSAggregatorChainflip_V1", ["0xf892fef9da200d9e84c9b0647ecff0f34633abe8"]);

    // Add the mock router to the routers array
    await tsAggregatorChainflip.addRouter(routerContract.address);
  });

  it("should correctly parse and handle the cfReceive message", async function () {
    // Prepare the message to encode
    const routerIndex = 0;
    const vault = "0x1261b1127ba46770f6a870f977b8c309382c6a90";
    const memo = "=:r:oleg:0/1/0:t:30";

    // Encode the message
    const encodedMessage = ethers.utils.defaultAbiCoder.encode(
      ["uint256", "address", "string"],
      [routerIndex, vault, memo]
    );

    // Prepare other parameters for cfReceive
    const srcChain = 123; // Example chain ID
    const srcAddress = ethers.utils.randomBytes(20); // Example source address
    const token = ethers.constants.AddressZero; // Use zero address for native token
    const amount = ethers.utils.parseEther("1.0"); // Example amount

    // Send 1 ether to simulate receiving native currency
    const tx = await tsAggregatorChainflip.connect(addr1).cfReceive(
      srcChain,
      srcAddress,
      encodedMessage,
      token,
      amount,
      { value: amount }
    );

    // Expect the event to be emitted with correct parameters
    await expect(tx).to.emit(tsAggregatorChainflip, "CFReceive").withArgs(
      srcChain,
      srcAddress,
      token,
      amount,
      routerContract.address,
      memo
    );

    // Additional checks can include inspecting the state changes on the contract, if necessary
  });
});
