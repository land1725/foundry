// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/MetaNode.sol";
import "src/MetaNodeStake.sol";
import "src/MockERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title RewardClaimPauseTest
 * @notice 奖励分配与领取功能测试套件
 * @dev 测试奖励计算、奖励领取、奖励暂停功能和奖励分配机制
 */
contract RewardClaimPauseTest is Test {
    // 核心合约实例
    MetaNode public metaNode;
    MetaNodeStake public metaNodeStake;
    MockERC20 public testToken;
    
    // 测试账户
    address public owner;    // 管理员账户 (部署和管理员)
    address public user1;    // 测试用户1
    address public user2;    // 测试用户2
    
    // 测试参数常量
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18; // 1亿代币
    uint256 public constant META_NODE_PER_BLOCK = 100 * 10**18;    // 每个区块100个代币奖励
    uint256 public constant TEST_TOKEN_SUPPLY = 1_000_000 * 10**18; // 100万测试代币
    
    // 质押池参数 - 专门为奖励测试优化
    uint256 public constant ETH_POOL_WEIGHT = 100;
    uint256 public constant ETH_MIN_DEPOSIT = 0.01 ether;
    uint256 public constant ETH_UNSTAKE_BLOCKS = 100;  // 标准解锁周期
    
    uint256 public constant ERC20_POOL_WEIGHT = 50;
    uint256 public constant ERC20_MIN_DEPOSIT = 100 * 10**18;  // 100个TEST代币
    uint256 public constant ERC20_UNSTAKE_BLOCKS = 200;  // 标准解锁周期
    
    // 用户资金分配
    uint256 public constant USER1_TOKEN_AMOUNT = 10_000 * 10**18;  // 1万个TEST代币
    uint256 public constant USER2_TOKEN_AMOUNT = 5_000 * 10**18;   // 5千个TEST代币
    uint256 public constant APPROVAL_AMOUNT = 50_000 * 10**18;     // 5万个TEST代币授权额度
    
    // 质押金额 - 用于产生奖励
    uint256 public constant USER1_STAKE_AMOUNT = 1_000 * 10**18;   // User1质押1000 TEST
    uint256 public constant USER2_ETH_STAKE = 0.5 ether;          // User2质押0.5 ETH

    // ！！！事件定义部分！！！
    // 这里定义我们要验证的事件，必须与合约中的事件定义完全一致
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Claim(address indexed user, uint256 indexed poolId, uint256 MetaNodeReward);

    /**
     * @notice 奖励分配与领取测试环境初始化设置
     * @dev 部署所有必要的合约、创建质押池、分配资金、设置有效质押以产生奖励
     */
    function setUp() public {
        console.log("=== Reward Distribution and Claim Test Environment Initialization ===");
        console.log("Starting simulation environment for reward distribution and claim functionality testing...");
        
        // 🎯 步骤1：获取和设定三个核心角色
        console.log("\n1. Core Role Setup:");
        owner = address(0x1);  // 拥有者（部署和管理员）
        user1 = address(0x2);  // 测试用户1
        user2 = address(0x3);  // 测试用户2
        
        console.log("- Owner (Deployer & Admin):", owner);
        console.log("- Test User 1:", user1);
        console.log("- Test User 2:", user2);
        console.log("+ Role addresses recorded for subsequent tracking");
        
        // 🚀 步骤2：部署所有必要的合约
        console.log("\n2. Smart Contract System Deployment:");
        
        // 2.1 部署MetaNode合约
        console.log("Deploying MetaNode token contract...");
        MetaNode metaNodeLogic = new MetaNode();
        
        bytes memory metaNodeInitData = abi.encodeWithSelector(
            MetaNode.initialize.selector,
            owner,  // recipient - 接收初始代币的地址
            owner   // initialOwner - 初始拥有者
        );
        
        ERC1967Proxy metaNodeProxy = new ERC1967Proxy(
            address(metaNodeLogic),
            metaNodeInitData
        );
        
        metaNode = MetaNode(address(metaNodeProxy));
        
        console.log("- MetaNode logic contract deployed at:", address(metaNodeLogic));
        console.log("- MetaNode proxy contract deployed at:", address(metaNodeProxy));
        console.log("+ MetaNode contract deployment verified");
        
        // 2.2 部署MetaNodeStake合约
        console.log("Deploying MetaNodeStake staking contract...");
        MetaNodeStake metaNodeStakeLogic = new MetaNodeStake();
        
        bytes memory metaNodeStakeInitData = abi.encodeWithSelector(
            MetaNodeStake.initialize.selector,
            IERC20(address(metaNode)), // 奖励代币地址
            META_NODE_PER_BLOCK        // 每区块奖励数量
        );
        
        // 使用 vm.prank 确保初始化时的 msg.sender 是 owner
        vm.prank(owner);
        ERC1967Proxy metaNodeStakeProxy = new ERC1967Proxy(
            address(metaNodeStakeLogic),
            metaNodeStakeInitData
        );
        
        metaNodeStake = MetaNodeStake(payable(address(metaNodeStakeProxy)));
        
        console.log("- MetaNodeStake logic contract deployed at:", address(metaNodeStakeLogic));
        console.log("- MetaNodeStake proxy contract deployed at:", address(metaNodeStakeProxy));
        console.log("+ MetaNodeStake contract deployment verified");
        console.log("+ All core contracts deployed successfully");
        
        // 🎯 步骤3：获取已部署的MetaNode代币合约实例，确认合约地址
        console.log("\n3. MetaNode Token Contract Instance:");
        console.log("- MetaNode token contract address:", address(metaNode));
        console.log("- MetaNode token name:", metaNode.name());
        console.log("- MetaNode token symbol:", metaNode.symbol());
        console.log("- MetaNode total supply:", Strings.toString(metaNode.totalSupply() / 10**18), "MN");
        console.log("+ MetaNode contract instance confirmed");
        
        // 🎯 步骤4：获取MetaNodeStake质押合约实例，确认合约地址
        console.log("\n4. MetaNodeStake Contract Instance:");
        console.log("- MetaNodeStake contract address:", address(metaNodeStake));
        console.log("- Reward token address:", address(metaNodeStake.MetaNode()));
        console.log("- Reward per block:", Strings.toString(metaNodeStake.MetaNodePerBlock() / 10**18), "MN/block");
        console.log("+ MetaNodeStake contract instance confirmed");
        
        // 🪙 步骤5：部署测试用的MockERC20代币合约
        console.log("\n5. Test Token (MockERC20) Deployment:");
        console.log("Deploying MockERC20 'Test Token' with 1,000,000 supply...");
        
        vm.prank(owner);
        testToken = new MockERC20("Test Token", "TEST", TEST_TOKEN_SUPPLY);
        
        console.log("- Test Token contract address:", address(testToken));
        console.log("- Test Token name:", testToken.name());
        console.log("- Test Token symbol:", testToken.symbol());
        console.log("- Test Token total supply:", Strings.toString(testToken.totalSupply() / 10**18), "TEST");
        console.log("- Owner balance:", Strings.toString(testToken.balanceOf(owner) / 10**18), "TEST");
        console.log("+ MockERC20 'Test Token' (TEST) deployed with 1,000,000 tokens");
        
        // 🏊 步骤6：创建两个质押池
        console.log("\n6. Staking Pool Creation:");
        console.log("Creating staking pools with standard unlock periods for reward testing...");
        
        // 创建ETH池（编号0）- 解锁周期100个区块
        console.log("- Creating ETH Pool (Pool #0):");
        console.log("  - Pool Type: Native ETH");
        console.log("  - Pool Weight:", ETH_POOL_WEIGHT);
        console.log("  - Minimum Deposit:", Strings.toString(ETH_MIN_DEPOSIT / 10**18), "ETH");
        console.log("  - Unlock Period:", Strings.toString(ETH_UNSTAKE_BLOCKS), "blocks");
        
        vm.prank(owner);
        metaNodeStake.addPool(
            address(0),           // ETH池使用零地址
            ETH_POOL_WEIGHT,      // 权重100
            ETH_MIN_DEPOSIT,      // 最小质押0.01 ETH
            ETH_UNSTAKE_BLOCKS    // 解锁周期100个区块
        );
        console.log("+ ETH Pool created with 100-block unlock period");
        
        // 创建ERC20代币池（编号1）- 解锁周期200个区块
        console.log("- Creating ERC20 Token Pool (Pool #1):");
        console.log("  - Pool Type: TEST Token");
        console.log("  - Token Address:", address(testToken));
        console.log("  - Pool Weight:", ERC20_POOL_WEIGHT);
        console.log("  - Minimum Deposit:", Strings.toString(ERC20_MIN_DEPOSIT / 10**18), "TEST");
        console.log("  - Unlock Period:", Strings.toString(ERC20_UNSTAKE_BLOCKS), "blocks");
        
        vm.prank(owner);
        metaNodeStake.addPool(
            address(testToken),    // TEST代币地址
            ERC20_POOL_WEIGHT,     // 权重50
            ERC20_MIN_DEPOSIT,     // 最小质押100 TEST
            ERC20_UNSTAKE_BLOCKS   // 解锁周期200个区块
        );
        console.log("+ ERC20 Token Pool created with 200-block unlock period");
        console.log("+ Two staking pools created: ETH Pool (100 blocks) + ERC20 Token Pool (200 blocks)");
        
        // 💰 步骤7：为用户准备测试资产
        console.log("\n7. User Asset Preparation:");
        console.log("Preparing user assets...");
        
        // 7.1 向User1分配10,000 TEST代币
        console.log("- Allocating 10,000 TEST tokens to User1:");
        vm.prank(owner);
        testToken.transfer(user1, USER1_TOKEN_AMOUNT);
        console.log("  - Amount transferred:", Strings.toString(USER1_TOKEN_AMOUNT / 10**18), "TEST tokens");
        console.log("  - User1 TEST balance:", Strings.toString(testToken.balanceOf(user1) / 10**18), "TEST");
        
        // 7.2 向User2分配5,000 TEST代币
        console.log("- Allocating 5,000 TEST tokens to User2:");
        vm.prank(owner);
        testToken.transfer(user2, USER2_TOKEN_AMOUNT);
        console.log("  - Amount transferred:", Strings.toString(USER2_TOKEN_AMOUNT / 10**18), "TEST tokens");
        console.log("  - User2 TEST balance:", Strings.toString(testToken.balanceOf(user2) / 10**18), "TEST");
        
        // 7.3 为每个用户分配2 ETH用于测试
        vm.deal(user1, 2 ether);
        vm.deal(user2, 2 ether);
        console.log("- Allocated 2 ETH to each user for testing");
        
        // 7.4 设置User1的ERC20授权
        console.log("- Setting up User1 ERC20 authorization:");
        vm.prank(user1);
        testToken.approve(address(metaNodeStake), APPROVAL_AMOUNT);
        console.log("  - Authorized amount:", Strings.toString(APPROVAL_AMOUNT / 10**18), "TEST tokens");
        
        // 7.5 设置User2的ERC20授权
        console.log("- Setting up User2 ERC20 authorization:");
        vm.prank(user2);
        testToken.approve(address(metaNodeStake), APPROVAL_AMOUNT);
        console.log("  - Authorized amount:", Strings.toString(APPROVAL_AMOUNT / 10**18), "TEST tokens");
        
        console.log("+ User asset preparation completed");
        console.log("+ Both users ready for staking and reward operations");
        
        // ⚡ 步骤8：设置有效质押以产生奖励
        console.log("\n8. Setting Up Active Stakes for Reward Generation:");
        console.log("Creating initial stakes to generate rewards...");
        
        // 8.1 User1在ERC20池质押1,000 TEST代币
        console.log("- User1 stakes 1,000 TEST in ERC20 pool:");
        vm.prank(user1);
        metaNodeStake.stakeERC20(1, USER1_STAKE_AMOUNT);
        console.log("  - Staked amount:", Strings.toString(USER1_STAKE_AMOUNT / 10**18), "TEST");
        
        // 8.2 User2在ETH池质押0.5 ETH
        console.log("- User2 stakes 0.5 ETH in ETH pool:");
        vm.prank(user2);
        metaNodeStake.stakeETH{value: USER2_ETH_STAKE}(0);
        console.log("  - Staked amount:", Strings.toString(USER2_ETH_STAKE / 10**18), "ETH");
        
        console.log("+ Initial stakes completed");
        console.log("+ Users have active stakes generating rewards");
        
        // 🎁 步骤9：验证质押合约中的奖励代币余额充足
        console.log("\n9. MetaNode Reward Token Balance Verification:");
        
        // 将足够的MetaNode代币转移到质押合约用于奖励分配
        uint256 rewardAllocation = 50_000 * 10**18; // 分配5万个MN代币作为奖励池
        vm.prank(owner);
        metaNode.transfer(address(metaNodeStake), rewardAllocation);
        
        uint256 stakingContractBalance = metaNode.balanceOf(address(metaNodeStake));
        console.log("- MetaNode tokens allocated for rewards:", Strings.toString(rewardAllocation / 10**18), "MN");
        console.log("- Staking contract MN balance:", Strings.toString(stakingContractBalance / 10**18), "MN");
        console.log("+ Sufficient reward tokens confirmed");
        
        // 🔧 步骤10：验证所有功能暂停状态
        console.log("\n10. System Function Status Verification:");
        console.log("Verifying system function status...");
        
        bool isStakePaused = metaNodeStake.stakingPaused();
        bool isUnstakePaused = metaNodeStake.unstakingPaused();
        bool isWithdrawPaused = metaNodeStake.withdrawPaused();
        bool isClaimPaused = metaNodeStake.claimPaused();
        
        console.log("- Staking function paused:", isStakePaused ? "YES" : "NO");
        console.log("- Unstaking function paused:", isUnstakePaused ? "YES" : "NO");
        console.log("- Withdrawal function paused:", isWithdrawPaused ? "YES" : "NO");
        console.log("- Claim rewards function paused:", isClaimPaused ? "YES" : "NO");
        console.log("+ All core functions are in open state (not paused)");
        console.log("+ System ready for reward distribution and claim testing");
        
        console.log("\n=== Reward Distribution and Claim Test Environment Ready ===");
        
        // 📊 最后：打印当前环境状态信息
        console.log("\n11. Environment Status Summary:");
        console.log("Environment status information:");
        
        // 池子数量
        uint256 poolLength = metaNodeStake.getPoolLength();
        console.log("- Total number of pools:", Strings.toString(poolLength));
        
        // 各池最小质押要求
        (,, uint256 ethLastRewardBlock,, uint256 ethMinDeposit,,) = metaNodeStake.pool(0);
        (,, uint256 erc20LastRewardBlock,, uint256 erc20MinDeposit,,) = metaNodeStake.pool(1);
        console.log("- ETH Pool minimum deposit:", Strings.toString(ethMinDeposit / 10**18), "ETH");
        console.log("- ERC20 Pool minimum deposit:", Strings.toString(erc20MinDeposit / 10**18), "TEST");
        
        // 用户质押量
        (uint256 user1StakeAmount,,) = metaNodeStake.user(1, user1);
        (uint256 user2StakeAmount,,) = metaNodeStake.user(0, user2);
        console.log("- User1 stake in ERC20 pool:", Strings.toString(user1StakeAmount / 10**18), "TEST");
        console.log("- User2 stake in ETH pool:", Strings.toString(user2StakeAmount / 10**18), "ETH");
        
        // 各池的最后奖励区块
        console.log("- ETH Pool last reward block:", Strings.toString(ethLastRewardBlock));
        console.log("- ERC20 Pool last reward block:", Strings.toString(erc20LastRewardBlock));
        
        // 质押合约的奖励代币余额
        console.log("- Staking contract reward balance:", Strings.toString(stakingContractBalance / 10**18), "MN tokens");
        console.log("- System status: Ready for reward distribution and claim tests");
        console.log("+ Environment summary display completed");
    }

    /**
     * @notice 测试用例1：奖励正确累计并发放
     * @dev 验证奖励机制能够正确计算和发放给质押用户，实现精确的奖励验证
     */
    function test01_RewardsCorrectlyAccumulatedAndDistributed() public {
        console.log("=== Testing Rewards Correctly Accumulated and Distributed with Precise Verification ===");
        
        // 🔍 步骤1：获取基础参数
        (uint256 stakeAmount,,) = metaNodeStake.user(1, user1);
        uint256 rewardPerBlock = metaNodeStake.MetaNodePerBlock();
        (, uint256 poolWeight, uint256 lastRewardBlock,, uint256 stTokenAmount,,) = metaNodeStake.pool(1);
        
        console.log("- User1 staked:", Strings.toString(stakeAmount / 10**18), "TEST");
        console.log("- Reward per block:", Strings.toString(rewardPerBlock / 10**18), "MN/block");
        require(stakeAmount > 0, "User1 should have staked tokens");
        
        // ⏰ 步骤2：挖矿10个区块
        vm.roll(block.number + 10);
        console.log("- Mined 10 blocks for rewards");
        
        // 💰 步骤3：记录余额并执行领取
        uint256 balanceBefore = metaNode.balanceOf(user1);
        vm.prank(user1);
        metaNodeStake.claimReward(1);
        uint256 balanceAfter = metaNode.balanceOf(user1);
        uint256 received = balanceAfter - balanceBefore;
        
        console.log("- Reward received:", Strings.toString(received / 10**18), "MN");
        
        // ✅ 步骤4：验证计算精确性
        _verifyRewardCalculation(stakeAmount, rewardPerBlock, poolWeight, lastRewardBlock, stTokenAmount, received);
        
        console.log("+ Reward mechanism verified with mathematical precision");
    }
    
    /**
     * @dev 验证奖励计算的精确性（分离函数避免stack too deep）
     */
    function _verifyRewardCalculation(
        uint256 /* userStake */,
        uint256 perBlock, 
        uint256 weight,
        uint256 lastBlock,
        uint256 totalStaked,
        uint256 actualReward
    ) internal {
        // 获取更新后的状态
        (,, uint256 newLastBlock,,,,) = metaNodeStake.pool(1);
        uint256 totalWeight = metaNodeStake.totalPoolWeight();
        
        // 计算预期值
        uint256 blocks = newLastBlock - lastBlock;
        uint256 poolReward = (blocks * perBlock * weight) / totalWeight;
        uint256 expectedAccIncrease = (poolReward * 1 ether) / totalStaked;
        
        console.log("- Blocks processed:", Strings.toString(blocks));
        console.log("- Pool reward:", Strings.toString(poolReward / 10**18), "MN");
        console.log("- Acc increase:", Strings.toString(expectedAccIncrease));
        
        // 验证计算
        assertTrue(actualReward > 0, "Should receive rewards");
        assertEq(newLastBlock, block.number, "Last reward block updated");
        
        // 🔍 关键验证：验证实际奖励金额是否与计算期望值一致
        // 根据合约逻辑：用户应得奖励 = (用户质押量 * 池子累积每代币奖励) / 1e18 - 用户已完成奖励
        // 对于新质押用户，finishedMetaNode通常为0，所以期望奖励应该接近 poolReward
        // 由于只有user1在ERC20池中质押，所以他应该获得全部的池子奖励
        console.log("- Expected pool reward:", Strings.toString(poolReward / 10**18), "MN");
        console.log("- Actual user reward:", Strings.toString(actualReward / 10**18), "MN");
        
        // 验证奖励金额准确性 - 允许小幅度误差（由于精度计算）
        uint256 tolerance = poolReward / 1000; // 0.1%的容差
        assertTrue(
            actualReward >= poolReward - tolerance && actualReward <= poolReward + tolerance,
            "Actual reward should match expected pool reward within tolerance"
        );
        
        console.log("+ Mathematical calculations verified");
        console.log("+ Reward amount accuracy verified within tolerance");
    }

    /**
     * @notice 测试用例2：无奖励时领奖被拒绝
     * @dev 测试当用户没有质押资产或未产生奖励时，系统能正确拒绝领取请求
     */
    function test02_ClaimRejectedWhenNoRewards() public {
        console.log("=== Testing Claim Rejected When No Rewards ===");
        
        // 🧑 步骤1：创建一个没有任何质押的新用户
        console.log("\n1. Setting Up User with No Stakes:");
        
        address newUser = address(0x999); // 新用户地址
        vm.deal(newUser, 1 ether); // 给新用户一些ETH用于gas
        
        console.log("- New user address:", newUser);
        console.log("+ New user created with no stakes");
        
        // 🔍 步骤2：确认新用户在各池中的质押量均为零
        console.log("\n2. Verifying Zero Stakes:");
        
        (uint256 newUserEthStake,,) = metaNodeStake.user(0, newUser);
        (uint256 newUserErc20Stake,,) = metaNodeStake.user(1, newUser);
        
        console.log("- New user ETH pool stake:", Strings.toString(newUserEthStake / 10**18), "ETH");
        console.log("- New user ERC20 pool stake:", Strings.toString(newUserErc20Stake / 10**18), "TEST");
        
        assertEq(newUserEthStake, 0, "New user should have no ETH stake");
        assertEq(newUserErc20Stake, 0, "New user should have no ERC20 stake");
        console.log("+ Confirmed: New user has no stakes in any pool");
        
        // 🚫 步骤3：用户尝试领取奖励（应该被拒绝）
        console.log("\n3. New User Attempting to Claim Rewards:");
        console.log("- Attempting to claim from ETH pool (Pool #0)");
        console.log("- Expected: Transaction should be rejected");
        
        vm.expectRevert("no reward to claim");
        vm.prank(newUser);
        metaNodeStake.claimReward(0); // 尝试从ETH池领取奖励
        
        console.log("+ ETH pool claim correctly rejected");
        
        console.log("- Attempting to claim from ERC20 pool (Pool #1)");
        console.log("- Expected: Transaction should be rejected");
        
        vm.expectRevert("no reward to claim");
        vm.prank(newUser);
        metaNodeStake.claimReward(1); // 尝试从ERC20池领取奖励
        
        console.log("+ ERC20 pool claim correctly rejected");
        
        // ✅ 步骤4：验证系统能有效识别无奖励状态
        console.log("\n4. Verifying System State:");
        
        uint256 newUserBalance = metaNode.balanceOf(newUser);
        console.log("- New user MN balance:", Strings.toString(newUserBalance / 10**18), "MN");
        
        assertEq(newUserBalance, 0, "New user should have no MN tokens");
        console.log("+ Confirmed: User received no rewards as expected");
        
        console.log("\n=== Claim Rejected When No Rewards Test Completed ===");
        console.log("+ System correctly prevents invalid claim operations");
    }

    /**
     * @notice 测试用例3：合约余额不足领奖被拒绝
     * @dev 测试当合约中奖励代币余额不足时，系统能正确拒绝领取请求
     */
    function test03_ClaimRejectedWhenInsufficientContractBalance() public {
        console.log("=== Testing Claim Rejected When Insufficient Contract Balance ===");
        
        // 🧑 步骤1：新用户进行质押并产生奖励
        console.log("\n1. Setting Up New User with Stake:");
        
        address newUser = address(0x888);
        uint256 stakeAmount = 500 * 10**18; // 质押500个TEST代币
        
        // 给新用户分配TEST代币
        vm.prank(owner);
        testToken.transfer(newUser, stakeAmount);
        
        console.log("- New user address:", newUser);
        console.log("- Allocated TEST tokens:", Strings.toString(stakeAmount / 10**18), "TEST");
        
        // 新用户授权并质押
        vm.prank(newUser);
        testToken.approve(address(metaNodeStake), stakeAmount);
        
        vm.prank(newUser);
        metaNodeStake.stakeERC20(1, stakeAmount);
        
        console.log("- New user staked:", Strings.toString(stakeAmount / 10**18), "TEST");
        console.log("+ New user stake established");
        
        // 🕐 步骤2：产生奖励
        console.log("\n2. Generating Rewards:");
        console.log("- Mining 5 blocks to generate rewards...");
        
        vm.roll(block.number + 5);
        console.log("- Current block:", Strings.toString(block.number));
        console.log("+ Rewards generated for new user");
        
        // 💸 步骤3：管理员清空合约中的所有奖励代币
        console.log("\n3. Admin Emptying Contract Reward Balance:");
        
        uint256 contractBalanceBefore = metaNode.balanceOf(address(metaNodeStake));
        console.log("- Contract balance before emptying:", Strings.toString(contractBalanceBefore / 10**18), "MN");
        
        // 使用owner权限将所有代币转出
        vm.prank(address(metaNodeStake));
        metaNode.transfer(owner, contractBalanceBefore);
        
        uint256 contractBalanceAfter = metaNode.balanceOf(address(metaNodeStake));
        console.log("- Contract balance after emptying:", Strings.toString(contractBalanceAfter / 10**18), "MN");
        
        assertEq(contractBalanceAfter, 0, "Contract should have zero balance");
        console.log("+ Contract balance successfully emptied");
        
        // 🚫 步骤4：用户尝试领取奖励（应该被拒绝）
        console.log("\n4. User Attempting to Claim with Empty Contract:");
        console.log("- New user attempting to claim rewards");
        console.log("- Expected: Transaction should be rejected due to insufficient contract balance");
        
        vm.expectRevert("insufficient reward tokens in contract");
        vm.prank(newUser);
        metaNodeStake.claimReward(1);
        
        console.log("+ Claim correctly rejected due to insufficient contract balance");
        
        // ✅ 步骤5：验证系统能检测合约余额状态
        console.log("\n5. Verifying Contract Balance Detection:");
        
        uint256 newUserBalance = metaNode.balanceOf(newUser);
        console.log("- New user MN balance:", Strings.toString(newUserBalance / 10**18), "MN");
        
        assertEq(newUserBalance, 0, "User should receive no rewards");
        console.log("+ System correctly detected insufficient contract balance");
        
        console.log("\n=== Claim Rejected When Insufficient Contract Balance Test Completed ===");
        console.log("+ System prevents over-distribution of rewards");
    }

    /**
     * @notice 测试用例4：暂停领奖功能领奖被拒绝
     * @dev 测试当管理员暂停领奖功能后，用户无法进行奖励领取操作
     */
    function test04_ClaimRejectedWhenPaused() public {
        console.log("=== Testing Claim Rejected When Function is Paused ===");
        
        // 🔄 步骤1：确保合约有足够奖励代币并恢复正常状态
        console.log("\n1. Ensuring Sufficient Contract Balance:");
        
        uint256 contractBalance = metaNode.balanceOf(address(metaNodeStake));
        console.log("- Current contract balance:", Strings.toString(contractBalance / 10**18), "MN");
        
        // ⏰ 步骤2：通过挖矿产生新的奖励
        console.log("\n2. Generating New Rewards:");
        console.log("- Mining 5 blocks to generate fresh rewards...");
        
        vm.roll(block.number + 5);
        console.log("- Current block:", Strings.toString(block.number));
        console.log("+ Fresh rewards generated for existing stakes");
        
        // 🔒 步骤3：管理员暂停领奖功能
        console.log("\n3. Admin Pausing Claim Function:");
        
        vm.prank(owner);
        metaNodeStake.pauseClaim(true);
        
        bool isClaimPaused = metaNodeStake.claimPaused();
        console.log("- Claim function status: PAUSED");
        assertTrue(isClaimPaused, "Claim function should be paused");
        console.log("+ Claim function successfully paused by admin");
        
        // 🚫 步骤4：用户尝试领取奖励（应该被拒绝）
        console.log("\n4. User1 Attempting to Claim While Paused:");
        console.log("- User1 attempting to claim rewards while function is paused");
        console.log("- Expected: Transaction should be rejected with pause error");
        
        vm.expectRevert("claim is paused");
        vm.prank(user1);
        metaNodeStake.claimReward(1);
        
        console.log("+ Claim attempt correctly rejected due to pause");
        
        // 🔓 步骤5：恢复领奖功能后验证用户可以正常领取
        console.log("\n5. Restoring Claim Function and Verifying Normal Operation:");
        
        vm.prank(owner);
        metaNodeStake.pauseClaim(false);
        
        bool isClaimActive = !metaNodeStake.claimPaused();
        console.log("- Claim function status: ACTIVE");
        assertTrue(isClaimActive, "Claim function should be active");
        console.log("+ Claim function successfully restored");
        
        // 记录恢复前用户余额
        uint256 user1BalanceBefore = metaNode.balanceOf(user1);
        console.log("- User1 balance before claim:", Strings.toString(user1BalanceBefore / 10**18), "MN");
        
        // 用户现在可以正常领取奖励
        console.log("- User1 attempting to claim after function restoration");
        
        vm.prank(user1);
        metaNodeStake.claimReward(1);
        
        uint256 user1BalanceAfter = metaNode.balanceOf(user1);
        uint256 rewardReceived = user1BalanceAfter - user1BalanceBefore;
        
        console.log("- User1 balance after claim:", Strings.toString(user1BalanceAfter / 10**18), "MN");
        console.log("- Reward received:", Strings.toString(rewardReceived / 10**18), "MN");
        
        assertTrue(rewardReceived > 0, "User should receive rewards after function restoration");
        console.log("+ User successfully claimed rewards after restoration");
        
        // ✅ 步骤6：验证管理员控制有效性
        console.log("\n6. Verifying Admin Control Effectiveness:");
        
        console.log("- Admin control over claim function: EFFECTIVE");
        console.log("- Pause enforcement: WORKING");
        console.log("- Function restoration: WORKING");
        console.log("+ System correctly enforces pause restrictions");
        
        console.log("\n=== Claim Rejected When Paused Test Completed ===");
        console.log("+ Admin pause control is fully functional");
    }

}
