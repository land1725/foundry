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
 * @title StakingUnstakingPauseTest
 * @notice 质押、解除质押和暂停功能测试套件
 * @dev 测试质押操作、解除质押操作和系统暂停功能
 */
contract StakingUnstakingPauseTest is Test {
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
    
    // 质押池参数
    uint256 public constant ETH_POOL_WEIGHT = 100;
    uint256 public constant ETH_MIN_DEPOSIT = 0.01 ether;
    uint256 public constant ETH_UNSTAKE_BLOCKS = 100;
    
    uint256 public constant ERC20_POOL_WEIGHT = 50;
    uint256 public constant ERC20_MIN_DEPOSIT = 100 * 10**18;  // 100个TEST代币
    uint256 public constant ERC20_UNSTAKE_BLOCKS = 200;
    
    // 用户资金分配
    uint256 public constant USER1_TOKEN_AMOUNT = 10_000 * 10**18;  // 1万个TEST代币
    uint256 public constant USER2_TOKEN_AMOUNT = 5_000 * 10**18;   // 5千个TEST代币
    uint256 public constant APPROVAL_AMOUNT = 50_000 * 10**18;     // 5万个TEST代币授权额度

        // ！！！事件定义部分！！！
    // 这里定义我们要验证的事件，必须与合约中的事件定义完全一致
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event RequestUnstake(address indexed user, uint256 indexed pid, uint256 amount);

    /**
     * @notice 测试环境初始化设置
     * @dev 部署所有必要的合约、创建质押池、分配资金并进行初始配置
     */
    function setUp() public {
        console.log("=== Staking and Unstaking Test Environment Initialization ===");
        console.log("Starting simulation environment for staking and unstaking functionality testing...");
        
        // 🎯 步骤1：获取和设定三个核心角色
        console.log("\n1. Core Role Setup:");
        owner = address(0x1);  // 拥有者（部署和管理员）
        user1 = address(0x2);  // 测试用户1
        user2 = address(0x3);  // 测试用户2
        
        console.log("- Owner (Deployer & Admin):", owner);
        console.log("- Test User 1:", user1);
        console.log("- Test User 2:", user2);
        console.log("+ Role addresses recorded for subsequent tracking");
        
        // 🚀 步骤2：部署整套智能合约系统
        console.log("\n2. Smart Contract System Deployment:");
        _deployMetaNodeContract();
        _deployMetaNodeStakeContract();
        
        // 🔍 步骤3：定位并获取核心代币合约
        console.log("\n3. Core Token Contract Location:");
        console.log("- MetaNode token contract address:", address(metaNode));
        console.log("- MetaNode token name:", metaNode.name());
        console.log("- MetaNode token symbol:", metaNode.symbol());
        console.log("+ Core token contract located and recorded");
        
        // 🏦 步骤4：定位并获取质押主合约
        console.log("\n4. Main Staking Contract Location:");
        console.log("- MetaNodeStake contract address:", address(metaNodeStake));
        console.log("- Reward token address:", address(metaNodeStake.MetaNode()));
        console.log("+ Main staking contract located and recorded");
        
        // 🪙 步骤5：部署测试用ERC20代币
        console.log("\n5. Test Token Deployment:");
        _deployTestToken();
        
        // 🏊‍♂️ 步骤6：创建两个不同类型的质押资金池
        console.log("\n6. Staking Pool Creation:");
        _createStakingPools();
        
        // 💰 步骤7：为测试用户准备充足的代币资金并完成授权
        console.log("\n7. User Fund Preparation and Authorization:");
        _prepareFundsAndAuthorizations();
        
        // ⚙️ 步骤8：验证系统关键功能开关的初始状态
        console.log("\n8. System Function Status Verification:");
        _verifySystemStatus();
        
        // ✅ 步骤9：初始化完成并汇总状态
        console.log("\n9. Initialization Summary:");
        _displayEnvironmentSummary();
        
        console.log("\n=== Staking and Unstaking Test Environment Ready ===");
    }

    /**
     * @dev 部署 MetaNode 代币合约（使用 UUPS 代理模式）
     */
    function _deployMetaNodeContract() private {
        console.log("Deploying MetaNode token contract...");
        
        // 部署逻辑合约
        MetaNode metaNodeLogic = new MetaNode();
        console.log("- MetaNode logic contract address:", address(metaNodeLogic));
        
        // 准备初始化数据
        bytes memory metaNodeInitData = abi.encodeWithSelector(
            MetaNode.initialize.selector, 
            owner, // recipient - 接收初始代币的地址
            owner  // initialOwner - 初始管理员
        );
        
        // 使用 vm.prank 确保初始化时的 msg.sender 是 owner
        vm.prank(owner);
        ERC1967Proxy metaNodeProxy = new ERC1967Proxy(
            address(metaNodeLogic), 
            metaNodeInitData
        );
        
        metaNode = MetaNode(address(metaNodeProxy));
        console.log("- MetaNode proxy contract address:", address(metaNode));
        
        // 验证部署结果
        assertTrue(address(metaNode) != address(0), "MetaNode contract address invalid");
        assertTrue(metaNode.totalSupply() == INITIAL_SUPPLY, "MetaNode total supply incorrect");
        assertTrue(metaNode.balanceOf(owner) == INITIAL_SUPPLY, "Owner initial balance incorrect");
        assertEq(metaNode.owner(), owner, "MetaNode owner incorrect");
        console.log("+ MetaNode contract deployment verified");
    }
    
    /**
     * @dev 部署 MetaNodeStake 质押合约（使用 UUPS 代理模式）
     */
    function _deployMetaNodeStakeContract() private {
        console.log("Deploying MetaNodeStake staking contract...");
        
        // 部署逻辑合约
        MetaNodeStake metaNodeStakeLogic = new MetaNodeStake();
        console.log("- MetaNodeStake logic contract address:", address(metaNodeStakeLogic));
        
        // 准备初始化数据
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
        console.log("- MetaNodeStake proxy contract address:", address(metaNodeStake));
        
        // 验证部署结果
        assertTrue(address(metaNodeStake) != address(0), "MetaNodeStake contract address invalid");
        assertTrue(address(metaNodeStake.MetaNode()) == address(metaNode), "Token address in MetaNodeStake incorrect");
        assertTrue(metaNodeStake.MetaNodePerBlock() == META_NODE_PER_BLOCK, "Reward per block incorrect");
        console.log("+ MetaNodeStake contract deployment verified");
    }
    
    /**
     * @dev 部署用于测试的 TEST 代币
     */
    function _deployTestToken() private {
        console.log("Deploying Test Token (TEST) with 1,000,000 supply...");
        
        vm.prank(owner);
        testToken = new MockERC20(
            "Test Token",      // 代币名称
            "TEST",           // 代币符号
            TEST_TOKEN_SUPPLY // 初始供应量
        );
        
        console.log("- Test Token contract address:", address(testToken));
        console.log("- Test Token name:", testToken.name());
        console.log("- Test Token symbol:", testToken.symbol());
        console.log("- Test Token total supply:", Strings.toString(testToken.totalSupply() / 10**18), "TEST");
        console.log("- Owner balance:", Strings.toString(testToken.balanceOf(owner) / 10**18), "TEST");
        
        // 验证部署结果
        assertTrue(address(testToken) != address(0), "TestToken contract address invalid");
        assertTrue(testToken.totalSupply() == TEST_TOKEN_SUPPLY, "TestToken total supply incorrect");
        assertTrue(testToken.balanceOf(owner) == TEST_TOKEN_SUPPLY, "Owner TestToken balance incorrect");
        assertEq(testToken.owner(), owner, "TestToken owner incorrect");
        console.log("+ Test Token deployment completed with 1,000,000 tokens (18 decimals)");
    }

    /**
     * @notice 创建质押池
     * @dev 创建ETH池和ERC20代币池
     */
    function _createStakingPools() private {
        console.log("Creating staking pools...");
        
        // 创建ETH池（编号0）
        console.log("- Creating ETH Pool (Pool #0):");
        console.log("  - Pool Type: Native ETH");
        console.log("  - Pool Weight:", ETH_POOL_WEIGHT);
        console.log("  - Minimum Deposit:", Strings.toString(ETH_MIN_DEPOSIT / 10**18), "ETH");
        console.log("  - Unlock Period:", ETH_UNSTAKE_BLOCKS, "blocks");
        
        vm.prank(owner);
        metaNodeStake.addPool(
            address(0),           // ETH池使用零地址
            ETH_POOL_WEIGHT,      // 权重100
            ETH_MIN_DEPOSIT,      // 最少质押0.01 ETH
            ETH_UNSTAKE_BLOCKS    // 解锁等待期100个区块
        );
        console.log("+ ETH Pool created successfully");
        
        // 创建ERC20代币池（编号1）
        console.log("- Creating ERC20 Token Pool (Pool #1):");
        console.log("  - Pool Type: TEST Token");
        console.log("  - Token Address:", address(testToken));
        console.log("  - Pool Weight:", ERC20_POOL_WEIGHT);
        console.log("  - Minimum Deposit:", Strings.toString(ERC20_MIN_DEPOSIT / 10**18), "TEST");
        console.log("  - Unlock Period:", ERC20_UNSTAKE_BLOCKS, "blocks");
        
        vm.prank(owner);
        metaNodeStake.addPool(
            address(testToken),    // TEST代币地址
            ERC20_POOL_WEIGHT,     // 权重50
            ERC20_MIN_DEPOSIT,     // 最少质押100个TEST代币
            ERC20_UNSTAKE_BLOCKS   // 解锁等待期200个区块
        );
        console.log("+ ERC20 Token Pool created successfully");
        
        console.log("+ Two staking pools created: ETH Pool + ERC20 Token Pool");
    }

    /**
     * @notice 为测试用户准备资金并完成授权
     * @dev 分配TEST代币给用户并授权质押合约
     */
    function _prepareFundsAndAuthorizations() private {
        console.log("Preparing user funds and authorizations...");
        
        // 给用户1分配代币 (使用owner身份转账)
        console.log("- Allocating tokens to User1:");
        vm.prank(owner);
        testToken.transfer(user1, USER1_TOKEN_AMOUNT);
        console.log("  - Amount transferred:", Strings.toString(USER1_TOKEN_AMOUNT / 10**18), "TEST tokens");
        console.log("  - User1 TEST balance:", Strings.toString(testToken.balanceOf(user1) / 10**18), "TEST");
        
        // 给用户2分配代币 (使用owner身份转账)
        console.log("- Allocating tokens to User2:");
        vm.prank(owner);
        testToken.transfer(user2, USER2_TOKEN_AMOUNT);
        console.log("  - Amount transferred:", Strings.toString(USER2_TOKEN_AMOUNT / 10**18), "TEST tokens");
        console.log("  - User2 TEST balance:", Strings.toString(testToken.balanceOf(user2) / 10**18), "TEST");
        
        // 用户1授权质押合约
        console.log("- Setting up User1 authorization:");
        vm.prank(user1);
        testToken.approve(address(metaNodeStake), APPROVAL_AMOUNT);
        console.log("  - Authorized amount:", Strings.toString(APPROVAL_AMOUNT / 10**18), "TEST tokens");
        
        // 用户2授权质押合约
        console.log("- Setting up User2 authorization:");
        vm.prank(user2);
        testToken.approve(address(metaNodeStake), APPROVAL_AMOUNT);
        console.log("  - Authorized amount:", Strings.toString(APPROVAL_AMOUNT / 10**18), "TEST tokens");
        
        console.log("+ User fund allocation and authorization completed");
        console.log("+ Both users ready for staking operations");
    }

    /**
     * @notice 验证系统功能状态
     * @dev 检查质押、解除质押、提取和奖励功能的暂停状态
     */
    function _verifySystemStatus() private view {
        console.log("Verifying system function status...");
        
        bool stakePaused = metaNodeStake.stakingPaused();
        bool unstakePaused = metaNodeStake.unstakingPaused();
        bool withdrawPaused = metaNodeStake.withdrawPaused();
        bool claimPaused = metaNodeStake.claimPaused();
        
        console.log("- Staking function paused:", stakePaused ? "YES" : "NO");
        console.log("- Unstaking function paused:", unstakePaused ? "YES" : "NO");
        console.log("- Withdrawal function paused:", withdrawPaused ? "YES" : "NO");
        console.log("- Claim rewards function paused:", claimPaused ? "YES" : "NO");
        
        // 验证所有功能都处于开放状态
        require(!stakePaused, "Staking should not be paused initially");
        require(!unstakePaused, "Unstaking should not be paused initially");
        require(!withdrawPaused, "Withdrawal should not be paused initially");
        require(!claimPaused, "Claim should not be paused initially");
        
        console.log("+ All core functions are in open state (not paused)");
        console.log("+ System ready for normal operation testing");
    }

    /**
     * @notice 显示环境初始化汇总信息
     * @dev 展示当前环境的整体状态
     */
    function _displayEnvironmentSummary() private view {
        console.log("Environment initialization completed. Current state summary:");
        
        // 质押池信息
        uint256 poolCount = metaNodeStake.getPoolLength();
        console.log("- Total staking pools created:", poolCount);
        
        // 各池最低质押门槛
        console.log("- ETH Pool minimum deposit:", Strings.toString(ETH_MIN_DEPOSIT / 10**18), "ETH");
        console.log("- ERC20 Pool minimum deposit:", Strings.toString(ERC20_MIN_DEPOSIT / 10**18), "TEST tokens");
        
        // 用户1资金状态
        uint256 user1EthBalance = user1.balance;
        uint256 user1TestBalance = testToken.balanceOf(user1);
        console.log("- User1 ETH balance:", Strings.toString(user1EthBalance / 10**18), "ETH");
        console.log("- User1 TEST token balance:", Strings.toString(user1TestBalance / 10**18), "TEST");
        
        // 系统总体状态
        uint256 totalPoolWeight = metaNodeStake.totalPoolWeight();
        console.log("- Total pool weight:", totalPoolWeight);
        console.log("- System status: Ready for staking and unstaking tests");
        
        console.log("+ Environment summary display completed");
    }

    /**
     * @notice 测试ERC20代币质押功能
     * @dev 验证ERC20代币质押功能是否正常工作
     */
    function test01_ERC20StakingFunction() public {
        console.log("=== Testing ERC20 Token Staking Function ===");
        
        // 🔍 步骤1：前置条件检查 (Arrange)
        console.log("\n1. Pre-condition Verification:");
        
        uint256 poolId = 1; // ERC20池的ID
        uint256 stakeAmount = 500 * 10**18; // 质押500个TEST代币
        
        // 检查用户代币余额
        uint256 userBalanceBefore = testToken.balanceOf(user1);
        console.log("- User1 TEST token balance:", Strings.toString(userBalanceBefore / 10**18), "TEST");
        require(userBalanceBefore >= stakeAmount, "User1 insufficient balance");
        console.log("+ User1 has sufficient balance for staking");
        
        // 检查授权额度
        uint256 allowance = testToken.allowance(user1, address(metaNodeStake));
        console.log("- User1 allowance to staking contract:", Strings.toString(allowance / 10**18), "TEST");
        require(allowance >= stakeAmount, "User1 insufficient allowance");
        console.log("+ User1 has sufficient allowance for staking");
        
        // 检查质押数量是否大于最小限额
        console.log("- Stake amount:", Strings.toString(stakeAmount / 10**18), "TEST");
        console.log("- Minimum deposit required:", Strings.toString(ERC20_MIN_DEPOSIT / 10**18), "TEST");
        require(stakeAmount >= ERC20_MIN_DEPOSIT, "Stake amount below minimum");
        console.log("+ Stake amount meets minimum deposit requirement");
        
        // 记录质押前的状态
        console.log("\n2. Recording Pre-stake State:");
        
        // 记录质押前的资金池总量
        (,,,,uint256 poolTotalAmountBefore,,) = metaNodeStake.pool(poolId);
        console.log("- Pool total amount before:", Strings.toString(poolTotalAmountBefore / 10**18), "TEST");
        
        // 记录用户质押前的质押量
        (uint256 userStakeAmountBefore,,) = metaNodeStake.user(poolId, user1);
        console.log("- User stake amount before:", Strings.toString(userStakeAmountBefore / 10**18), "TEST");
        
        console.log("+ Pre-stake state recorded");
        
        // 🚀 步骤2：执行质押操作 (Act)
        console.log("\n3. Executing Staking Operation:");
        console.log("- Staking", Strings.toString(stakeAmount / 10**18), "TEST tokens to pool", poolId);
        
        // ！！！核心部分：期望事件验证！！！ 
        // 我们期望接下来由 metaNodeStake 合约发出一个 Deposit 事件
        vm.expectEmit(true, true, true, true);

        // 发出我们期望的事件签名和参数
        // 参数的顺序和类型必须与合约中定义的 Deposit 事件完全一致
        emit Deposit(user1, 1, stakeAmount);
        
        // 执行质押操作 (使用stakeERC20函数)
        vm.prank(user1);
        metaNodeStake.stakeERC20(poolId, stakeAmount);
        
        console.log("+ Staking operation executed successfully");
        
        // ✅ 步骤3：验证结果 (Assert)
        console.log("\n4. Verifying Staking Results:");
        
        // 验证用户质押余额增加
        (uint256 userStakeAmountAfter,,) = metaNodeStake.user(poolId, user1);
        uint256 expectedUserStake = userStakeAmountBefore + stakeAmount;
        console.log("- User stake amount after:", Strings.toString(userStakeAmountAfter / 10**18), "TEST");
        console.log("- Expected user stake amount:", Strings.toString(expectedUserStake / 10**18), "TEST");
        assertEq(userStakeAmountAfter, expectedUserStake, "User stake amount should increase correctly");
        console.log("+ User stake balance increased correctly");
        
        // 验证资金池总量增加
        (,,,,uint256 poolTotalAmountAfter,,) = metaNodeStake.pool(poolId);
        uint256 expectedPoolTotal = poolTotalAmountBefore + stakeAmount;
        console.log("- Pool total amount after:", Strings.toString(poolTotalAmountAfter / 10**18), "TEST");
        console.log("- Expected pool total amount:", Strings.toString(expectedPoolTotal / 10**18), "TEST");
        assertEq(poolTotalAmountAfter, expectedPoolTotal, "Pool total amount should increase correctly");
        console.log("+ Pool total amount increased correctly");
        
        // 验证用户代币余额减少
        uint256 userBalanceAfter = testToken.balanceOf(user1);
        uint256 expectedUserBalance = userBalanceBefore - stakeAmount;
        console.log("- User TEST balance after:", Strings.toString(userBalanceAfter / 10**18), "TEST");
        console.log("- Expected user balance:", Strings.toString(expectedUserBalance / 10**18), "TEST");
        assertEq(userBalanceAfter, expectedUserBalance, "User token balance should decrease correctly");
        console.log("+ User token balance decreased correctly");
        
        // 验证代币转移到质押合约
        uint256 contractBalance = testToken.balanceOf(address(metaNodeStake));
        console.log("- Staking contract TEST balance:", Strings.toString(contractBalance / 10**18), "TEST");
        require(contractBalance >= stakeAmount, "Contract should receive staked tokens");
        console.log("+ Tokens successfully transferred to staking contract");
        
        console.log("\n=== ERC20 Token Staking Function Test Completed Successfully ===");
        console.log("+ All conditions met expectations - Test PASSED");
    }

    /**
     * @notice 测试ETH质押功能
     * @dev 验证ETH质押功能是否正常工作
     */
    function test02_ETHStakingFunction() public {
        console.log("=== Testing ETH Staking Function ===");
        
        // 🔍 步骤1：前置条件检查 (Arrange)
        console.log("\n1. Pre-condition Verification:");
        
        uint256 poolId = 0; // ETH池的ID
        uint256 stakeAmount = 0.1 ether; // 质押0.1 ETH
        
        // 为user1分配ETH余额
        vm.deal(user1, 1 ether); // 给user1分配1个ETH
        
        // 检查用户ETH余额
        uint256 userBalanceBefore = user1.balance;
        console.log("- User1 ETH balance:", Strings.toString(userBalanceBefore / 10**18), "ETH");
        require(userBalanceBefore >= stakeAmount, "User1 insufficient ETH balance");
        console.log("+ User1 has sufficient ETH balance for staking");
        
        // 检查质押数量是否大于最小限额
        console.log("- Stake amount:", Strings.toString(stakeAmount / 10**18), "ETH");
        console.log("- Minimum deposit required:", Strings.toString(ETH_MIN_DEPOSIT / 10**18), "ETH");
        require(stakeAmount >= ETH_MIN_DEPOSIT, "Stake amount below minimum");
        console.log("+ Stake amount meets minimum deposit requirement");
        
        // 记录质押前的状态
        console.log("\n2. Recording Pre-stake State:");
        
        // 记录质押前的资金池总量
        (,,,,uint256 poolTotalAmountBefore,,) = metaNodeStake.pool(poolId);
        console.log("- Pool total amount before:", Strings.toString(poolTotalAmountBefore / 10**18), "ETH");
        
        // 记录用户质押前的质押量
        (uint256 userStakeAmountBefore,,) = metaNodeStake.user(poolId, user1);
        console.log("- User stake amount before:", Strings.toString(userStakeAmountBefore / 10**18), "ETH");
        
        // 记录合约ETH余额
        uint256 contractBalanceBefore = address(metaNodeStake).balance;
        console.log("- Staking contract ETH balance before:", Strings.toString(contractBalanceBefore / 10**18), "ETH");
        
        console.log("+ Pre-stake state recorded");
        
        // 🚀 步骤2：执行质押操作 (Act)
        console.log("\n3. Executing ETH Staking Operation:");
        console.log("- Staking", Strings.toString(stakeAmount / 10**18), "ETH to pool", poolId);
        
        // ！！！核心部分：期望事件验证！！！ 
        // 我们期望接下来由 metaNodeStake 合约发出一个 Deposit 事件
        vm.expectEmit(true, true, true, true);

        // 发出我们期望的事件签名和参数
        // 参数的顺序和类型必须与合约中定义的 Deposit 事件完全一致
        emit Deposit(user1, 0, stakeAmount);
        
        // 执行ETH质押操作 (使用stakeETH函数，发送ETH)
        vm.prank(user1);
        metaNodeStake.stakeETH{value: stakeAmount}(poolId);
        
        console.log("+ ETH staking operation executed successfully");
        
        // ✅ 步骤3：验证结果 (Assert)
        console.log("\n4. Verifying ETH Staking Results:");
        
        // 验证用户质押余额增加
        (uint256 userStakeAmountAfter,,) = metaNodeStake.user(poolId, user1);
        uint256 expectedUserStake = userStakeAmountBefore + stakeAmount;
        console.log("- User stake amount after:", Strings.toString(userStakeAmountAfter / 10**18), "ETH");
        console.log("- Expected user stake amount:", Strings.toString(expectedUserStake / 10**18), "ETH");
        assertEq(userStakeAmountAfter, expectedUserStake, "User stake amount should increase correctly");
        console.log("+ User stake balance increased correctly");
        
        // 验证资金池总量增加
        (,,,,uint256 poolTotalAmountAfter,,) = metaNodeStake.pool(poolId);
        uint256 expectedPoolTotal = poolTotalAmountBefore + stakeAmount;
        console.log("- Pool total amount after:", Strings.toString(poolTotalAmountAfter / 10**18), "ETH");
        console.log("- Expected pool total amount:", Strings.toString(expectedPoolTotal / 10**18), "ETH");
        assertEq(poolTotalAmountAfter, expectedPoolTotal, "Pool total amount should increase correctly");
        console.log("+ Pool total amount increased correctly");
        
        // 验证用户ETH余额减少
        uint256 userBalanceAfter = user1.balance;
        uint256 expectedUserBalance = userBalanceBefore - stakeAmount;
        console.log("- User ETH balance after:", Strings.toString(userBalanceAfter / 10**18), "ETH");
        console.log("- Expected user balance:", Strings.toString(expectedUserBalance / 10**18), "ETH");
        assertEq(userBalanceAfter, expectedUserBalance, "User ETH balance should decrease correctly");
        console.log("+ User ETH balance decreased correctly");
        
        // 验证ETH转移到质押合约
        uint256 contractBalanceAfter = address(metaNodeStake).balance;
        uint256 expectedContractBalance = contractBalanceBefore + stakeAmount;
        console.log("- Staking contract ETH balance after:", Strings.toString(contractBalanceAfter / 10**18), "ETH");
        console.log("- Expected contract balance:", Strings.toString(expectedContractBalance / 10**18), "ETH");
        assertEq(contractBalanceAfter, expectedContractBalance, "Contract should receive staked ETH");
        console.log("+ ETH successfully transferred to staking contract");
        
        console.log("\n=== ETH Staking Function Test Completed Successfully ===");
        console.log("+ All conditions met expectations - Test PASSED");
    }

    /**
     * @notice 测试用例3：低于最小限额质押被拒绝
     * @dev 验证当用户尝试质押低于资金池设定的最小金额时，系统是否能正确拒绝操作
     */
    function test03_StakingBelowMinimumAmountRejected() public {
        console.log("=== Testing Staking Below Minimum Amount Rejection ===");
        
        // 🔍 步骤1：确认最小质押限额配置
        console.log("\n1. Verifying Minimum Deposit Configuration:");
        console.log("- ETH Pool minimum deposit:", Strings.toString(ETH_MIN_DEPOSIT / 10**18), "ETH");
        console.log("- ERC20 Pool minimum deposit:", Strings.toString(ERC20_MIN_DEPOSIT / 10**18), "TEST");
        
        // 🚫 步骤2：测试ETH低于最小限额质押
        console.log("\n2. Testing ETH Staking Below Minimum:");
        
        uint256 ethPoolId = 0;
        uint256 lowEthAmount = 0.005 ether; // 低于0.01 ETH的金额
        
        // 给user1分配足够的ETH
        vm.deal(user1, 1 ether);
        
        console.log("- Attempting to stake", Strings.toString(lowEthAmount / 10**15), "mETH (below minimum)");
        console.log("- Expected: Transaction should be rejected");
        
        // 预期交易被拒绝
        vm.expectRevert("amount is less than minDepositAmount");
        vm.prank(user1);
        metaNodeStake.stakeETH{value: lowEthAmount}(ethPoolId);
        
        console.log("+ ETH low amount staking correctly rejected");
        
        // 🚫 步骤3：测试ERC20低于最小限额质押
        console.log("\n3. Testing ERC20 Staking Below Minimum:");
        
        uint256 erc20PoolId = 1;
        uint256 lowTokenAmount = 50 * 10**18; // 低于100 TEST的金额
        
        console.log("- Attempting to stake", Strings.toString(lowTokenAmount / 10**18), "TEST (below minimum)");
        console.log("- Expected: Transaction should be rejected");
        
        // 预期交易被拒绝
        vm.expectRevert("amount is less than minDepositAmount");
        vm.prank(user1);
        metaNodeStake.stakeERC20(erc20PoolId, lowTokenAmount);
        
        console.log("+ ERC20 low amount staking correctly rejected");
        
        console.log("\n=== Low Amount Staking Rejection Test Completed Successfully ===");
        console.log("+ System effectively prevents staking below minimum limits");
    }

    /**
     * @notice 测试用例4：暂停质押功能后不能质押
     * @dev 测试当管理员暂停质押功能后，用户是否无法进行任何质押操作
     */
    function test04_StakingWhenPausedRejected() public {
        console.log("=== Testing Staking When Function is Paused ===");
        
        // 🔒 步骤1：管理员暂停质押功能
        console.log("\n1. Admin Pausing Staking Function:");
        
        vm.prank(owner);
        metaNodeStake.setPausedStates(true, false, false, false); // 只暂停质押功能
        
        // 验证暂停状态
        bool isStakingPaused = metaNodeStake.stakingPaused();
        console.log("- Staking function status: PAUSED");
        assertTrue(isStakingPaused, "Staking should be paused");
        console.log("+ Staking function successfully paused by admin");
        
        // 🚫 步骤2：测试暂停状态下的ERC20质押
        console.log("\n2. Testing ERC20 Staking When Paused:");
        
        uint256 erc20PoolId = 1;
        uint256 stakeAmount = 500 * 10**18;
        
        console.log("- Attempting ERC20 staking while function is paused");
        console.log("- Expected: Transaction should be rejected");
        
        vm.expectRevert("staking is paused");
        vm.prank(user1);
        metaNodeStake.stakeERC20(erc20PoolId, stakeAmount);
        
        console.log("+ ERC20 staking correctly rejected when paused");
        
        // 🚫 步骤3：测试暂停状态下的ETH质押
        console.log("\n3. Testing ETH Staking When Paused:");
        
        uint256 ethPoolId = 0;
        uint256 ethStakeAmount = 0.1 ether;
        
        // 给user1分配ETH
        vm.deal(user1, 1 ether);
        
        console.log("- Attempting ETH staking while function is paused");
        console.log("- Expected: Transaction should be rejected");
        
        vm.expectRevert("staking is paused");
        vm.prank(user1);
        metaNodeStake.stakeETH{value: ethStakeAmount}(ethPoolId);
        
        console.log("+ ETH staking correctly rejected when paused");
        
        // 🔓 步骤4：恢复质押功能以便后续测试
        console.log("\n4. Restoring Staking Function:");
        
        vm.prank(owner);
        metaNodeStake.setPausedStates(false, false, false, false); // 恢复所有功能
        
        bool isStakingActive = !metaNodeStake.stakingPaused();
        console.log("- Staking function status: ACTIVE");
        assertTrue(isStakingActive, "Staking should be active");
        console.log("+ Staking function successfully restored");
        
        console.log("\n=== Paused Staking Rejection Test Completed Successfully ===");
        console.log("+ Admin control over staking function is effective");
    }

    /**
     * @notice 测试用例5：正常发起解除质押请求
     * @dev 测试用户正常发起解除质押请求的完整流程
     */
    function test05_NormalUnstakeRequest() public {
        console.log("=== Testing Normal Unstake Request Process ===");
        
        // 🔧 步骤1：前置设置 - 用户先进行质押
        console.log("\n1. Setup - User Stakes Tokens First:");
        
        uint256 poolId = 1; // ERC20池
        uint256 initialStakeAmount = 1000 * 10**18; // 质押1000 TEST
        uint256 unstakeAmount = 300 * 10**18; // 解除质押300 TEST
        
        // 执行初始质押
        vm.prank(user1);
        metaNodeStake.stakeERC20(poolId, initialStakeAmount);
        
        console.log("- Initial stake amount:", Strings.toString(initialStakeAmount / 10**18), "TEST");
        console.log("+ User1 has successfully staked tokens");
        
        // 🔍 步骤2：记录解除质押前的状态
        console.log("\n2. Recording Pre-unstake State:");
        
        (uint256 userStakeAmountBefore,,) = metaNodeStake.user(poolId, user1);
        (,,,,uint256 poolTotalAmountBefore,,) = metaNodeStake.pool(poolId);
        
        console.log("- User stake amount before:", Strings.toString(userStakeAmountBefore / 10**18), "TEST");
        console.log("- Pool total amount before:", Strings.toString(poolTotalAmountBefore / 10**18), "TEST");
        console.log("+ Pre-unstake state recorded");
        
        // 🚀 步骤3：执行解除质押操作
        console.log("\n3. Executing Unstake Request:");
        console.log("- Requesting to unstake", Strings.toString(unstakeAmount / 10**18), "TEST");
        
        // 预期触发RequestUnstake事件
        vm.expectEmit(true, true, true, true);
        emit RequestUnstake(user1, poolId, unstakeAmount);
        
        vm.prank(user1);
        metaNodeStake.unStake(poolId, unstakeAmount);
        
        console.log("+ Unstake request executed successfully");
        
        // ✅ 步骤4：验证解除质押后的状态
        console.log("\n4. Verifying Post-unstake State:");
        
        // 验证用户质押余额减少
        (uint256 userStakeAmountAfter,,) = metaNodeStake.user(poolId, user1);
        uint256 expectedUserStake = userStakeAmountBefore - unstakeAmount;
        console.log("- User stake amount after:", Strings.toString(userStakeAmountAfter / 10**18), "TEST");
        console.log("- Expected user stake amount:", Strings.toString(expectedUserStake / 10**18), "TEST");
        assertEq(userStakeAmountAfter, expectedUserStake, "User stake amount should decrease correctly");
        console.log("+ User stake balance decreased correctly");
        
        // 验证资金池总量减少
        (,,,,uint256 poolTotalAmountAfter,,) = metaNodeStake.pool(poolId);
        uint256 expectedPoolTotal = poolTotalAmountBefore - unstakeAmount;
        console.log("- Pool total amount after:", Strings.toString(poolTotalAmountAfter / 10**18), "TEST");
        console.log("- Expected pool total amount:", Strings.toString(expectedPoolTotal / 10**18), "TEST");
        assertEq(poolTotalAmountAfter, expectedPoolTotal, "Pool total amount should decrease correctly");
        console.log("+ Pool total amount decreased correctly");
        
        console.log("\n=== Normal Unstake Request Test Completed Successfully ===");
        console.log("+ Unstake request process works correctly");
    }

    /**
     * @notice 测试用例6：暂停解绑功能后不能解绑
     * @dev 验证当解绑功能被暂停时，用户无法进行解除质押操作
     */
    function test06_UnstakeWhenPausedRejected() public {
        console.log("=== Testing Unstake When Function is Paused ===");
        
        // 🔧 步骤1：前置设置 - 用户先进行质押
        console.log("\n1. Setup - User Stakes Tokens First:");
        
        uint256 poolId = 1; // ERC20池
        uint256 stakeAmount = 500 * 10**18; // 质押500 TEST
        uint256 unstakeAmount = 200 * 10**18; // 尝试解除200 TEST
        
        // 执行质押
        vm.prank(user1);
        metaNodeStake.stakeERC20(poolId, stakeAmount);
        
        console.log("- Staked amount:", Strings.toString(stakeAmount / 10**18), "TEST");
        console.log("+ User1 has tokens staked");
        
        // 🔒 步骤2：管理员暂停解绑功能
        console.log("\n2. Admin Pausing Unstaking Function:");
        
        vm.prank(owner);
        metaNodeStake.setPausedStates(false, true, false, false); // 只暂停解绑功能
        
        // 验证暂停状态
        bool isUnstakingPaused = metaNodeStake.unstakingPaused();
        console.log("- Unstaking function status: PAUSED");
        assertTrue(isUnstakingPaused, "Unstaking should be paused");
        console.log("+ Unstaking function successfully paused by admin");
        
        // 🚫 步骤3：测试暂停状态下的解除质押
        console.log("\n3. Testing Unstake When Function is Paused:");
        
        console.log("- Attempting to unstake", Strings.toString(unstakeAmount / 10**18), "TEST while function is paused");
        console.log("- Expected: Transaction should be rejected");
        
        vm.expectRevert("unstaking is paused");
        vm.prank(user1);
        metaNodeStake.unStake(poolId, unstakeAmount);
        
        console.log("+ Unstake request correctly rejected when paused");
        
        // 🔓 步骤4：恢复解绑功能
        console.log("\n4. Restoring Unstaking Function:");
        
        vm.prank(owner);
        metaNodeStake.setPausedStates(false, false, false, false); // 恢复所有功能
        
        bool isUnstakingActive = !metaNodeStake.unstakingPaused();
        console.log("- Unstaking function status: ACTIVE");
        assertTrue(isUnstakingActive, "Unstaking should be active");
        console.log("+ Unstaking function successfully restored");
        
        console.log("\n=== Paused Unstaking Rejection Test Completed Successfully ===");
        console.log("+ Admin control over unstaking function is effective");
    }

    /**
     * @notice 测试用例7：超额解除质押被拒绝
     * @dev 测试用户尝试解除超过实际质押数量的代币时会被系统拒绝
     */
    function test07_ExcessiveUnstakeRejected() public {
        console.log("=== Testing Excessive Unstake Amount Rejection ===");
        
        // 🔧 步骤1：前置设置 - 用户质押一定数量的代币
        console.log("\n1. Setup - User Stakes Limited Amount:");
        
        uint256 poolId = 1; // ERC20池
        uint256 actualStakeAmount = 300 * 10**18; // 实际质押300 TEST
        uint256 excessiveUnstakeAmount = 500 * 10**18; // 尝试解除500 TEST（超额）
        
        // 执行质押
        vm.prank(user1);
        metaNodeStake.stakeERC20(poolId, actualStakeAmount);
        
        console.log("- Actual staked amount:", Strings.toString(actualStakeAmount / 10**18), "TEST");
        console.log("+ User1 has staked limited tokens");
        
        // 🔍 步骤2：记录当前质押状态
        console.log("\n2. Recording Current Stake State:");
        
        (uint256 userStakeAmountBefore,,) = metaNodeStake.user(poolId, user1);
        console.log("- User current stake amount:", Strings.toString(userStakeAmountBefore / 10**18), "TEST");
        console.log("- Attempting to unstake:", Strings.toString(excessiveUnstakeAmount / 10**18), "TEST");
        console.log("- Excessive amount:", Strings.toString((excessiveUnstakeAmount - userStakeAmountBefore) / 10**18), "TEST");
        
        // 🚫 步骤3：测试超额解除质押
        console.log("\n3. Testing Excessive Unstake Request:");
        
        console.log("- Expected: Transaction should be rejected with insufficient balance error");
        
        vm.expectRevert("insufficient staked amount");
        vm.prank(user1);
        metaNodeStake.unStake(poolId, excessiveUnstakeAmount);
        
        console.log("+ Excessive unstake request correctly rejected");
        
        // ✅ 步骤4：验证质押状态保持不变
        console.log("\n4. Verifying Stake State Unchanged:");
        
        (uint256 userStakeAmountAfter,,) = metaNodeStake.user(poolId, user1);
        console.log("- User stake amount after failed attempt:", Strings.toString(userStakeAmountAfter / 10**18), "TEST");
        
        assertEq(userStakeAmountAfter, userStakeAmountBefore, "User stake amount should remain unchanged");
        console.log("+ User stake state remains unchanged after failed excessive unstake");
        
        // 🔍 步骤5：验证正常数量的解除质押仍然有效
        console.log("\n5. Verifying Normal Unstake Still Works:");
        
        uint256 normalUnstakeAmount = 100 * 10**18; // 正常解除100 TEST
        console.log("- Attempting normal unstake of", Strings.toString(normalUnstakeAmount / 10**18), "TEST");
        
        vm.prank(user1);
        metaNodeStake.unStake(poolId, normalUnstakeAmount);
        
        (uint256 finalStakeAmount,,) = metaNodeStake.user(poolId, user1);
        uint256 expectedFinalAmount = userStakeAmountBefore - normalUnstakeAmount;
        console.log("- Final stake amount:", Strings.toString(finalStakeAmount / 10**18), "TEST");
        assertEq(finalStakeAmount, expectedFinalAmount, "Normal unstake should work correctly");
        console.log("+ Normal unstake still works after excessive attempt");
        
        console.log("\n=== Excessive Unstake Rejection Test Completed Successfully ===");
        console.log("+ System effectively prevents excessive unstake operations");
    }

}
