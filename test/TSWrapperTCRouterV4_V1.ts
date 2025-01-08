const { ethers } = require("hardhat");
const { expect } = require("chai");

const usdc = "0xdac17f958d2ee523a2206206994597c13d831ec7"; // rev token
const thor = "0xa5f2211b9b8170f694421f2046281775e8468044"; // not rev token

describe("TSWrapperTCRouterV4_V1", function () {
  let tsWrapperTCRouterV4: {
    waitForDeployment: () => any;
    setRevToken: (arg0: string, arg1: boolean) => any;
    connect: (arg0: any) => {
      (): any;
      new (): any;
      cfReceive: {
        (
          arg0: number,
          arg1: any,
          arg2: any,
          arg3: any,
          arg4: any,
          arg5: { value: any }
        ): any;
        new (): any;
      };
      wrapDeposit: {
        (
          arg0: string,
          arg1: string,
          arg2: string,
          arg3: string,
          arg4: string,
          arg6: { value: any }
        ): any;
        new (): any;
      };
      setRevToken: {
        (arg0: string, arg1: boolean): any;
        new (): any;
      };
    };
  };
  let owner, addr1: any;
  let routerContract: { waitForDeployment: () => any; address: any };

  before(async function () {
    // Get signers
    [owner, addr1] = await ethers.getSigners();

    // Deploy a mock router that implements IThorchainRouterV4
    routerContract = await ethers.deployContract("THORChain_Router", [
      "0x3155ba85d5f96b2d030a4966af206230e46849cb",
    ]);
    await routerContract.waitForDeployment();

    // Deploy the TSAggregatorChainflip_V1 contract
    tsWrapperTCRouterV4 = await ethers.deployContract(
      "TSWrapperTCRouterV4_V1",
      ["0xf892fef9da200d9e84c9b0647ecff0f34633abe8"]
    );
    await tsWrapperTCRouterV4.waitForDeployment();

    // Add the mock router to the routers array
    await tsWrapperTCRouterV4.setRevToken(usdc, true);
  });

  it("should correctly wrap deposit and take fee", async function () {
    // Prepare the message to encode
    const vault = "0x1261b1127ba46770f6a870f977b8c309382c6a90";
    const memo = "=:r:oleg:0/1/0:t:30";

    // Encode the message
    const encodedMessage = ethers.utils.defaultAbiCoder.encode(
      ["address", "address", "uint", "string", "uint"],
      [vault, usdc, "100000000", memo, "1750924806"]
    );

    // Send 1 ether to simulate receiving native currency
    const tx = await tsWrapperTCRouterV4
      .connect(addr1)
      .wrapDeposit(vault, usdc, "100000000", memo, "1750924806", {
        value: ethers.utils.parseEther("0"),
      });
  });
});
