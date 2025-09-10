// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/MetaNode.sol";
import "src/MetaNodeStake.sol";
import "src/MockERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title PoolManagementTest
 * @notice 质押池管理功能测试套件
 * @dev 测试质押池的创建、管理和配置功能
 */
contract PoolManagementTest is Test {
    // 核心合约实例
    MetaNode public metaNode;
    MetaNodeStake public metaNodeStake;
    MockERC20 public mockToken;
    
    // 测试账户
    address public owner;    // 管理员账户
    address public user1;    // 普通用户1
    address public user2;    // 普通用户2
    
    // 测试参数常量
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18; // 1亿代币
    uint256 public constant META_NODE_PER_BLOCK = 100 * 10**18;    // 每个区块100个代币奖励
    uint256 public constant MOCK_TOKEN_SUPPLY = 1_000_000 * 10**18; // 100万测试代币

    /**
     * @notice 测试环境初始化设置
     * @dev 部署所有必要的合约并进行初始配置
     */
    function setUp() public {
        console.log("=== Pool Management Test Environment Initialization ===");
        
        // 1. 账户准备 👥
        console.log("\n1. Account Preparation:");
        owner = address(0x1);
        user1 = address(0x2);
        user2 = address(0x3);
        
        console.log("- Owner (Admin):", owner);
        console.log("- User1:", user1);
        console.log("- User2:", user2);
        
        // 2. 核心合约部署 📄
        console.log("\n2. Core Contract Deployment:");
        _deployMetaNodeContract();
        _deployMetaNodeStakeContract();
        
        // 3. 获取代币合约 🪙
        console.log("\n3. Token Contract Instance:");
        console.log("- MetaNode token contract address:", address(metaNode));
        console.log("- MetaNode token name:", metaNode.name());
        console.log("- MetaNode token symbol:", metaNode.symbol());
        
        // 4. 获取质押合约 🏦
        console.log("\n4. Staking Contract Instance:");
        console.log("- MetaNodeStake contract address:", address(metaNodeStake));
        console.log("- Reward token address:", address(metaNodeStake.MetaNode()));
        console.log("- Reward per block:", metaNodeStake.MetaNodePerBlock());
        
        // 5. 部署测试代币 🧪
        console.log("\n5. Test Token Deployment:");
        _deployMockToken();
        
        // 6. 权限验证 🔍
        console.log("\n6. Permission Verification:");
        _verifyPermissions();
        
        console.log("\n=== Pool Management Test Environment Ready ===");
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
     * @dev 部署用于测试的 MockERC20 代币
     */
    function _deployMockToken() private {
        console.log("Deploying MockERC20 test token...");
        
        vm.prank(owner);
        mockToken = new MockERC20(
            "Test Token",      // 代币名称
            "TEST",           // 代币符号
            MOCK_TOKEN_SUPPLY // 初始供应量
        );
        
        console.log("- MockERC20 contract address:", address(mockToken));
        console.log("- MockERC20 name:", mockToken.name());
        console.log("- MockERC20 symbol:", mockToken.symbol());
        console.log("- MockERC20 initial supply:", mockToken.totalSupply());
        console.log("- Owner balance:", mockToken.balanceOf(owner));
        
        // 验证部署结果
        assertTrue(address(mockToken) != address(0), "MockERC20 contract address invalid");
        assertTrue(mockToken.totalSupply() == MOCK_TOKEN_SUPPLY, "MockERC20 total supply incorrect");
        assertTrue(mockToken.balanceOf(owner) == MOCK_TOKEN_SUPPLY, "Owner MockERC20 balance incorrect");
        assertEq(mockToken.owner(), owner, "MockERC20 owner incorrect");
        console.log("+ MockERC20 contract deployment verified");
    }
    
    /**
     * @dev 验证管理员权限设置
     */
    function _verifyPermissions() private {
        console.log("Verifying admin permissions...");
        
        // 检查 ADMIN_ROLE 权限
        bytes32 adminRole = metaNodeStake.ADMIN_ROLE();
        bool hasAdminRole = metaNodeStake.hasRole(adminRole, owner);
        console.log("- Owner has ADMIN_ROLE:", hasAdminRole);
        assertTrue(hasAdminRole, "Owner should have ADMIN_ROLE");
        
        // 检查 DEFAULT_ADMIN_ROLE 权限
        bytes32 defaultAdminRole = metaNodeStake.DEFAULT_ADMIN_ROLE();
        bool hasDefaultAdminRole = metaNodeStake.hasRole(defaultAdminRole, owner);
        console.log("- Owner has DEFAULT_ADMIN_ROLE:", hasDefaultAdminRole);
        assertTrue(hasDefaultAdminRole, "Owner should have DEFAULT_ADMIN_ROLE");
        
        // 检查 UPGRADE_ROLE 权限
        bytes32 upgradeRole = metaNodeStake.UPGRADE_ROLE();
        bool hasUpgradeRole = metaNodeStake.hasRole(upgradeRole, owner);
        console.log("- Owner has UPGRADE_ROLE:", hasUpgradeRole);
        assertTrue(hasUpgradeRole, "Owner should have UPGRADE_ROLE");
        
        // 验证普通用户没有管理员权限
        bool user1HasAdminRole = metaNodeStake.hasRole(adminRole, user1);
        assertTrue(!user1HasAdminRole, "User1 should not have ADMIN_ROLE");
        
        console.log("+ Admin permission verification completed");
    }
    
    /**
     * @notice 测试添加ETH质押池
     * @dev 验证添加第一个ETH池子的完整流程
     */
    function test02_AddETHPool() public {
        console.log("=== Testing Add ETH Pool ===");
        
        // 🎯 前置条件检查 (Arrange)
        console.log("\n1. Precondition Check:");
        uint256 initialPoolLength = metaNodeStake.getPoolLength();
        uint256 initialTotalWeight = metaNodeStake.totalPoolWeight();
        
        console.log("- Initial pool length:", initialPoolLength);
        console.log("- Initial total pool weight:", initialTotalWeight);
        
        // 验证初始状态为空
        assertEq(initialPoolLength, 0, "Pool list should be empty initially");
        assertEq(initialTotalWeight, 0, "Total pool weight should be 0 initially");
        console.log("+ Pool list is empty, pool count = 0, totalPoolWeight = 0");
        
        // 🚀 执行测试操作 (Act)
        console.log("\n2. Execute Add Pool Operation:");
        
        // 定义ETH池参数
        address ethPoolAddress = address(0);        // ETH池使用零地址
        uint256 poolWeight = 100;                   // 权重设为100
        uint256 minDepositAmount = 0.01 ether;      // 最低质押0.01 ETH
        uint256 unstakeLockedBlocks = 100;          // 解锁需要100个区块
        
        console.log("- Pool parameters:");
        console.log("  - Token address (ETH):", ethPoolAddress);
        console.log("  - Pool weight:", poolWeight);
        console.log("  - Min deposit amount:", minDepositAmount);
        console.log("  - Unstake locked blocks:", unstakeLockedBlocks);
        
        // 以管理员身份添加ETH池
        vm.prank(owner);
        metaNodeStake.addPool(
            ethPoolAddress,
            poolWeight,
            minDepositAmount,
            unstakeLockedBlocks
        );
        
        console.log("+ ETH pool addition transaction completed");
        
        // 🔍 验证结果 (Assert)
        console.log("\n3. Verify Pool Parameters:");
        
        // 获取添加的池子信息（索引为0）
        (
            address stTokenAddress,
            uint256 poolWeight_,
            uint256 lastRewardBlock,
            uint256 accMetaNodePerST,
            uint256 stTokenAmount,
            uint256 minDepositAmount_,
            uint256 unstakeLockedBlocks_
        ) = metaNodeStake.pool(0);
        
        console.log("- Retrieved pool info:");
        console.log("  - Token address:", stTokenAddress);
        console.log("  - Pool weight:", poolWeight_);
        console.log("  - Last reward block:", lastRewardBlock);
        console.log("  - Accumulated MetaNode per ST:", accMetaNodePerST);
        console.log("  - ST token amount:", stTokenAmount);
        console.log("  - Min deposit amount:", minDepositAmount_);
        console.log("  - Unstake locked blocks:", unstakeLockedBlocks_);
        
        // 验证池子参数
        assertEq(stTokenAddress, ethPoolAddress, "Pool token address should be zero (ETH)");
        assertEq(poolWeight_, poolWeight, "Pool weight should match");
        assertEq(minDepositAmount_, minDepositAmount, "Min deposit amount should match");
        assertEq(unstakeLockedBlocks_, unstakeLockedBlocks, "Unstake locked blocks should match");
        
        // 验证初始值
        assertEq(accMetaNodePerST, 0, "Initial accumulated MetaNode per ST should be 0");
        assertEq(stTokenAmount, 0, "Initial staking token amount should be 0");
        assertTrue(lastRewardBlock > 0, "Last reward block should be set to current block");
        
        console.log("+ ETH pool parameters verification passed");
        
        // 🌐 验证全局状态更新
        console.log("\n4. Verify Global State Update:");
        
        uint256 finalPoolLength = metaNodeStake.getPoolLength();
        uint256 finalTotalWeight = metaNodeStake.totalPoolWeight();
        
        console.log("- Final pool length:", finalPoolLength);
        console.log("- Final total pool weight:", finalTotalWeight);
        
        // 验证全局状态
        assertEq(finalPoolLength, 1, "Pool length should be 1 after adding ETH pool");
        assertEq(finalTotalWeight, poolWeight, "Total weight should equal ETH pool weight");
        
        console.log("+ Total weight update correct:", finalTotalWeight);
        console.log("\n=== ETH Pool Addition Test Completed Successfully ===");
    }
    
    /**
     * @notice 测试非ETH代币作为第一个池子被拒绝
     * @dev 验证合约只允许ETH池作为第一个质押池的安全机制
     */
    function test03_RejectNonETHAsFirstPool() public {
        console.log("=== Testing Rejection of Non-ETH Token as First Pool ===");
        
        // 🎯 前置条件检查 (Arrange)
        console.log("\n1. Precondition Check:");
        uint256 initialPoolLength = metaNodeStake.getPoolLength();
        uint256 initialTotalWeight = metaNodeStake.totalPoolWeight();
        
        console.log("- Initial pool length:", initialPoolLength);
        console.log("- Initial total pool weight:", initialTotalWeight);
        
        // 验证初始状态为空
        assertEq(initialPoolLength, 0, "Pool list should be empty initially");
        assertEq(initialTotalWeight, 0, "Total pool weight should be 0 initially");
        console.log("+ Pool list is empty, pool count = 0, totalPoolWeight = 0");
        
        // 🚫 执行应被拒绝的操作 (Act & Assert)
        console.log("\n2. Execute Rejected Operation:");
        
        // 尝试使用ERC20代币作为第一个池子（应该被拒绝）
        address nonETHTokenAddress = address(mockToken);  // 使用MockERC20代币地址
        uint256 poolWeight = 100;
        uint256 minDepositAmount = 1000 * 10**18;  // 1000个代币
        uint256 unstakeLockedBlocks = 100;
        
        console.log("- Attempting to add non-ETH token as first pool:");
        console.log("  - Token address (ERC20):", nonETHTokenAddress);
        console.log("  - Pool weight:", poolWeight);
        console.log("  - Min deposit amount:", minDepositAmount);
        console.log("  - Unstake locked blocks:", unstakeLockedBlocks);
        
        // 验证添加非ETH池作为第一个池子会被拒绝
        vm.prank(owner);
        vm.expectRevert("first pool must be ETH pool");
        metaNodeStake.addPool(
            nonETHTokenAddress,
            poolWeight,
            minDepositAmount,
            unstakeLockedBlocks
        );
        
        console.log("+ Non-ETH pool as first pool correctly rejected");
        
        // 🔍 验证状态未改变 (Assert)
        console.log("\n3. Verify State Unchanged:");
        
        uint256 finalPoolLength = metaNodeStake.getPoolLength();
        uint256 finalTotalWeight = metaNodeStake.totalPoolWeight();
        
        console.log("- Final pool length:", finalPoolLength);
        console.log("- Final total pool weight:", finalTotalWeight);
        
        // 验证状态没有发生变化
        assertEq(finalPoolLength, initialPoolLength, "Pool length should remain unchanged after rejection");
        assertEq(finalTotalWeight, initialTotalWeight, "Total weight should remain unchanged after rejection");
        assertEq(finalPoolLength, 0, "Pool list should still be empty");
        assertEq(finalTotalWeight, 0, "Total weight should still be 0");
        
        console.log("+ Pool list remains empty, pool count = 0");
        console.log("+ Contract state completely unchanged after failed operation");
        console.log("\n=== Non-ETH First Pool Rejection Test Completed Successfully ===");
    }
    
    /**
     * @notice 测试重复添加同一个ERC20代币池被拒绝
     * @dev 验证合约防止重复添加相同代币池的安全机制
     */
    function test04_RejectDuplicateERC20Pool() public {
        console.log("=== Testing Rejection of Duplicate ERC20 Pool ===");
        
        // 🎯 前置条件设置 (Arrange)
        console.log("\n1. Setup Prerequisites:");
        
        // 步骤1：添加ETH池（必须是第一个池子）
        console.log("- Step 1: Adding ETH pool (required first pool)...");
        vm.prank(owner);
        metaNodeStake.addPool(
            address(0),      // ETH池使用零地址
            100,             // 权重100
            0.01 ether,      // 最低质押0.01 ETH
            100              // 解锁100个区块
        );
        console.log("+ ETH pool added successfully");
        
        // 步骤2：添加第一个ERC20池
        console.log("- Step 2: Adding first ERC20 pool...");
        address firstERC20Address = address(mockToken);
        uint256 firstERC20Weight = 50;
        uint256 firstERC20MinDeposit = 1000 * 10**18;  // 1000个代币
        uint256 firstERC20UnstakeBlocks = 200;
        
        vm.prank(owner);
        metaNodeStake.addPool(
            firstERC20Address,
            firstERC20Weight,
            firstERC20MinDeposit,
            firstERC20UnstakeBlocks
        );
        console.log("+ First ERC20 pool added successfully");
        
        // 验证前置条件
        uint256 setupPoolLength = metaNodeStake.getPoolLength();
        uint256 setupTotalWeight = metaNodeStake.totalPoolWeight();
        
        console.log("- Current pool count:", setupPoolLength);
        console.log("- Current total weight:", setupTotalWeight);
        
        assertEq(setupPoolLength, 2, "Should have 2 pools after setup");
        assertEq(setupTotalWeight, 150, "Total weight should be 150 (100 + 50)");
        console.log("+ Pool count: 2, Total weight: 150");
        
        // 🚫 执行应被拒绝的操作 (Act & Assert)
        console.log("\n2. Execute Rejected Operation:");
        
        // 尝试添加重复的ERC20池（使用相同的代币地址）
        console.log("- Attempting to add duplicate ERC20 pool:");
        console.log("  - Token address (same as existing):", firstERC20Address);
        console.log("  - Pool weight:", 75);  // 使用不同的权重，但代币地址相同
        console.log("  - Min deposit amount:", 500 * 10**18);
        console.log("  - Unstake locked blocks:", 150);
        
        // 验证添加重复ERC20池会被拒绝
        vm.prank(owner);
        vm.expectRevert("pool already exists for this token");
        metaNodeStake.addPool(
            firstERC20Address,  // 使用相同的代币地址
            75,                 // 不同的权重
            500 * 10**18,       // 不同的最低质押量
            150                 // 不同的解锁区块数
        );
        
        console.log("+ Duplicate ERC20 pool correctly rejected");
        
        // 🔍 验证状态未改变 (Assert)
        console.log("\n3. Verify State Unchanged:");
        
        uint256 finalPoolLength = metaNodeStake.getPoolLength();
        uint256 finalTotalWeight = metaNodeStake.totalPoolWeight();
        
        console.log("- Final pool count:", finalPoolLength);
        console.log("- Final total weight:", finalTotalWeight);
        
        // 验证状态没有发生变化
        assertEq(finalPoolLength, setupPoolLength, "Pool count should remain unchanged after rejection");
        assertEq(finalTotalWeight, setupTotalWeight, "Total weight should remain unchanged after rejection");
        assertEq(finalPoolLength, 2, "Should still have exactly 2 pools");
        assertEq(finalTotalWeight, 150, "Total weight should still be 150");
        
        console.log("+ Total weight remains unchanged: 150");
        console.log("+ Contract state preserved after failed duplicate operation");
        console.log("\n=== Duplicate ERC20 Pool Rejection Test Completed Successfully ===");
    }
    
    /**
     * @notice 测试无效参数被拒绝
     * @dev 验证合约对各种无效参数的防护机制
     */
    function test05_RejectInvalidParameters() public {
        console.log("=== Testing Rejection of Invalid Parameters ===");
        
        // 🎯 前置条件设置 (Arrange)
        console.log("\n1. Setup Prerequisites:");
        
        // 步骤1：添加ETH池（必须是第一个池子）
        console.log("- Step 1: Adding ETH pool (required first pool)...");
        vm.prank(owner);
        metaNodeStake.addPool(
            address(0),      // ETH池使用零地址
            100,             // 权重100
            0.01 ether,      // 最低质押0.01 ETH
            100              // 解锁100个区块
        );
        console.log("+ ETH pool added successfully");
        
        // 步骤2：部署第二个测试代币（确保测试隔离性）
        console.log("- Step 2: Deploying second test token for isolation...");
        MockERC20 mockToken2 = new MockERC20("Test Token 2", "TEST2", 1000000 * 10**18);
        address secondTokenAddress = address(mockToken2);
        console.log("+ Second test token deployed:", secondTokenAddress);
        
        // 验证初始状态
        uint256 initialPoolLength = metaNodeStake.getPoolLength();
        uint256 initialTotalWeight = metaNodeStake.totalPoolWeight();
        
        console.log("- Initial pool count:", initialPoolLength);
        console.log("- Initial total weight:", initialTotalWeight);
        
        assertEq(initialPoolLength, 1, "Should have 1 pool after ETH pool setup");
        assertEq(initialTotalWeight, 100, "Total weight should be 100 (ETH pool only)");
        console.log("+ ETH pool setup verified");
        
        // 🚫 执行多个应被拒绝的操作并断言 (Act & Assert)
        console.log("\n2. Execute Multiple Invalid Parameter Tests:");
        
        // 测试1：池权重为0
        console.log("- Test 1: Pool weight = 0");
        console.log("  - Token address:", secondTokenAddress);
        console.log("  - Pool weight: 0 (invalid)");
        console.log("  - Min deposit amount:", 1000 * 10**18);
        console.log("  - Unstake locked blocks:", 200);
        
        vm.prank(owner);
        vm.expectRevert("invalid pool weight");
        metaNodeStake.addPool(
            secondTokenAddress,
            0,                  // 无效：权重为0
            1000 * 10**18,
            200
        );
        console.log("+ Pool weight = 0 correctly rejected");
        
        // 测试2：解锁周期为0
        console.log("- Test 2: Unstake locked blocks = 0");
        console.log("  - Token address:", secondTokenAddress);
        console.log("  - Pool weight:", 50);
        console.log("  - Min deposit amount:", 1000 * 10**18);
        console.log("  - Unstake locked blocks: 0 (invalid)");
        
        vm.prank(owner);
        vm.expectRevert("invalid unstake locked blocks");
        metaNodeStake.addPool(
            secondTokenAddress,
            50,
            1000 * 10**18,
            0                   // 无效：解锁周期为0
        );
        console.log("+ Unstake locked blocks = 0 correctly rejected");
        
        // 测试3：尝试再次添加ETH池（零地址检查）
        console.log("- Test 3: Attempting to add second ETH pool");
        console.log("  - Token address: 0x0000000000000000000000000000000000000000 (zero address)");
        console.log("  - Pool weight:", 75);
        console.log("  - Min deposit amount:", 0.02 ether);
        console.log("  - Unstake locked blocks:", 150);
        
        vm.prank(owner);
        vm.expectRevert("ERC20 pool token address cannot be zero");
        metaNodeStake.addPool(
            address(0),         // 无效：尝试再次使用零地址
            75,
            0.02 ether,
            150
        );
        console.log("+ Second ETH pool correctly rejected (zero address protection)");
        
        // 🔍 验证状态未改变 (Assert)
        console.log("\n3. Verify State Unchanged After All Rejections:");
        
        uint256 finalPoolLength = metaNodeStake.getPoolLength();
        uint256 finalTotalWeight = metaNodeStake.totalPoolWeight();
        
        console.log("- Final pool count:", finalPoolLength);
        console.log("- Final total weight:", finalTotalWeight);
        
        // 验证状态没有发生变化
        assertEq(finalPoolLength, initialPoolLength, "Pool count should remain unchanged after all rejections");
        assertEq(finalTotalWeight, initialTotalWeight, "Total weight should remain unchanged after all rejections");
        assertEq(finalPoolLength, 1, "Should still have exactly 1 pool (ETH only)");
        assertEq(finalTotalWeight, 100, "Total weight should still be 100 (ETH pool only)");
        
        console.log("+ Total weight remains unchanged: 100");
        console.log("+ Contract state preserved after all invalid parameter rejections");
        console.log("+ All three invalid parameter scenarios successfully blocked");
        console.log("\n=== Invalid Parameters Rejection Test Completed Successfully ===");
    }

}
