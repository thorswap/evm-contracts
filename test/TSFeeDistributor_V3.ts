import { expect } from "chai";
import { ethers } from "hardhat";

async function deployMockERC20(
  name: string,
  symbol: string,
  decimals: number
) {
  const token = await ethers.deployContract("MockERC20", [name, symbol, decimals]);
  return token;
}

async function deployMockRewardsReceiver() {
  const mock = await ethers.deployContract("MockRewardsReceiver");
  return mock;
}

describe("TSFeeDistributor_V3", function () {
  let owner: any, executor: any, other: any;
  let feeDistributor: any;
  let tcRouter: any;
  let usdc: any;
  let thor: any;
  let uThor: any;
  let yThor: any;
  let vThor: any;
  
  // For readability
  const parseUnits = (value: string | number, decimals = 6) =>
    ethers.parseUnits(value.toString(), decimals);

  before(async () => {
    [owner, executor, other] = await ethers.getSigners();
  });

  beforeEach(async () => {
    usdc = await deployMockERC20("Test USDC", "USDC", 6);
    thor = await deployMockERC20("Test THOR", "THOR", 18);

    uThor = await deployMockRewardsReceiver();
    yThor = await deployMockRewardsReceiver();
    vThor = await deployMockRewardsReceiver();

    const tcRouter = await ethers.deployContract("MockThorchainRouter");
    console.log("tcRouter", tcRouter)
    feeDistributor = await ethers.deployContract("TSFeeDistributor_V3", [
      tcRouter.target,           // _tcRouterAddress
      usdc.target,               // _feeAsset
      owner.address,             // _treasuryWallet
      thor.target,               // _thorToken
      uThor.target,              // _uThorToken
      vThor.target,              // _vThorToken
      yThor.target               // _yThorToken
    ]);

    await feeDistributor.setOwner(executor.address, true);
    await feeDistributor.setExecutor(executor.address, true);

    await feeDistributor.setThreshold(parseUnits("10", 6)); // e.g. 10 USDC
  });

  it("initial configuration is correct", async () => {
    expect(await feeDistributor.treasuryBps()).to.equal(2500);
    expect(await feeDistributor.communityBps()).to.equal(7500);
    expect(await feeDistributor.rewardAmountThreshold()).to.equal(parseUnits("10", 6));
    expect(await feeDistributor.treasuryWallet()).to.equal(owner.address);
  });

  it("reverts if not executor calls distribute", async () => {
    await usdc.mint(feeDistributor.target, parseUnits("100", 6));

    await expect(
      feeDistributor.connect(other).distribute(tcRouter.target)
    ).to.be.revertedWith("Not an executor in private mode");
  });

  it("reverts if balance is below threshold", async () => {
    // By default, we set threshold to 10 USDC
    await usdc.mint(feeDistributor.target, parseUnits("5", 6)); // only 5 USDC
    await expect(
      feeDistributor.connect(executor).distribute(tcRouter.target)
    ).to.be.revertedWith("Balance below threshold");
  });

  it("distributes successfully above threshold", async () => {
    // 1) Fund the distributor with 100 USDC
    const totalSupply = parseUnits("100", 6);
    await usdc.mint(feeDistributor.target, totalSupply);

    // 2) Suppose we want to set the treasury BPS to 20% and community BPS to 80%
    await feeDistributor.setShares(2000, 8000); // 2000 + 8000 = 10000

    // 3) Let's also pretend we have some THOR balances to shape the sub-split:
    //    We'll mint THOR to the "addresses" of the yield tokens:
    await thor.mint(uThor.target, ethers.parseUnits("50", 18));
    await thor.mint(yThor.target, ethers.parseUnits("100", 18));
    await thor.mint(vThor.target, ethers.parseUnits("150", 18));
    // Make sure the router also has some THOR for the "pool"
    await thor.mint(tcRouter.target, ethers.parseUnits("200", 18));

    // 4) The ratio of 50 : 100 : 150 : 200 => total = 500
    //    - uThor => 50/500 => 10% of communityBps => 0.1 * 8000 => 800 BPS
    //    - yThor => 100/500 => 20% => 1600 BPS
    //    - vThor => 150/500 => 30% => 2400 BPS
    //    - thorPool => leftover => 8000 - (800+1600+2400) = 3200 BPS
    //
    //    We'll verify that in the distribution by reading vThorBps and thorPoolBps from the event.

    // 5) Distribute. The threshold is 10, we have 100, so it should pass.
    await feeDistributor.connect(executor).distribute(tcRouter.target);

    // 6) Verify outcome:
    //
    //  - The total USDC was 100.
    //  - 20% => 20 USDC to the treasury, 80 USDC to the community.
    //
    //  - community portion: 80 USDC
    //    - uThor => 80 * 800 / 8000 => 80 * 0.1 => 8 USDC
    //    - yThor => 80 * 1600 / 8000 => 80 * 0.2 => 16 USDC
    //    - vThor => 80 * 2400 / 8000 => 80 * 0.3 => 24 USDC
    //    - thorPool => 80 * 3200 / 8000 => 80 * 0.4 => 32 USDC
    //
    //    The contract calls depositRewards(8) to uThor, depositRewards(16) to yThor,
    //    and depositWithExpiry(24 + 32 = 56) to the router.

    //  - So total distributed is 20 (treasury) + 8 (uThor) + 16 (yThor) + 56 (router) = 100
    //
    // 7) We can now check:
    //    (a) The treasury wallet (owner.address) should have +20 USDC
    //    (b) The final deposit in uThor / yThor mock is 8 and 16 respectively
    //    (c) The router call was for 56 USDC
    //    (d) The event logs the final vThorBps and thorPoolBps

    // (a) Check treasury
    expect(await usdc.balanceOf(owner.address)).to.equal(
      parseUnits("20", 6)
    );

    // (b) Check depositRewards in the mocks
    const uThorRewards = await uThor.totalRewardsReceived();
    const yThorRewards = await yThor.totalRewardsReceived();
    expect(uThorRewards).to.equal(parseUnits("8", 6));
    expect(yThorRewards).to.equal(parseUnits("16", 6));

    // (c) The router got 56 USDC
    expect(await usdc.balanceOf(tcRouter.target)).to.equal(
      parseUnits("56", 6)
    );

    // (d) Check the event
    // You can parse the event from the transaction receipt:
    const tx = await feeDistributor.connect(executor).distribute(tcRouter.target);
    const receipt = await tx.wait();

    // The event in your code is: event Distribution(uint256 amount, uint256 vThorBps, uint256 poolBps);
    // Because you do the distribution logic again, let's just check the first one we did:
    // Actually, let's do this more simply: wait for the first transaction's logs
    // We'll skip the second distribution call for clarity.

    // We'll parse the logs of the first distribution:
    // (Alternatively, you can store the result of that distribution call above.)
    // For demonstration, let's do it properly from the first call:

    //  - This is how you'd do it if you stored the transaction for the first distribute call:
    // const tx = await feeDistributor.connect(executor).distribute(tcRouter.target);
    // const receipt = await tx.wait();
    const distributionEvent = receipt.logs
      .map((log: any) => {
        try {
          return feeDistributor.interface.parseLog(log);
        } catch {
          return null;
        }
      })
      .filter((parsed: any) => parsed && parsed.name === "Distribution")[0];

    // distributionEvent.args => [amount, vThorBps, poolBps]
    // By the time we do the second distribute, the THOR balances are the same or we can check again.
    // For demonstration, let's just assert they exist:
    expect(distributionEvent).to.exist;
    if (distributionEvent) {
      // Check that vThorBps = 2400 and poolBps = 3200 from the example THOR ratio above
      expect(distributionEvent.args.vThorBps).to.equal(2400);
      expect(distributionEvent.args.poolBps).to.equal(3200);
    }
  });
});
