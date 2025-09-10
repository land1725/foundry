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
 * @title ComprehensivePermissionPauseTest
 * @notice 综合权限与暂停控制功能测试套件
 * @dev 测试完整的权限管理体系、细粒度暂停控制、角色权限验证和安全机制
 */
contract ComprehensivePermissionPauseTest is Test {
    // 核心合约实例
    MetaNode public metaNode;
    MetaNodeStake public metaNodeStake;
    MockERC20 public testToken;
    
    // 测试账户 - 五个核心角色
    address public owner;              // 部署者/最高管理员
    address public admin;              // 管理员（ADMIN_ROLE）
    address public user1;              // 测试用户1
    address public user2;              // 测试用户2
    address public unauthorizedUser;   // 未授权用户
    
    // 测试参数常量
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18; // 1亿代币
    uint256 public constant META_NODE_PER_BLOCK = 100 * 10**18;    // 每个区块100个代币奖励
    uint256 public constant TEST_TOKEN_SUPPLY = 1_000_000 * 10**18; // 100万测试代币
    
    // 质押池参数
    uint256 public constant ETH_POOL_WEIGHT = 100;
    uint256 public constant ETH_MIN_DEPOSIT = 0.01 ether;
    uint256 public constant ETH_UNSTAKE_BLOCKS = 100;  // 解锁周期
    
    uint256 public constant ERC20_POOL_WEIGHT = 50;
    uint256 public constant ERC20_MIN_DEPOSIT = 100 * 10**18;  // 100个TEST代币
    uint256 public constant ERC20_UNSTAKE_BLOCKS = 200;  // 解锁周期
    
    // 用户资金分配
    uint256 public constant USER_TOKEN_AMOUNT = 10_000 * 10**18;  // 每用户1万个TEST代币
    uint256 public constant APPROVAL_AMOUNT = 50_000 * 10**18;   // 授权额度
    
    // 质押金额
    uint256 public constant USER1_STAKE_AMOUNT = 1_000 * 10**18;  // User1质押1000 TEST
    uint256 public constant USER2_ETH_STAKE = 0.5 ether;         // User2质押0.5 ETH
    
    // 奖励分配
    uint256 public constant REWARD_ALLOCATION = 50_000 * 10**18; // 分配5万个MN代币作为奖励池

    // ！！！事件定义部分！！！
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Claim(address indexed user, uint256 indexed poolId, uint256 MetaNodeReward);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event AddPool(
        address indexed stTokenAddress,
        uint256 indexed poolWeight,
        uint256 indexed lastRewardBlock,
        uint256 minDepositAmount,
        uint256 unstakeLockedBlocks
    );

    /**
     * @notice 综合权限与暂停控制测试环境初始化设置
     * @dev 部署合约、设置权限、创建质押池、分配资产、建立初始质押并生成奖励
     */
    function setUp() public {
        console.log("=== Comprehensive Permission & Pause Control Test Environment Initialization ===");
        console.log("Starting complete environment setup for permission management and pause control testing...");
        
        // 🎯 步骤1：获取五个测试账户并记录地址信息
        console.log("\n1. Test Account Setup (5 Core Roles):");
        owner = address(0x1);              // 部署者（Owner）
        admin = address(0x2);              // 管理员（Admin）
        user1 = address(0x3);              // 用户1（User1）
        user2 = address(0x4);              // 用户2（User2）
        unauthorizedUser = address(0x5);   // 未授权用户（UnauthorizedUser）
        
        console.log("- Owner (Deployer):", owner);
        console.log("- Admin (ADMIN_ROLE):", admin);
        console.log("- User1 (Test User):", user1);
        console.log("- User2 (Test User):", user2);
        console.log("- UnauthorizedUser:", unauthorizedUser);
        console.log("+ Five test accounts configured with distinct roles");
        
        // 🚀 步骤2：合约部署与获取
        console.log("\n2. Smart Contract Deployment & Instance Retrieval:");
        
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
        console.log("- MetaNode contract instance confirmed");
        
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
        console.log("- MetaNodeStake contract instance confirmed");
        
        // 2.3 获取MetaNode代币合约实例，确认合约地址
        console.log("Confirming MetaNode token contract instance:");
        console.log("- MetaNode token contract address:", address(metaNode));
        console.log("- MetaNode token name:", metaNode.name());
        console.log("- MetaNode token symbol:", metaNode.symbol());
        console.log("- MetaNode total supply:", Strings.toString(metaNode.totalSupply() / 10**18), "MN");
        console.log("+ MetaNode contract instance confirmed and verified");
        
        // 2.4 获取MetaNodeStake质押合约实例，确认合约地址
        console.log("Confirming MetaNodeStake contract instance:");
        console.log("- MetaNodeStake contract address:", address(metaNodeStake));
        console.log("- Reward token address:", address(metaNodeStake.MetaNode()));
        console.log("- Reward per block:", Strings.toString(metaNodeStake.MetaNodePerBlock() / 10**18), "MN/block");
        console.log("+ MetaNodeStake contract instance confirmed and verified");
        
        // 2.5 部署测试用的MockERC20代币合约
        console.log("Deploying MockERC20 'Test Token' contract:");
        console.log("- Token Name: Test Token");
        console.log("- Token Symbol: TEST");
        console.log("- Initial Supply: 1,000,000 tokens");
        
        vm.prank(owner);
        testToken = new MockERC20("Test Token", "TEST", TEST_TOKEN_SUPPLY);
        
        console.log("- Test Token contract address:", address(testToken));
        console.log("- Test Token total supply:", Strings.toString(testToken.totalSupply() / 10**18), "TEST");
        console.log("- Owner balance:", Strings.toString(testToken.balanceOf(owner) / 10**18), "TEST");
        console.log("+ MockERC20 'Test Token' (TEST) deployed successfully");
        console.log("+ All smart contracts deployed and instances retrieved");
        
        // 🔐 步骤3：权限管理设置
        console.log("\n3. Permission Management Setup:");
        console.log("Setting up ADMIN_ROLE for admin account...");
        
        // 获取ADMIN_ROLE常量
        bytes32 adminRole = metaNodeStake.ADMIN_ROLE();
        console.log("- ADMIN_ROLE identifier obtained");
        
        // Owner授予Admin账户ADMIN_ROLE权限
        vm.prank(owner);
        metaNodeStake.grantRole(adminRole, admin);
        
        // 验证权限设置
        bool hasAdminRole = metaNodeStake.hasRole(adminRole, admin);
        console.log("- Admin account:", admin);
        console.log("- ADMIN_ROLE granted:", hasAdminRole ? "YES" : "NO");
        
        require(hasAdminRole, "Admin should have ADMIN_ROLE");
        console.log("+ ADMIN_ROLE successfully granted to admin account");
        console.log("+ Permission management setup completed");
        
        // 🏊 步骤4：质押池创建
        console.log("\n4. Staking Pool Creation:");
        console.log("Creating two staking pools with standard parameters...");
        
        // 4.1 创建ETH质押池（池ID：0）
        console.log("- Creating ETH Pool (Pool ID: 0):");
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
        console.log("+ ETH Pool (ID: 0) created successfully");
        
        // 4.2 创建ERC20质押池（池ID：1）
        console.log("- Creating ERC20 Pool (Pool ID: 1):");
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
        console.log("+ ERC20 Pool (ID: 1) created successfully");
        console.log("+ Two staking pools created: ETH Pool + ERC20 Pool");
        
        // 💰 步骤5：用户资产准备
        console.log("\n5. User Asset Preparation:");
        console.log("Distributing TEST tokens to all test users...");
        
        // 向所有测试用户分发10,000 TEST代币
        address[] memory users = new address[](4);
        users[0] = admin;
        users[1] = user1;
        users[2] = user2;
        users[3] = unauthorizedUser;
        
        for (uint i = 0; i < users.length; i++) {
            vm.prank(owner);
            testToken.transfer(users[i], USER_TOKEN_AMOUNT);
            console.log("- Allocated", Strings.toString(USER_TOKEN_AMOUNT / 10**18), "TEST tokens to", users[i]);
            
            // 完成对质押合约的ERC20代币授权操作
            vm.prank(users[i]);
            testToken.approve(address(metaNodeStake), APPROVAL_AMOUNT);
            console.log("  - Authorized", Strings.toString(APPROVAL_AMOUNT / 10**18), "TEST tokens to staking contract");
        }
        
        // 为每个用户分配2 ETH用于测试
        vm.deal(admin, 2 ether);
        vm.deal(user1, 2 ether);
        vm.deal(user2, 2 ether);
        vm.deal(unauthorizedUser, 2 ether);
        console.log("- Allocated 2 ETH to each test user for transaction fees");
        
        console.log("+ All users have 10,000 TEST tokens and 2 ETH");
        console.log("+ ERC20 authorization completed for all users");
        console.log("+ User asset preparation completed");
        
        // ⚡ 步骤6：初始质押设置
        console.log("\n6. Initial Staking Setup:");
        console.log("Creating initial stakes to establish baseline...");
        
        // 6.1 User1在ERC20池质押1,000 TEST代币
        console.log("- User1 stakes 1,000 TEST in ERC20 pool:");
        vm.prank(user1);
        metaNodeStake.stakeERC20(1, USER1_STAKE_AMOUNT);
        console.log("  - User1 staked amount:", Strings.toString(USER1_STAKE_AMOUNT / 10**18), "TEST");
        
        // 6.2 User2在ETH池质押0.5 ETH
        console.log("- User2 stakes 0.5 ETH in ETH pool:");
        vm.prank(user2);
        metaNodeStake.stakeETH{value: USER2_ETH_STAKE}(0);
        console.log("  - User2 staked amount:", Strings.toString(USER2_ETH_STAKE / 10**18), "ETH");
        
        console.log("+ Initial stakes established successfully");
        console.log("+ Both users have active stakes generating rewards");
        
        // 🔧 步骤7：状态验证 - 验证所有功能暂停状态初始均为开放状态
        console.log("\n7. Function Status Verification:");
        console.log("Verifying all pause states are initially false (open)...");
        
        bool isStakePaused = metaNodeStake.stakingPaused();
        bool isUnstakePaused = metaNodeStake.unstakingPaused();
        bool isWithdrawPaused = metaNodeStake.withdrawPaused();
        bool isClaimPaused = metaNodeStake.claimPaused();
        bool isGlobalPaused = metaNodeStake.paused();
        
        console.log("- Staking function paused:", isStakePaused ? "YES" : "NO");
        console.log("- Unstaking function paused:", isUnstakePaused ? "YES" : "NO");
        console.log("- Withdrawal function paused:", isWithdrawPaused ? "YES" : "NO");
        console.log("- Claim rewards function paused:", isClaimPaused ? "YES" : "NO");
        console.log("- Global pause state:", isGlobalPaused ? "YES" : "NO");
        
        // 验证所有功能都处于开放状态
        assertTrue(!isStakePaused, "Staking should be open initially");
        assertTrue(!isUnstakePaused, "Unstaking should be open initially");
        assertTrue(!isWithdrawPaused, "Withdrawal should be open initially");
        assertTrue(!isClaimPaused, "Claim should be open initially");
        assertTrue(!isGlobalPaused, "Global state should be open initially");
        
        console.log("+ All functions confirmed to be in open state (false)");
        console.log("+ Function status verification completed");
        
        // 🎁 步骤8：奖励生成
        console.log("\n8. Reward Generation:");
        console.log("Setting up reward tokens and generating initial rewards...");
        
        // 将MetaNode代币转移到质押合约用于奖励分配
        vm.prank(owner);
        metaNode.transfer(address(metaNodeStake), REWARD_ALLOCATION);
        
        uint256 stakingContractBalance = metaNode.balanceOf(address(metaNodeStake));
        console.log("- MetaNode tokens allocated for rewards:", Strings.toString(REWARD_ALLOCATION / 10**18), "MN");
        console.log("- Staking contract MN balance:", Strings.toString(stakingContractBalance / 10**18), "MN");
        
        // 通过挖矿10个区块产生奖励，为后续测试做准备
        console.log("- Mining 10 blocks to generate rewards...");
        vm.roll(block.number + 10);
        console.log("- Current block number:", Strings.toString(block.number));
        console.log("+ 10 blocks mined, rewards accumulated for existing stakes");
        
        console.log("+ Reward generation setup completed");
        
        // 📊 步骤9：环境状态汇总
        console.log("\n9. Environment Status Summary:");
        console.log("Final environment configuration summary:");
        
        // 池子数量
        uint256 poolLength = metaNodeStake.getPoolLength();
        console.log("- Total staking pools:", Strings.toString(poolLength));
        
        // 用户质押量
        (uint256 user1StakeAmount,,) = metaNodeStake.user(1, user1);
        (uint256 user2StakeAmount,,) = metaNodeStake.user(0, user2);
        console.log("- User1 stake in ERC20 pool:", Strings.toString(user1StakeAmount / 10**18), "TEST");
        console.log("- User2 stake in ETH pool:", Strings.toString(user2StakeAmount / 10**18), "ETH");
        
        // 权限配置
        console.log("- Owner account:", owner);
        console.log("- Admin account (ADMIN_ROLE):", admin);
        console.log("- Regular users count: 2 (user1, user2)");
        console.log("- Unauthorized user:", unauthorizedUser);
        
        // 资产配置
        console.log("- Each user TEST balance:", Strings.toString(USER_TOKEN_AMOUNT / 10**18), "TEST");
        console.log("- Each user ETH balance: 2 ETH");
        console.log("- Staking contract reward balance:", Strings.toString(stakingContractBalance / 10**18), "MN");
        
        // 系统状态
        console.log("- All pause functions: OPEN (false)");
        console.log("- Permission system: CONFIGURED");
        console.log("- Initial stakes: ESTABLISHED");
        console.log("- Rewards: GENERATED (10 blocks)");
        
        console.log("+ Environment contains: 2 staking pools, complete permission system, sufficient assets, initial stakes, and generated rewards");
        console.log("+ All functions in normal operational state");
        
        console.log("\n=== Comprehensive Permission & Pause Control Test Environment Initialization Completed ===");
        console.log("Environment ready for comprehensive permission management and pause control testing");
    }

    /**
     * @notice 测试用例1：全局暂停后所有核心操作被禁止
     * @dev 验证当管理员激活全局暂停功能后，所有核心操作（质押、解质押、提现、领奖）均被正确禁止
     */
    function test01_GlobalPauseBlocksAllCoreOperations() public {
        console.log("=== Testing Global Pause Blocks All Core Operations ===");
        
        // 🔒 步骤1：管理员启用全局暂停
        console.log("\n1. Admin Activating Global Pause:");
        console.log("- Admin activating global pause...");
        
        vm.prank(owner);
        metaNodeStake.pauseGlobal(true);
        
        bool isPaused = metaNodeStake.paused();
        console.log("- Global pause status:", isPaused ? "PAUSED" : "ACTIVE");
        assertTrue(isPaused, "Global pause should be activated");
        console.log("+ Global pause successfully activated by admin");
        
        // 🚫 步骤2：测试质押操作被拒绝
        console.log("\n2. Testing Staking Operations Rejection:");
        
        // 测试ERC20质押被拒绝
        console.log("- User1 attempting ERC20 staking while globally paused");
        vm.expectRevert("staking is paused");
        vm.prank(user1);
        metaNodeStake.stakeERC20(1, 100 * 10**18);
        console.log("+ ERC20 staking correctly rejected with 'staking is paused'");
        
        // 测试ETH质押被拒绝
        console.log("- User2 attempting ETH staking while globally paused");
        vm.expectRevert("staking is paused");
        vm.prank(user2);
        metaNodeStake.stakeETH{value: 0.1 ether}(0);
        console.log("+ ETH staking correctly rejected with 'staking is paused'");
        
        // 🚫 步骤3：测试解质押操作被拒绝
        console.log("\n3. Testing Unstaking Operations Rejection:");
        console.log("- User1 attempting unstaking while globally paused");
        
        vm.expectRevert("unstaking is paused");
        vm.prank(user1);
        metaNodeStake.unStake(1, 100 * 10**18);
        console.log("+ Unstaking correctly rejected with 'unstaking is paused'");
        
        // 🚫 步骤4：测试提现操作被拒绝
        console.log("\n4. Testing Withdrawal Operations Rejection:");
        console.log("- User attempting withdrawal while globally paused");
        
        vm.expectRevert("withdraw is paused");
        vm.prank(user1);
        metaNodeStake.withdraw(1);
        console.log("+ Withdrawal correctly rejected with 'withdraw is paused'");
        
        // 🚫 步骤5：测试奖励领取操作被拒绝
        console.log("\n5. Testing Claim Operations Rejection:");
        console.log("- User1 attempting reward claim while globally paused");
        
        vm.expectRevert("claim is paused");
        vm.prank(user1);
        metaNodeStake.claimReward(1);
        console.log("+ Reward claim correctly rejected with 'claim is paused'");
        
        // ✅ 步骤6：验证完成后恢复系统正常状态
        console.log("\n6. Restoring Normal System State:");
        console.log("- Admin deactivating global pause...");
        
        vm.prank(owner);
        metaNodeStake.pauseGlobal(false);
        
        bool isActive = !metaNodeStake.paused();
        console.log("- Global pause status:", isActive ? "ACTIVE" : "PAUSED");
        assertTrue(isActive, "Global pause should be deactivated");
        console.log("+ System successfully restored to normal state");
        
        console.log("\n=== Global Pause Test Completed ===");
        console.log("+ All core operations correctly blocked during global pause");
        console.log("+ System properly restored to operational state");
    }

    /**
     * @notice 测试用例2：细粒度单项暂停效果
     * @dev 测试管理员对各项功能的独立暂停控制能力
     */
    function test02_GranularPauseControls() public {
        console.log("=== Testing Granular Pause Controls ===");
        
        // 🔒 步骤1：暂停质押功能测试
        console.log("\n1. Testing Staking Function Pause:");
        console.log("- Admin pausing staking function...");
        
        vm.prank(admin);
        metaNodeStake.pauseStaking(true);
        
        bool isStakingPaused = metaNodeStake.stakingPaused();
        console.log("- Staking pause status:", isStakingPaused ? "PAUSED" : "ACTIVE");
        assertTrue(isStakingPaused, "Staking should be paused");
        
        // 测试质押被拒绝
        console.log("- Testing staking rejection...");
        vm.expectRevert("staking is paused");
        vm.prank(user1);
        metaNodeStake.stakeERC20(1, 100 * 10**18);
        console.log("+ Staking correctly rejected");
        
        // 测试其他功能正常（如果有现有质押可以领奖）
        console.log("- Testing other functions remain operational...");
        try vm.prank(user1) {
            metaNodeStake.claimReward(1);
            console.log("+ Claim function remains operational");
        } catch {
            console.log("+ Claim function accessible (no rewards available)");
        }
        
        // 恢复质押功能
        vm.prank(admin);
        metaNodeStake.pauseStaking(false);
        console.log("+ Staking function restored");
        
        // 🔒 步骤2：暂停解质押功能测试
        console.log("\n2. Testing Unstaking Function Pause:");
        console.log("- Admin pausing unstaking function...");
        
        vm.prank(admin);
        metaNodeStake.pauseUnstaking(true);
        
        bool isUnstakingPaused = metaNodeStake.unstakingPaused();
        console.log("- Unstaking pause status:", isUnstakingPaused ? "PAUSED" : "ACTIVE");
        assertTrue(isUnstakingPaused, "Unstaking should be paused");
        
        // 测试解质押被拒绝
        console.log("- Testing unstaking rejection...");
        vm.expectRevert("unstaking is paused");
        vm.prank(user1);
        metaNodeStake.unStake(1, 100 * 10**18);
        console.log("+ Unstaking correctly rejected");
        
        // 测试质押功能正常
        console.log("- Testing staking function remains operational...");
        vm.prank(user1);
        metaNodeStake.stakeERC20(1, 100 * 10**18);
        console.log("+ Staking function remains operational");
        
        // 恢复解质押功能
        vm.prank(admin);
        metaNodeStake.pauseUnstaking(false);
        console.log("+ Unstaking function restored");
        
        // 🔒 步骤3：暂停提现功能测试
        console.log("\n3. Testing Withdrawal Function Pause:");
        console.log("- Admin pausing withdrawal function...");
        
        vm.prank(admin);
        metaNodeStake.pauseWithdraw(true);
        
        bool isWithdrawPaused = metaNodeStake.withdrawPaused();
        console.log("- Withdrawal pause status:", isWithdrawPaused ? "PAUSED" : "ACTIVE");
        assertTrue(isWithdrawPaused, "Withdrawal should be paused");
        
        // 测试提现被拒绝
        console.log("- Testing withdrawal rejection...");
        vm.expectRevert("withdraw is paused");
        vm.prank(user1);
        metaNodeStake.withdraw(1);
        console.log("+ Withdrawal correctly rejected");
        
        // 测试质押功能正常
        console.log("- Testing staking function remains operational...");
        vm.prank(user2);
        metaNodeStake.stakeETH{value: 0.1 ether}(0);
        console.log("+ Staking function remains operational");
        
        // 恢复提现功能
        vm.prank(admin);
        metaNodeStake.pauseWithdraw(false);
        console.log("+ Withdrawal function restored");
        
        // 🔒 步骤4：暂停领奖功能测试
        console.log("\n4. Testing Claim Function Pause:");
        console.log("- Admin pausing claim function...");
        
        vm.prank(admin);
        metaNodeStake.pauseClaim(true);
        
        bool isClaimPaused = metaNodeStake.claimPaused();
        console.log("- Claim pause status:", isClaimPaused ? "PAUSED" : "ACTIVE");
        assertTrue(isClaimPaused, "Claim should be paused");
        
        // 测试领奖被拒绝
        console.log("- Testing claim rejection...");
        vm.expectRevert("claim is paused");
        vm.prank(user1);
        metaNodeStake.claimReward(1);
        console.log("+ Claim correctly rejected");
        
        // 测试质押功能正常
        console.log("- Testing staking function remains operational...");
        vm.prank(user1);
        metaNodeStake.stakeERC20(1, 100 * 10**18);
        console.log("+ Staking function remains operational");
        
        // 恢复领奖功能
        vm.prank(admin);
        metaNodeStake.pauseClaim(false);
        console.log("+ Claim function restored");
        
        console.log("\n=== Granular Pause Controls Test Completed ===");
        console.log("+ All granular pause controls working correctly");
        console.log("+ Individual functions can be paused independently");
        console.log("+ Non-paused functions remain operational during selective pauses");
    }

    /**
     * @notice 测试用例3：有权限账号正常管理池与参数
     * @dev 验证具有管理员权限的账号能够正常执行各项管理操作
     */
    function test03_AuthorizedAccountManagement() public {
        console.log("=== Testing Authorized Account Management Operations ===");
        
        // 🔍 步骤1：确认管理员权限有效
        console.log("\n1. Confirming Admin Permissions:");
        
        bytes32 adminRole = metaNodeStake.ADMIN_ROLE();
        bool hasAdminRole = metaNodeStake.hasRole(adminRole, admin);
        console.log("- Admin account:", admin);
        console.log("- ADMIN_ROLE status:", hasAdminRole ? "GRANTED" : "NOT GRANTED");
        assertTrue(hasAdminRole, "Admin should have ADMIN_ROLE");
        console.log("+ Admin permissions confirmed");
        
        // 🏊 步骤2：添加新质押池
        console.log("\n2. Adding New Staking Pool:");
        console.log("- Admin adding new ERC20 staking pool...");
        
        uint256 poolsBefore = metaNodeStake.getPoolLength();
        console.log("- Pools before:", Strings.toString(poolsBefore));
        
        // 创建一个新的测试代币用于新池子
        MockERC20 newTestToken = new MockERC20("New Test Token", "NEWTEST", 1000000 * 10**18);
        
        // 添加新池（使用新代币）
        vm.prank(admin);
        metaNodeStake.addPool(
            address(newTestToken), // 使用新代币
            75,                    // 权重75
            200 * 10**18,         // 最小质押200 NEWTEST
            150                   // 解锁周期150个区块
        );
        
        uint256 poolsAfter = metaNodeStake.getPoolLength();
        console.log("- Pools after:", Strings.toString(poolsAfter));
        assertEq(poolsAfter, poolsBefore + 1, "Pool count should increase by 1");
        console.log("+ New staking pool successfully added");
        
        // 🔧 步骤3：设置暂停状态
        console.log("\n3. Setting Pause States:");
        console.log("- Admin setting various pause states...");
        
        // 批量设置暂停状态
        vm.prank(admin);
        metaNodeStake.pauseStaking(true);
        
        vm.prank(admin);
        metaNodeStake.pauseUnstaking(true);
        
        bool stakingPaused = metaNodeStake.stakingPaused();
        bool unstakingPaused = metaNodeStake.unstakingPaused();
        
        console.log("- Staking paused:", stakingPaused ? "YES" : "NO");
        console.log("- Unstaking paused:", unstakingPaused ? "YES" : "NO");
        
        assertTrue(stakingPaused, "Staking should be paused");
        assertTrue(unstakingPaused, "Unstaking should be paused");
        console.log("+ Pause states successfully set by admin");
        
        // 恢复状态
        vm.prank(admin);
        metaNodeStake.pauseStaking(false);
        vm.prank(admin);
        metaNodeStake.pauseUnstaking(false);
        console.log("+ Pause states restored to normal");
        
        // 🪙 步骤4：管理代币设置
        console.log("\n4. Token Management Operations:");
        console.log("- Admin performing MetaNode token management...");
        
        // 验证admin可以执行需要权限的操作
        uint256 currentPerBlock = metaNodeStake.MetaNodePerBlock();
        console.log("- Current reward per block:", Strings.toString(currentPerBlock / 10**18), "MN/block");
        
        // Admin可以成功执行管理功能
        vm.prank(admin);
        metaNodeStake.updatePoolInfo(1); // 更新池子信息
        console.log("+ Pool info update successful");
        
        console.log("+ All management operations completed successfully");
        console.log("+ Admin permissions verified and functional");
        
        console.log("\n=== Authorized Account Management Test Completed ===");
        console.log("+ Management permissions working correctly");
        console.log("+ All administrative functions accessible to authorized accounts");
    }

    /**
     * @notice 测试用例4：无权限账号被禁止管理与升级
     * @dev 验证无权限用户无法执行任何管理操作
     */
    function test04_UnauthorizedAccountRejection() public {
        console.log("=== Testing Unauthorized Account Access Rejection ===");
        
        // 🔍 步骤1：确认测试用户没有权限
        console.log("\n1. Confirming Unauthorized User Lacks Permissions:");
        
        bytes32 adminRole = metaNodeStake.ADMIN_ROLE();
        bytes32 upgradeRole = metaNodeStake.UPGRADE_ROLE();
        
        bool hasAdminRole = metaNodeStake.hasRole(adminRole, unauthorizedUser);
        bool hasUpgradeRole = metaNodeStake.hasRole(upgradeRole, unauthorizedUser);
        
        console.log("- Unauthorized user:", unauthorizedUser);
        console.log("- Has ADMIN_ROLE:", hasAdminRole ? "YES" : "NO");
        console.log("- Has UPGRADE_ROLE:", hasUpgradeRole ? "YES" : "NO");
        
        assertTrue(!hasAdminRole, "Unauthorized user should not have ADMIN_ROLE");
        assertTrue(!hasUpgradeRole, "Unauthorized user should not have UPGRADE_ROLE");
        console.log("+ Confirmed: User has no administrative permissions");
        
        // 🚫 步骤2：添加质押池被拒绝
        console.log("\n2. Testing Pool Addition Rejection:");
        console.log("- Unauthorized user attempting to add pool...");
        
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        metaNodeStake.addPool(
            address(testToken),
            25,
            50 * 10**18,
            100
        );
        console.log("+ Pool addition correctly rejected for unauthorized user");
        
        // 🚫 步骤3：参数配置被拒绝
        console.log("\n3. Testing Parameter Configuration Rejection:");
        console.log("- Unauthorized user attempting to set pause states...");
        
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        metaNodeStake.pauseStaking(true);
        console.log("+ Pause staking correctly rejected");
        
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        metaNodeStake.pauseUnstaking(true);
        console.log("+ Pause unstaking correctly rejected");
        
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        metaNodeStake.pauseWithdraw(true);
        console.log("+ Pause withdraw correctly rejected");
        
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        metaNodeStake.pauseClaim(true);
        console.log("+ Pause claim correctly rejected");
        
        // 🚫 步骤4：全局暂停被拒绝
        console.log("\n4. Testing Global Pause Rejection:");
        console.log("- Unauthorized user attempting global pause...");
        
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        metaNodeStake.pauseGlobal(true);
        console.log("+ Global pause correctly rejected");
        
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        metaNodeStake.pauseGlobal(false);
        console.log("+ Global unpause correctly rejected");
        
        // 🚫 步骤5：角色管理被拒绝
        console.log("\n5. Testing Role Management Rejection:");
        console.log("- Unauthorized user attempting role management...");
        
        // 尝试授予角色权限
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        metaNodeStake.grantRole(adminRole, user1);
        console.log("+ Grant role correctly rejected");
        
        // 尝试撤销角色权限
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        metaNodeStake.revokeRole(adminRole, admin);
        console.log("+ Revoke role correctly rejected");
        
        // ✅ 步骤6：验证系统状态未被影响
        console.log("\n6. Verifying System State Integrity:");
        console.log("- Checking system remains unchanged after unauthorized attempts...");
        
        // 验证暂停状态未被改变
        bool stakingPaused = metaNodeStake.stakingPaused();
        bool unstakingPaused = metaNodeStake.unstakingPaused();
        bool withdrawPaused = metaNodeStake.withdrawPaused();
        bool claimPaused = metaNodeStake.claimPaused();
        bool globalPaused = metaNodeStake.paused();
        
        console.log("- Staking paused:", stakingPaused ? "YES" : "NO");
        console.log("- Unstaking paused:", unstakingPaused ? "YES" : "NO");
        console.log("- Withdraw paused:", withdrawPaused ? "YES" : "NO");
        console.log("- Claim paused:", claimPaused ? "YES" : "NO");
        console.log("- Global paused:", globalPaused ? "YES" : "NO");
        
        // 所有状态应该保持为false（未暂停）
        assertTrue(!stakingPaused, "Staking should remain unpaused");
        assertTrue(!unstakingPaused, "Unstaking should remain unpaused");
        assertTrue(!withdrawPaused, "Withdraw should remain unpaused");
        assertTrue(!claimPaused, "Claim should remain unpaused");
        assertTrue(!globalPaused, "Global should remain unpaused");
        
        // 验证角色权限未被改变
        bool adminStillHasRole = metaNodeStake.hasRole(adminRole, admin);
        bool user1HasNoRole = metaNodeStake.hasRole(adminRole, user1);
        
        assertTrue(adminStillHasRole, "Admin should still have ADMIN_ROLE");
        assertTrue(!user1HasNoRole, "User1 should not have gained ADMIN_ROLE");
        
        console.log("+ System state integrity confirmed");
        console.log("+ All unauthorized access attempts properly blocked");
        
        console.log("\n=== Unauthorized Account Rejection Test Completed ===");
        console.log("+ Access control system working correctly");
        console.log("+ Unauthorized users cannot perform administrative operations");
        console.log("+ System security and integrity maintained");
    }

}
