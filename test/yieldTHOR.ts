import { ethers } from "hardhat";
import { expect } from "chai";
const parseUnits = ethers.parseUnits;

describe("yieldTHOR", function () {
  it("constructor", async function () {
    const [{ address: owner }, { address: other }] = await ethers.getSigners();

    const thor = await ethers.deployContract("testERC20");
    const usdc = await ethers.deployContract("testERC20");
    const c = await ethers.deployContract("yieldTHOR", [
      "Test",
      "TEST",
      thor.target,
      usdc.target,
    ]);

    await thor.approve(c.target, parseUnits("1000", 18));
    await usdc.approve(c.target, parseUnits("1000", 18));

    let before = await thor.balanceOf(owner);
    await c.deposit(parseUnits("123", 18), owner);
    expect(await c.balanceOf(owner)).to.equal(parseUnits("123", 18));
    expect(await thor.balanceOf(c.target)).to.equal(parseUnits("123", 18));
    expect(before - (await thor.balanceOf(owner))).to.equal(
      parseUnits("123", 18)
    );

    await c.withdraw(parseUnits("23", 18), owner, owner);
    expect(await c.balanceOf(owner)).to.equal(parseUnits("100", 18));
    expect(await thor.balanceOf(c.target)).to.equal(parseUnits("100", 18));
    expect(before - (await thor.balanceOf(owner))).to.equal(
      parseUnits("100", 18)
    );

    await c.withdraw(parseUnits("100", 18), owner, owner);
    await expect(c.depositRewards(parseUnits("10", 18))).rejected;
    await c.deposit(parseUnits("100", 18), owner);

    await c.depositRewards(parseUnits("10", 18));
    expect(await c.claimable(owner)).to.equal(parseUnits("10", 18));
    await c.transfer(other, parseUnits("20", 18));
    expect(await c.claimable(owner)).to.equal(parseUnits("10", 18));
    await c.depositRewards(parseUnits("10", 18));
    expect(await c.claimable(owner)).to.equal(parseUnits("18", 18));
    expect(await c.claimable(other)).to.equal(parseUnits("2", 18));
    before = await usdc.balanceOf(owner);
    await c.claimRewards();
    expect(before - (await usdc.balanceOf(owner))).to.equal(
      parseUnits("-18", 18)
    );
    expect(await c.claimable(owner)).to.equal(parseUnits("0", 18));
    expect(await c.claimable(other)).to.equal(parseUnits("2", 18));
    await c.withdraw(parseUnits("60", 18), owner, owner);
    await c.depositRewards(parseUnits("10", 18));
    expect(await c.claimable(owner)).to.equal(parseUnits("5", 18));
    expect(await c.claimable(other)).to.equal(parseUnits("7", 18));
  });
});
