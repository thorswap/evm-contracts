import { ethers } from "hardhat";
import { expect } from "chai";
const parseUnits = ethers.parseUnits;

const THOR_DECIMALS = 18;
const YTHOR_DECIMALS = 18;
const USDC_DECIMALS = 6;

describe("yieldTHOR", async function () {
  it("constructor", async function () {
    const [{ address: owner }, { address: other }] = await ethers.getSigners();

    const thor = await ethers.deployContract("testERC20");
    const usdc = await ethers.deployContract("testUSDC");
    const yThor = await ethers.deployContract("yieldTHOR", [
      "Test",
      "TEST",
      thor.target,
      usdc.target,
    ]);

    await thor.approve(yThor.target, parseUnits("1000", YTHOR_DECIMALS));
    await usdc.approve(yThor.target, parseUnits("1000", USDC_DECIMALS));

    let before = await thor.balanceOf(owner);
    await yThor.deposit(parseUnits("123", YTHOR_DECIMALS), owner);
    expect(await yThor.balanceOf(owner)).to.equal(
      parseUnits("123", YTHOR_DECIMALS)
    );
    expect(await thor.balanceOf(yThor.target)).to.equal(
      parseUnits("123", THOR_DECIMALS)
    );
    expect(before - (await thor.balanceOf(owner))).to.equal(
      parseUnits("123", THOR_DECIMALS)
    );

    await yThor.withdraw(parseUnits("23", YTHOR_DECIMALS), owner, owner);
    expect(await yThor.balanceOf(owner)).to.equal(
      parseUnits("100", YTHOR_DECIMALS)
    );
    expect(await thor.balanceOf(yThor.target)).to.equal(
      parseUnits("100", THOR_DECIMALS)
    );
    expect(before - (await thor.balanceOf(owner))).to.equal(
      parseUnits("100", THOR_DECIMALS)
    );

    await yThor.withdraw(parseUnits("100", YTHOR_DECIMALS), owner, owner);
    await expect(yThor.depositRewards(parseUnits("10", USDC_DECIMALS)))
      .rejected;
    await yThor.deposit(parseUnits("100", THOR_DECIMALS), owner);

    await yThor.depositRewards(parseUnits("10", USDC_DECIMALS));
    expect(await yThor.claimable(owner)).to.equal(
      parseUnits("10", USDC_DECIMALS)
    );

    await yThor.transfer(other, parseUnits("20", YTHOR_DECIMALS));
    expect(await yThor.claimable(owner)).to.equal(
      parseUnits("10", USDC_DECIMALS)
    );
    await yThor.depositRewards(parseUnits("10", USDC_DECIMALS));
    expect(await yThor.claimable(owner)).to.equal(
      parseUnits("18", USDC_DECIMALS)
    );
    expect(await yThor.claimable(other)).to.equal(
      parseUnits("2", USDC_DECIMALS)
    );

    before = await usdc.balanceOf(owner);

    await yThor.claimRewards();
    expect(before - (await usdc.balanceOf(owner))).to.equal(
      parseUnits("-18", USDC_DECIMALS)
    );
    expect(await yThor.claimable(owner)).to.equal(
      parseUnits("0", YTHOR_DECIMALS)
    );
    expect(await yThor.claimable(other)).to.equal(
      parseUnits("2", USDC_DECIMALS)
    );
    await yThor.withdraw(parseUnits("60", YTHOR_DECIMALS), owner, owner);
    await yThor.depositRewards(parseUnits("10", USDC_DECIMALS));
    expect(await yThor.claimable(owner)).to.equal(
      parseUnits("5", USDC_DECIMALS)
    );
    expect(await yThor.claimable(other)).to.equal(
      parseUnits("7", USDC_DECIMALS)
    );
  });
});
