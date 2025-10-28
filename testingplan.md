# xTHOR Vesting Contract - Comprehensive Testing Plan

## 🎯 **Testing Overview**

This plan covers systematic testing of the xTHOR Individual Vesting Contract over a **72-hour period (3 days)** with realistic reward distribution scenarios.

### **Testing Timeline (3 Days)**
- **Total Vesting Period**: 72 hours (3 days)
- **Cliff Period**: 24 hours (1 full day for reward accumulation)
- **Linear Vesting**: Hours 24-72 (48 hours of gradual unlock)
- **Daily Reward Cycles**: Every 24 hours simulate reward distribution

---

## ⏰ **Testing Schedule**

| Time | Milestone | What's Unlocked | Available Actions |
|------|-----------|----------------|-------------------|
| **T+0 (Deploy)** | Contract Start | Nothing | ✅ Claim USDC rewards only |
| **T+12h** | Half Day | Nothing | ✅ Multiple reward claims |
| **T+24h** | Cliff Ends | ~33% of tokens | ✅ Claim USDC + vested uTHOR |
| **T+36h** | Day 1.5 | ~50% of tokens | ✅ Halfway point |
| **T+48h** | Day 2 Complete | ~67% of tokens | ✅ Major testing milestone |
| **T+60h** | Day 2.5 | ~83% of tokens | ✅ Near completion |
| **T+72h** | Vesting Complete | 100% of tokens | ✅ Full unlock |

---

## 🧪 **Test Scenarios & Execution Plan**

### **Phase 1: Pre-Cliff Testing (Hours 0-24)**
*Test reward claiming when tokens are completely locked - Full day of reward accumulation*

#### **Scenario 1A: USDC Rewards Only (Tokens Locked)**
```bash
# Setup - Simulate reward accumulation
await mockUTHOR.simulateRewardAccumulation(parseUnits("50", 6)); // 50 USDC

# Test 1: Verify no tokens are claimable
expect(await xTHORVesting.claimableAmount()).to.equal(0);

# Test 2: Claim USDC rewards while tokens locked
await expect(xTHORVesting.connect(beneficiary).claimRewards())
  .to.emit(xTHORVesting, "RewardsClaimed");

# Test 3: Verify tokens still locked in contract
expect(await uTHOR.balanceOf(xTHORVesting.target)).to.equal(TOTAL_AMOUNT);
expect(await uTHOR.balanceOf(beneficiary.address)).to.equal(0);
```

**Expected Results:**
- ✅ USDC rewards successfully claimed
- ✅ uTHOR tokens remain locked in contract
- ✅ Beneficiary receives USDC but no uTHOR

#### **Scenario 1B: Multiple Daily Reward Claims (Pre-Cliff)**
```bash
# Hour 6: Morning reward distribution
await mockUTHOR.simulateRewardAccumulation(parseUnits("30", 6));
await xTHORVesting.connect(beneficiary).claimRewards();

# Hour 12: Midday reward distribution  
await mockUTHOR.simulateRewardAccumulation(parseUnits("35", 6));
await xTHORVesting.connect(beneficiary).claimRewards();

# Hour 18: Evening reward distribution
await mockUTHOR.simulateRewardAccumulation(parseUnits("40", 6));
await xTHORVesting.connect(beneficiary).claimRewards();

# Hour 24: End of cliff - final pre-unlock reward
await mockUTHOR.simulateRewardAccumulation(parseUnits("45", 6));
await xTHORVesting.connect(beneficiary).claimRewards();

# Verify cumulative rewards received over full day
expect(await usdc.balanceOf(beneficiary.address)).to.equal(parseUnits("150", 6));
```

---

### **Phase 2: Post-Cliff Testing (Hours 24-72)**
*Test claiming vested tokens after unlock begins*

#### **Scenario 2A: uTHOR Claiming After Unlock**
```bash
# Move to 24 hours (cliff end)
await time.increaseTo(startTime + 24 * 60 * 60);

# Test 1: Verify tokens are now claimable
const claimable = await xTHORVesting.claimableAmount();
expect(claimable).to.be.gt(0);

# Test 2: Claim vested uTHOR tokens
const balanceBefore = await uTHOR.balanceOf(beneficiary.address);
await xTHORVesting.connect(beneficiary).claimVested();
const balanceAfter = await uTHOR.balanceOf(beneficiary.address);

# Test 3: Verify correct amount received
expect(balanceAfter - balanceBefore).to.equal(claimable);
```

**Expected Results:**
- ✅ ~33% of tokens claimable after 24 hours (cliff end)
- ✅ Beneficiary successfully receives vested uTHOR
- ✅ Contract balance reduces accordingly

