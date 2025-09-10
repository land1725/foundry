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
 * @title WithdrawalPauseTest
 * @notice 提现和暂停功能测试套件
 * @dev 测试提现操作、锁定期管理和系统暂停功能
 */
contract WithdrawalPauseTest is Test {
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
    
    // 质押池参数 - 专门为提现测试优化
    uint256 public constant ETH_POOL_WEIGHT = 100;
    uint256 public constant ETH_MIN_DEPOSIT = 0.01 ether;
    uint256 public constant ETH_UNSTAKE_BLOCKS = 5;  // 较短的解锁周期便于测试
    
    uint256 public constant ERC20_POOL_WEIGHT = 50;
    uint256 public constant ERC20_MIN_DEPOSIT = 100 * 10**18;  // 100个TEST代币
    uint256 public constant ERC20_UNSTAKE_BLOCKS = 3;  // 较短的解锁周期便于测试
    
    // 用户资金分配
    uint256 public constant USER1_TOKEN_AMOUNT = 10_000 * 10**18;  // 1万个TEST代币
    uint256 public constant USER2_TOKEN_AMOUNT = 5_000 * 10**18;   // 5千个TEST代币
    uint256 public constant APPROVAL_AMOUNT = 50_000 * 10**18;     // 5万个TEST代币授权额度
    
    // 初始质押和解除质押金额
    uint256 public constant USER1_INITIAL_STAKE = 2_000 * 10**18;  // User1初始质押2000 TEST
    uint256 public constant USER1_UNSTAKE_1 = 500 * 10**18;       // User1第一次解除质押500 TEST
    uint256 public constant USER1_UNSTAKE_2 = 300 * 10**18;       // User1第二次解除质押300 TEST
    uint256 public constant USER2_ETH_STAKE = 0.5 ether;          // User2质押0.5 ETH
    uint256 public constant USER2_ETH_UNSTAKE = 0.2 ether;        // User2解除质押0.2 ETH

    // ！！！事件定义部分！！！
    // 这里定义我们要验证的事件，必须与合约中的事件定义完全一致
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event RequestUnstake(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed poolId, uint256 amount, uint256 indexed blockNumber);

    /**
     * @notice 测试环境初始化设置
     * @dev 部署所有必要的合约、创建质押池、分配资金、创建初始质押和解除质押请求
     */
    function setUp() public {
        console.log("=== Withdrawal and Pause Test Environment Initialization ===");
        console.log("Starting simulation environment for withdrawal and pause functionality testing...");
        
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
        _deployMetaNodeContract();
        _deployMetaNodeStakeContract();
        console.log("+ All core contracts deployed successfully");
        
        // 🔍 步骤3：获取已部署的MetaNode代币合约实例
        console.log("\n3. MetaNode Token Contract Instance:");
        console.log("- MetaNode token contract address:", address(metaNode));
        console.log("- MetaNode token name:", metaNode.name());
        console.log("- MetaNode token symbol:", metaNode.symbol());
        console.log("- MetaNode total supply:", Strings.toString(metaNode.totalSupply() / 10**18), "MN");
        console.log("+ MetaNode contract instance confirmed");
        
        // 🏦 步骤4：获取MetaNodeStake质押合约实例
        console.log("\n4. MetaNodeStake Contract Instance:");
        console.log("- MetaNodeStake contract address:", address(metaNodeStake));
        console.log("- Reward token address:", address(metaNodeStake.MetaNode()));
        console.log("- Reward per block:", Strings.toString(metaNodeStake.MetaNodePerBlock() / 10**18), "MN/block");
        console.log("+ MetaNodeStake contract instance confirmed");
        
        // 🪙 步骤5：部署测试用MockERC20代币合约
        console.log("\n5. Test Token (MockERC20) Deployment:");
        _deployTestToken();
        
        // 🏊‍♂️ 步骤6：创建两个质押池
        console.log("\n6. Staking Pool Creation:");
        _createStakingPools();
        
        // 💰 步骤7：为用户准备测试资产
        console.log("\n7. User Asset Preparation:");
        _prepareFundsAndAuthorizations();
        
        // 🔄 步骤8：创建初始质押和解除质押请求
        console.log("\n8. Initial Staking and Unstaking Setup:");
        _createInitialStakingAndUnstaking();
        
        // ⚙️ 步骤9：验证所有功能暂停状态
        console.log("\n9. System Function Status Verification:");
        _verifySystemStatus();
        
        // ✅ 步骤10：打印当前环境状态信息
        console.log("\n10. Environment Status Summary:");
        _displayEnvironmentSummary();
        
        console.log("\n=== Withdrawal and Pause Test Environment Ready ===");
    }

    /**
     * @dev 部署 MetaNode 代币合约（使用 UUPS 代理模式）
     */
    function _deployMetaNodeContract() private {
        console.log("Deploying MetaNode token contract...");
        
        // 部署逻辑合约
        MetaNode metaNodeLogic = new MetaNode();
        console.log("- MetaNode logic contract deployed at:", address(metaNodeLogic));
        
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
        console.log("- MetaNode proxy contract deployed at:", address(metaNode));
        
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
        console.log("- MetaNodeStake logic contract deployed at:", address(metaNodeStakeLogic));
        
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
        console.log("- MetaNodeStake proxy contract deployed at:", address(metaNodeStake));
        
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
        console.log("Deploying MockERC20 'Test Token' with 1,000,000 supply...");
        
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
        console.log("+ MockERC20 'Test Token' (TEST) deployed with 1,000,000 tokens");
    }

    /**
     * @notice 创建质押池
     * @dev 创建ETH池和ERC20代币池，使用较短的解锁周期便于测试
     */
    function _createStakingPools() private {
        console.log("Creating staking pools with short unlock periods for testing...");
        
        // 创建ETH池（编号0）- 解锁周期5个区块
        console.log("- Creating ETH Pool (Pool #0):");
        console.log("  - Pool Type: Native ETH");
        console.log("  - Pool Weight:", ETH_POOL_WEIGHT);
        console.log("  - Minimum Deposit:", Strings.toString(ETH_MIN_DEPOSIT / 10**18), "ETH");
        console.log("  - Unlock Period:", Strings.toString(ETH_UNSTAKE_BLOCKS), "blocks");
        
        vm.prank(owner);
        metaNodeStake.addPool(
            address(0),           // ETH池使用零地址
            ETH_POOL_WEIGHT,      // 权重100
            ETH_MIN_DEPOSIT,      // 最少质押0.01 ETH
            ETH_UNSTAKE_BLOCKS    // 解锁等待期5个区块
        );
        console.log("+ ETH Pool created with 5-block unlock period");
        
        // 创建ERC20代币池（编号1）- 解锁周期3个区块
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
            ERC20_MIN_DEPOSIT,     // 最少质押100个TEST代币
            ERC20_UNSTAKE_BLOCKS   // 解锁等待期3个区块
        );
        console.log("+ ERC20 Token Pool created with 3-block unlock period");
        
        console.log("+ Two staking pools created: ETH Pool (5 blocks) + ERC20 Token Pool (3 blocks)");
    }

    /**
     * @notice 为用户准备测试资产
     * @dev 分配TEST代币给用户、分配ETH并授权质押合约
     */
    function _prepareFundsAndAuthorizations() private {
        console.log("Preparing user assets...");
        
        // 向User1分配10,000 TEST代币
        console.log("- Allocating 10,000 TEST tokens to User1:");
        vm.prank(owner);
        testToken.transfer(user1, USER1_TOKEN_AMOUNT);
        console.log("  - Amount transferred:", Strings.toString(USER1_TOKEN_AMOUNT / 10**18), "TEST tokens");
        console.log("  - User1 TEST balance:", Strings.toString(testToken.balanceOf(user1) / 10**18), "TEST");
        
        // 向User2分配5,000 TEST代币
        console.log("- Allocating 5,000 TEST tokens to User2:");
        vm.prank(owner);
        testToken.transfer(user2, USER2_TOKEN_AMOUNT);
        console.log("  - Amount transferred:", Strings.toString(USER2_TOKEN_AMOUNT / 10**18), "TEST tokens");
        console.log("  - User2 TEST balance:", Strings.toString(testToken.balanceOf(user2) / 10**18), "TEST");
        
        // 给用户分配ETH余额
        vm.deal(user1, 2 ether);
        vm.deal(user2, 2 ether);
        console.log("- Allocated 2 ETH to each user for testing");
        
        // 用户1授权质押合约
        console.log("- Setting up User1 ERC20 authorization:");
        vm.prank(user1);
        testToken.approve(address(metaNodeStake), APPROVAL_AMOUNT);
        console.log("  - Authorized amount:", Strings.toString(APPROVAL_AMOUNT / 10**18), "TEST tokens");
        
        // 用户2授权质押合约
        console.log("- Setting up User2 ERC20 authorization:");
        vm.prank(user2);
        testToken.approve(address(metaNodeStake), APPROVAL_AMOUNT);
        console.log("  - Authorized amount:", Strings.toString(APPROVAL_AMOUNT / 10**18), "TEST tokens");
        
        console.log("+ User asset preparation completed");
        console.log("+ Both users ready for staking and withdrawal operations");
    }

    /**
     * @notice 创建初始质押和解除质押请求
     * @dev User1在ERC20池进行质押和解除质押，User2在ETH池进行质押和解除质押
     */
    function _createInitialStakingAndUnstaking() private {
        console.log("Creating initial staking and unstaking requests...");
        
        // User1在ERC20池质押2,000 TEST
        console.log("- User1 stakes 2,000 TEST in ERC20 pool:");
        vm.prank(user1);
        metaNodeStake.stakeERC20(1, USER1_INITIAL_STAKE);
        console.log("  - Staked amount:", Strings.toString(USER1_INITIAL_STAKE / 10**18), "TEST");
        
        // User1第一次解除质押500 TEST
        console.log("- User1 requests unstake #1: 500 TEST:");
        vm.prank(user1);
        metaNodeStake.unStake(1, USER1_UNSTAKE_1);
        console.log("  - Unstake request amount:", Strings.toString(USER1_UNSTAKE_1 / 10**18), "TEST");
        
        // User1第二次解除质押300 TEST
        console.log("- User1 requests unstake #2: 300 TEST:");
        vm.prank(user1);
        metaNodeStake.unStake(1, USER1_UNSTAKE_2);
        console.log("  - Unstake request amount:", Strings.toString(USER1_UNSTAKE_2 / 10**18), "TEST");
        
        // User2在ETH池质押0.5 ETH
        console.log("- User2 stakes 0.5 ETH in ETH pool:");
        vm.prank(user2);
        metaNodeStake.stakeETH{value: USER2_ETH_STAKE}(0);
        console.log("  - Staked amount:", Strings.toString(USER2_ETH_STAKE / 10**18), "ETH");
        
        // User2解除质押0.2 ETH
        console.log("- User2 requests unstake: 0.2 ETH:");
        vm.prank(user2);
        metaNodeStake.unStake(0, USER2_ETH_UNSTAKE);
        console.log("  - Unstake request amount:", Strings.toString(USER2_ETH_UNSTAKE / 10**18), "ETH");
        
        console.log("+ Initial staking and unstaking setup completed");
        console.log("+ Users have pending unstake requests waiting for unlock period");
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
        console.log("+ System ready for withdrawal and pause testing");
    }

    /**
     * @notice 打印当前环境状态信息
     * @dev 展示当前环境的整体状态，包括池子、区块、用户状态等
     */
    function _displayEnvironmentSummary() private view {
        console.log("Environment status information:");
        
        // 池子数量
        uint256 poolCount = metaNodeStake.getPoolLength();
        console.log("- Total staking pools created:", poolCount);
        
        // 当前区块高度
        uint256 currentBlock = block.number;
        console.log("- Current block height:", currentBlock);
        
        // 各池解锁周期设置
        console.log("- ETH Pool unlock period:", Strings.toString(ETH_UNSTAKE_BLOCKS), "blocks");
        console.log("- ERC20 Pool unlock period:", Strings.toString(ERC20_UNSTAKE_BLOCKS), "blocks");
        
        // 用户剩余质押量
        (uint256 user1StakeAmount,,) = metaNodeStake.user(1, user1);
        (uint256 user2StakeAmount,,) = metaNodeStake.user(0, user2);
        
        console.log("- User1 remaining stake in ERC20 pool:", Strings.toString(user1StakeAmount / 10**18), "TEST");
        console.log("- User2 remaining stake in ETH pool:", Strings.toString(user2StakeAmount / 10**18), "ETH");
        
        // 用户未提取余额
        uint256 user1TokenBalance = testToken.balanceOf(user1);
        uint256 user2EthBalance = user2.balance;
        console.log("- User1 TEST token balance:", Strings.toString(user1TokenBalance / 10**18), "TEST");
        console.log("- User2 ETH balance:", Strings.toString(user2EthBalance / 10**18), "ETH");
        
        // 系统总体状态
        uint256 totalPoolWeight = metaNodeStake.totalPoolWeight();
        console.log("- Total pool weight:", totalPoolWeight);
        console.log("- System status: Ready for withdrawal and pause function tests");
        
        console.log("+ Environment summary display completed");
    }

    /**
     * @notice 测试用例1：有到期请求时提现成功
     * @dev 验证当用户有到期的解除质押请求时，能够成功提现相应资产
     */
    function test01_SuccessfulWithdrawalWhenRequestsExpired() public {
        console.log("=== Testing Successful Withdrawal When Requests Are Expired ===");
        
        // 🕐 步骤1：等待ERC20池解除质押请求到期
        console.log("\n1. Waiting for ERC20 Pool Unstake Requests to Expire:");
        console.log("- ERC20 pool unlock period:", Strings.toString(ERC20_UNSTAKE_BLOCKS), "blocks");
        console.log("- Mining 4 blocks to exceed 3-block unlock period...");
        
        // 挖掘4个区块，超过3个区块的解锁周期
        vm.roll(block.number + 4);
        console.log("- Current block number:", Strings.toString(block.number));
        console.log("+ Unstake requests should now be expired and withdrawable");
        
        // 🔍 步骤2：记录提现前状态
        console.log("\n2. Recording Pre-withdrawal State:");
        
        uint256 userTokenBalanceBefore = testToken.balanceOf(user1);
        console.log("- User1 TEST token balance before:", Strings.toString(userTokenBalanceBefore / 10**18), "TEST");
        
        uint256 expectedWithdrawAmount = USER1_UNSTAKE_1 + USER1_UNSTAKE_2; // 500 + 300 = 800 TEST
        console.log("- Expected withdrawal amount:", Strings.toString(expectedWithdrawAmount / 10**18), "TEST");
        console.log("+ Pre-withdrawal state recorded");
        
        // 🚀 步骤3：执行提现操作
        console.log("\n3. Executing Withdrawal Operation:");
        console.log("- User1 attempting to withdraw from ERC20 pool (Pool #1)");
        
        // 预期触发Withdraw事件（检查所有4个参数，包括blockNumber）
        vm.expectEmit(true, true, true, true);
        emit Withdraw(user1, 1, expectedWithdrawAmount, block.number); // 传入当前的block number
        
        vm.prank(user1);
        metaNodeStake.withdraw(1); // ERC20池的ID是1
        
        console.log("+ Withdrawal operation executed successfully");
        
        // ✅ 步骤4：验证提现结果
        console.log("\n4. Verifying Withdrawal Results:");
        
        uint256 userTokenBalanceAfter = testToken.balanceOf(user1);
        uint256 expectedTokenBalance = userTokenBalanceBefore + expectedWithdrawAmount;
        
        console.log("- User1 TEST token balance after:", Strings.toString(userTokenBalanceAfter / 10**18), "TEST");
        console.log("- Expected token balance:", Strings.toString(expectedTokenBalance / 10**18), "TEST");
        
        assertEq(userTokenBalanceAfter, expectedTokenBalance, "User token balance should increase by withdrawal amount");
        console.log("+ User token balance correctly increased by 800 TEST");
        
        console.log("\n=== Successful Withdrawal Test Completed ===");
        console.log("+ User successfully withdrew 800 TEST from expired unstake requests");
    }

    /**
     * @notice 测试用例2：仅未到期不能提现
     * @dev 测试当解除质押请求尚未到期时，用户无法进行提现操作
     */
    function test02_CannotWithdrawWhenRequestsNotExpired() public {
        console.log("=== Testing Cannot Withdraw When Requests Not Expired ===");
        
        // 🔍 步骤1：确认ETH池解锁周期和当前状态
        console.log("\n1. Verifying ETH Pool Unlock Period and Current State:");
        console.log("- ETH pool unlock period:", Strings.toString(ETH_UNSTAKE_BLOCKS), "blocks");
        console.log("- Current block number:", Strings.toString(block.number));
        console.log("- User2 has unstake request for 0.2 ETH that is not yet expired");
        console.log("+ ETH unstake request is still within lock period");
        
        // 🔍 步骤2：记录提现前的用户余额
        console.log("\n2. Recording Pre-withdrawal State:");
        
        uint256 userEthBalanceBefore = user2.balance;
        console.log("- User2 ETH balance before attempt:", Strings.toString(userEthBalanceBefore / 10**18), "ETH");
        console.log("+ Pre-withdrawal state recorded");
        
        // 🚫 步骤3：尝试提现未到期的请求
        console.log("\n3. Attempting to Withdraw Unexpired Request:");
        console.log("- User2 attempting to withdraw from ETH pool (Pool #0)");
        console.log("- Expected: Transaction should be rejected");
        
        vm.expectRevert("no withdrawable amount");
        vm.prank(user2);
        metaNodeStake.withdraw(0); // ETH池的ID是0
        
        console.log("+ Withdrawal attempt correctly rejected");
        
        // ✅ 步骤4：验证余额几乎没有变化（仅gas费用）
        console.log("\n4. Verifying Balance Remains Unchanged:");
        
        uint256 userEthBalanceAfter = user2.balance;
        console.log("- User2 ETH balance after failed attempt:", Strings.toString(userEthBalanceAfter / 10**18), "ETH");
        
        // ETH余额应该基本不变（可能有微小的gas费变化）
        uint256 balanceDifference = userEthBalanceBefore > userEthBalanceAfter 
            ? userEthBalanceBefore - userEthBalanceAfter 
            : userEthBalanceAfter - userEthBalanceBefore;
        
        // 验证余额变化很小（主要是gas费用）
        assertTrue(balanceDifference < 0.001 ether, "ETH balance should remain mostly unchanged");
        console.log("+ User ETH balance unchanged (except for gas fees)");
        
        console.log("\n=== Cannot Withdraw Unexpired Requests Test Completed ===");
        console.log("+ System correctly prevents withdrawal of unexpired unstake requests");
    }

    /**
     * @notice 测试用例3：多次请求全部提现后清空状态
     * @dev 验证用户多次发起解除质押请求后，能够一次性提现所有到期请求，并且提现后队列状态被正确清空
     */
    function test03_WithdrawAllRequestsAndClearQueue() public {
        console.log("=== Testing Withdraw All Requests and Clear Queue ===");
        
        // 🔄 步骤1：用户发起第三次解除质押请求
        console.log("\n1. User Makes Additional Unstake Request:");
        
        uint256 thirdUnstakeAmount = 200 * 10**18; // 第三次解除质押200 TEST
        console.log("- User1 making third unstake request:", Strings.toString(thirdUnstakeAmount / 10**18), "TEST");
        
        vm.prank(user1);
        metaNodeStake.unStake(1, thirdUnstakeAmount);
        console.log("+ Third unstake request created");
        
        // 🕐 步骤2：等待所有请求到期
        console.log("\n2. Waiting for All Requests to Expire:");
        console.log("- Mining 4 blocks to ensure all requests expire...");
        
        vm.roll(block.number + 4);
        console.log("- Current block number:", Strings.toString(block.number));
        console.log("+ All unstake requests should now be expired");
        
        // 🔍 步骤3：记录提现前状态
        console.log("\n3. Recording Pre-withdrawal State:");
        
        uint256 userTokenBalanceBefore = testToken.balanceOf(user1);
        console.log("- User1 TEST token balance before:", Strings.toString(userTokenBalanceBefore / 10**18), "TEST");
        
        uint256 totalExpectedWithdraw = USER1_UNSTAKE_1 + USER1_UNSTAKE_2 + thirdUnstakeAmount; // 500 + 300 + 200 = 1000 TEST
        console.log("- Total expected withdrawal:", Strings.toString(totalExpectedWithdraw / 10**18), "TEST");
        console.log("+ Pre-withdrawal state recorded");
        
        // 🚀 步骤4：第一次提现（应该成功提取所有到期请求）
        console.log("\n4. First Withdrawal - All Expired Requests:");
        console.log("- User1 withdrawing all expired requests from ERC20 pool");
        
        vm.prank(user1);
        metaNodeStake.withdraw(1);
        
        uint256 userTokenBalanceAfter = testToken.balanceOf(user1);
        uint256 actualWithdrawn = userTokenBalanceAfter - userTokenBalanceBefore;
        
        console.log("- Actual withdrawn amount:", Strings.toString(actualWithdrawn / 10**18), "TEST");
        assertEq(actualWithdrawn, totalExpectedWithdraw, "Should withdraw all expired requests");
        console.log("+ First withdrawal successful - all 1000 TEST withdrawn");
        
        // 🚫 步骤5：第二次尝试提现（应该被拒绝）
        console.log("\n5. Second Withdrawal Attempt - Should Be Rejected:");
        console.log("- User1 attempting second withdrawal from same pool");
        console.log("- Expected: No more withdrawable amounts available");
        
        vm.expectRevert("no withdrawable amount");
        vm.prank(user1);
        metaNodeStake.withdraw(1);
        
        console.log("+ Second withdrawal correctly rejected - queue is empty");
        
        // ✅ 步骤6：验证最终状态
        console.log("\n6. Verifying Final State:");
        
        uint256 finalTokenBalance = testToken.balanceOf(user1);
        console.log("- User1 final TEST token balance:", Strings.toString(finalTokenBalance / 10**18), "TEST");
        
        assertEq(finalTokenBalance, userTokenBalanceAfter, "Balance should remain unchanged after failed second withdrawal");
        console.log("+ Final balance confirmed - no additional withdrawals occurred");
        
        console.log("\n=== Withdraw All Requests and Clear Queue Test Completed ===");
        console.log("+ System correctly handles batch withdrawal and queue cleanup");
    }

    /**
     * @notice 测试用例4：暂停提现功能后不能提现
     * @dev 测试当管理员暂停提现功能后，用户无法进行提现操作
     */
    function test04_CannotWithdrawWhenPaused() public {
        console.log("=== Testing Cannot Withdraw When Function is Paused ===");
        
        // 🕐 步骤1：等待解除质押请求到期
        console.log("\n1. Waiting for Unstake Requests to Expire:");
        console.log("- Mining 4 blocks to make requests withdrawable...");
        
        vm.roll(block.number + 4);
        console.log("- Current block number:", Strings.toString(block.number));
        console.log("+ Unstake requests are now expired and normally withdrawable");
        
        // 🔒 步骤2：管理员暂停提现功能
        console.log("\n2. Admin Pausing Withdraw Function:");
        
        vm.prank(owner);
        metaNodeStake.setPausedStates(false, false, true, false); // 只暂停提现功能
        
        bool isWithdrawPaused = metaNodeStake.withdrawPaused();
        console.log("- Withdraw function status: PAUSED");
        assertTrue(isWithdrawPaused, "Withdraw should be paused");
        console.log("+ Withdraw function successfully paused by admin");
        
        // 🔍 步骤3：记录暂停前的用户余额
        console.log("\n3. Recording Pre-withdrawal State:");
        
        uint256 userTokenBalanceBefore = testToken.balanceOf(user1);
        console.log("- User1 TEST token balance before attempt:", Strings.toString(userTokenBalanceBefore / 10**18), "TEST");
        console.log("+ Pre-withdrawal state recorded");
        
        // 🚫 步骤4：尝试提现已到期的请求（应该被拒绝）
        console.log("\n4. Attempting Withdrawal While Paused:");
        console.log("- User1 attempting to withdraw expired requests while function is paused");
        console.log("- Expected: Transaction should be rejected with pause error");
        
        vm.expectRevert("withdraw is paused");
        vm.prank(user1);
        metaNodeStake.withdraw(1);
        
        console.log("+ Withdrawal attempt correctly rejected due to pause");
        
        // ✅ 步骤5：验证用户余额保持不变
        console.log("\n5. Verifying Balance Remains Unchanged:");
        
        uint256 userTokenBalanceAfter = testToken.balanceOf(user1);
        console.log("- User1 TEST token balance after failed attempt:", Strings.toString(userTokenBalanceAfter / 10**18), "TEST");
        
        assertEq(userTokenBalanceAfter, userTokenBalanceBefore, "User token balance should remain unchanged");
        console.log("+ User token balance unchanged - no withdrawal occurred");
        
        // 🔓 步骤6：恢复提现功能进行验证
        console.log("\n6. Restoring Withdraw Function for Verification:");
        
        vm.prank(owner);
        metaNodeStake.setPausedStates(false, false, false, false); // 恢复所有功能
        
        bool isWithdrawActive = !metaNodeStake.withdrawPaused();
        console.log("- Withdraw function status: ACTIVE");
        assertTrue(isWithdrawActive, "Withdraw should be active");
        console.log("+ Withdraw function successfully restored");
        
        console.log("\n=== Cannot Withdraw When Paused Test Completed ===");
        console.log("+ Admin control over withdraw function is effective");
        console.log("+ System correctly enforces pause restrictions");
    }

}