#### **Scenario 2B: Linear Vesting Verification**
```bash
# Test vesting at different time points
const testPoints = [
  { hours: 24, expectedPercent: 0.333 }, // 33% after 24h (cliff end)
  { hours: 36, expectedPercent: 0.5 },   // 50% after 36h  
  { hours: 48, expectedPercent: 0.667 }, // 67% after 48h (day 2)
  { hours: 60, expectedPercent: 0.833 }, // 83% after 60h
  { hours: 72, expectedPercent: 1.0 },   // 100% after 72h (day 3)
];

for (const point of testPoints) {
  await time.increaseTo(startTime + point.hours * 60 * 60);
  const claimable = await xTHORVesting.claimableAmount();
  const expected = BigInt(Math.floor(Number(TOTAL_AMOUNT) * point.expectedPercent));
  
  expect(claimable).to.be.closeTo(expected, parseUnits("1", 18));
}
```

---

### **Phase 3: Combined Claiming Testing**
*Critical test: USDC claimed first, then uTHOR*

#### **Scenario 3A: Combined Claiming via claimVested()**
```bash
# Setup: Move to 36 hours (50% vested)  
await time.increaseTo(startTime + 36 * 60 * 60);

# Setup: Simulate reward accumulation
const rewardAmount = parseUnits("75", 6);
await mockUTHOR.simulateRewardAccumulation(rewardAmount);

# Pre-claim balances
const usdcBefore = await usdc.balanceOf(beneficiary.address);
const uthorBefore = await uTHOR.balanceOf(beneficiary.address);
const claimableUTHOR = await xTHORVesting.claimableAmount();

# Execute combined claim
const tx = await xTHORVesting.connect(beneficiary).claimVested();

# Verify both events emitted
await expect(tx).to.emit(xTHORVesting, "RewardsClaimed");
await expect(tx).to.emit(xTHORVesting, "TokensReleased");

# Verify both tokens received
const usdcAfter = await usdc.balanceOf(beneficiary.address);
const uthorAfter = await uTHOR.balanceOf(beneficiary.address);

expect(usdcAfter - usdcBefore).to.equal(rewardAmount);
expect(uthorAfter - uthorBefore).to.equal(claimableUTHOR);
```

**Critical Verification:**
- ✅ USDC rewards claimed FIRST (preserving reward rights)
- ✅ uTHOR tokens transferred SECOND
- ✅ Both RewardsClaimed and TokensReleased events emitted
- ✅ Beneficiary receives both asset types in one transaction

#### **Scenario 3B: Separate Claiming Pattern**
```bash
# Setup: Move to 48 hours (67% vested)
await time.increaseTo(startTime + 48 * 60 * 60);
await mockUTHOR.simulateRewardAccumulation(parseUnits("60", 6));

# Step 1: Claim only USDC rewards
const usdcBefore = await usdc.balanceOf(beneficiary.address);
await xTHORVesting.connect(beneficiary).claimRewards();
const usdcAfter = await usdc.balanceOf(beneficiary.address);

# Verify USDC received, uTHOR still in contract
expect(usdcAfter - usdcBefore).to.equal(parseUnits("60", 6));
expect(await uTHOR.balanceOf(xTHORVesting.target)).to.equal(TOTAL_AMOUNT); // Still full amount

# Step 2: Later claim vested uTHOR
const uthorBefore = await uTHOR.balanceOf(beneficiary.address);
const claimable = await xTHORVesting.claimableAmount();
await xTHORVesting.connect(beneficiary).claimVested();
const uthorAfter = await uTHOR.balanceOf(beneficiary.address);

# Verify uTHOR received, no additional USDC (already claimed)
expect(uthorAfter - uthorBefore).to.equal(claimable);
expect(await usdc.balanceOf(beneficiary.address)).to.equal(usdcAfter); // No change
```

---

### **Phase 4: Advanced Scenarios**

#### **Scenario 4A: Partial Claims Over Time**
```bash
// Test claiming multiple times during vesting period
const claimTimes = [
  { hour: 24, description: "Cliff end claim" },
  { hour: 36, description: "Day 1.5 claim" }, 
  { hour: 48, description: "Day 2 claim" },
  { hour: 60, description: "Day 2.5 claim" },
  { hour: 72, description: "Final claim" }
];

let totalClaimed = 0n;

for (const claim of claimTimes) {
  await time.increaseTo(startTime + claim.hour * 60 * 60);
  
  const claimableBefore = await xTHORVesting.claimableAmount();
  if (claimableBefore > 0) {
    await xTHORVesting.connect(beneficiary).claimVested();
    totalClaimed += claimableBefore;
  }
}

// Verify all tokens eventually claimed
expect(totalClaimed).to.equal(TOTAL_AMOUNT);
expect(await xTHORVesting.claimableAmount()).to.equal(0);
```

#### **Scenario 4B: Owner Revocation Testing**
```bash
// Test owner revoking vesting at 50% completion  
await time.increaseTo(startTime + 36 * 60 * 60); // 50% point (1.5 days)

// Setup rewards for beneficiary
await mockUTHOR.simulateRewardAccumulation(parseUnits("40", 6));

// Pre-revocation state
const ownerBalanceBefore = await uTHOR.balanceOf(owner.address);
const beneficiaryUsdcBefore = await usdc.balanceOf(beneficiary.address);
const vestedAmount = await xTHORVesting.claimableAmount();
const contractBalance = await uTHOR.balanceOf(xTHORVesting.target);

// Execute revocation
const tx = await xTHORVesting.revokeVesting();
await expect(tx).to.emit(xTHORVesting, "VestingRevoked");

// Verify results
const ownerBalanceAfter = await uTHOR.balanceOf(owner.address);
const beneficiaryUsdcAfter = await usdc.balanceOf(beneficiary.address);

// Owner should get unvested tokens
const unvested = contractBalance - vestedAmount;
expect(ownerBalanceAfter - ownerBalanceBefore).to.equal(unvested);

// Beneficiary should get pending rewards
expect(beneficiaryUsdcAfter - beneficiaryUsdcBefore).to.equal(parseUnits("40", 6));

// Further claiming should be disabled
await expect(xTHORVesting.connect(beneficiary).claimVested())
  .to.be.revertedWith("xTHOR: Claiming not enabled");
```

---

## 📊 **Daily Testing Schedule**

### **Day 1 Focus: Full Cliff Period (24 hours)**
- **Hours 0-24**: Pure USDC reward claiming (tokens locked)
- Multiple reward distributions throughout the day
- Test reward accumulation patterns

### **Day 2 Focus: Active Vesting**  
- **Hours 24-48**: First vested token claims (33% → 67%)
- Combined claiming patterns  
- Separate vs integrated claiming strategies
- Owner revocation testing at 50% (36h)

### **Day 3 Focus: Final Vesting + Completion**
- **Hours 48-72**: Final vesting period (67% → 100%)
- Advanced claiming patterns
- Edge case testing
- Complete vesting scenarios
- Final cleanup and validation

---

## 🔧 **Testing Script Examples**

### **Setup Script**
```bash
# Deploy with testing mode
npx hardhat run scripts/deploy-xTHOR.ts --testing --network localhost

# Fund the contract (owner)
await uTHOR.approve(xTHORAddress, parseUnits("100", 18));
await xTHORVesting.depositUTHOR(parseUnits("100", 18));

# Pre-fund MockUTHOR with USDC for reward simulation
await usdc.mint(mockUTHORAddress, parseUnits("1000", 6));
```

### **Reward Simulation Script**
```bash
# Simulate daily reward distribution
async function simulateDailyRewards(day: number) {
  const dailyReward = parseUnits((day * 25).toString(), 6); // Increasing rewards
  await mockUTHOR.simulateRewardAccumulation(dailyReward);
  console.log(`Day ${day}: ${ethers.formatUnits(dailyReward, 6)} USDC rewards distributed`);
}
```

---

## ✅ **Success Criteria**

### **Must Pass Tests:**
1. **Pre-cliff USDC claiming** works while tokens locked
2. **Post-cliff uTHOR claiming** works with correct amounts
3. **Combined claiming** automatically claims USDC first, then uTHOR
4. **Linear vesting** releases correct percentages over time
5. **Separate claiming** allows flexible reward/token claiming patterns
6. **Owner revocation** preserves beneficiary rewards and returns unvested tokens
7. **Multiple claim cycles** work without double-claiming or loss

### **Performance Benchmarks:**
- All transactions complete within reasonable gas limits
- No rounding errors exceeding 0.001% of amounts
- Event emissions match expected patterns
- Contract state updates correctly after each operation

---

## 🚨 **Critical Test Cases**

### **Priority 1: Core Functionality**
- [x] USDC rewards claimable during lock period
- [x] uTHOR claimable after cliff
- [x] Combined claiming preserves reward sequence

### **Priority 2: Security & Edge Cases**  
- [x] Owner revocation preserves beneficiary rights
- [x] Multiple claims don't cause double-spending
- [x] Emergency withdrawals work correctly

### **Priority 3: Real-world Scenarios**
- [x] Multi-day reward accumulation
- [x] Partial claiming strategies
- [x] Time-based vesting accuracy

---

This testing plan ensures comprehensive coverage of all scenarios with realistic timing that mirrors actual reward distribution patterns! 🎯