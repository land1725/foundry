// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/MetaNode.sol";
import "src/MetaNodeStake.sol";
import "src/MetaNodeStakeV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract MetaNodeTest is Test {
    MetaNode public metaNode;
    MetaNodeStake public metaNodeStake;
    address public owner;
    address public user1;
    address public user2;
    
    // 测试参数
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18; // 1亿代币
    uint256 public constant META_NODE_PER_BLOCK = 100 * 10**18; // 每个区块100个代币奖励

    function setUp() public {
        console.log("=== Starting test environment initialization ===");
        
        // 1. Get account addresses as different wallet identities
        owner = address(0x1);
        user1 = address(0x2);
        user2 = address(0x3);
        
        console.log("Account addresses:");
        console.log("- Owner:", owner);
        console.log("- User1:", user1);
        console.log("- User2:", user2);
        
        // 2. Deploy MetaNode contract using proxy pattern
        console.log("\nDeploying MetaNode token contract...");
        
        // Deploy logic contract
        MetaNode metaNodeLogic = new MetaNode();
        console.log("MetaNode logic contract address:", address(metaNodeLogic));
        
        // Prepare initialization data
        bytes memory metaNodeInitData = abi.encodeWithSelector(
            MetaNode.initialize.selector, 
            owner, // recipient
            owner  // initialOwner
        );
        
        // 关键修改：使用 vm.prank 确保初始化时的 msg.sender 是 owner
        vm.prank(owner);
        ERC1967Proxy metaNodeProxy = new ERC1967Proxy(
            address(metaNodeLogic), 
            metaNodeInitData
        );
        
        metaNode = MetaNode(address(metaNodeProxy));
        
        console.log("MetaNode proxy contract address:", address(metaNode));
        
        // 3. Deploy MetaNodeStake contract using proxy pattern
        console.log("\nDeploying MetaNodeStake staking contract...");
        
        // Deploy logic contract
        MetaNodeStake metaNodeStakeLogic = new MetaNodeStake();
        console.log("MetaNodeStake logic contract address:", address(metaNodeStakeLogic));
        
        // Prepare initialization data
        bytes memory metaNodeStakeInitData = abi.encodeWithSelector(
            MetaNodeStake.initialize.selector,
            IERC20(address(metaNode)),
            META_NODE_PER_BLOCK
        );
        
        // 关键修改：使用 vm.prank 确保初始化时的 msg.sender 是 owner
        vm.prank(owner);
        ERC1967Proxy metaNodeStakeProxy = new ERC1967Proxy(
            address(metaNodeStakeLogic), 
            metaNodeStakeInitData
        );
        
        metaNodeStake = MetaNodeStake(payable(address(metaNodeStakeProxy)));
        
        console.log("MetaNodeStake proxy contract address:", address(metaNodeStake));
        
        // 4. Get deployed contract instances and read important parameters
        console.log("\n=== Reading important parameters ===");
        
        // MetaNode token contract parameters
        console.log("MetaNode token info:");
        console.log("- Name:", metaNode.name());
        console.log("- Symbol:", metaNode.symbol());
        console.log("- Decimals:", metaNode.decimals());
        console.log("- Total supply:", metaNode.totalSupply());
        console.log("- Owner balance:", metaNode.balanceOf(owner));
        console.log("- Contract owner:", metaNode.owner());
        
        // MetaNodeStake staking contract parameters
        console.log("\nMetaNodeStake staking contract info:");
        console.log("- MetaNode token contract address:", address(metaNodeStake.MetaNode()));
        console.log("- Reward per block:", metaNodeStake.MetaNodePerBlock());
        
        // 5. Verify proxy contract addresses are valid and ensure contracts and proxies are working
        console.log("\n=== Verifying contract deployment status ===");
        
        // Verify MetaNode contract
        assertTrue(address(metaNode) != address(0), "MetaNode contract address invalid");
        assertTrue(metaNode.totalSupply() > 0, "MetaNode total supply should be greater than 0");
        assertTrue(metaNode.balanceOf(owner) == INITIAL_SUPPLY, "Owner initial balance incorrect");
        assertEq(metaNode.owner(), owner, "MetaNode owner incorrect");
        console.log("+ MetaNode contract verification passed");
        
        // Verify MetaNodeStake contract
        assertTrue(address(metaNodeStake) != address(0), "MetaNodeStake contract address invalid");
        assertTrue(address(metaNodeStake.MetaNode()) == address(metaNode), "Token address in MetaNodeStake incorrect");
        assertTrue(metaNodeStake.MetaNodePerBlock() == META_NODE_PER_BLOCK, "Reward per block incorrect");
        console.log("+ MetaNodeStake contract verification passed");
        
        console.log("\n=== Test environment initialization completed ===");
    }

    // 测试用例1：部署初始化和升级权限验证
    function test01_DeploymentInitializationAndUpgrade() public {
        console.log("=== Testing deployment initialization and upgrade ===");
        
        // 1. 代币地址验证
        console.log("\n1. Token Address Verification:");
        address recordedTokenAddress = address(metaNodeStake.MetaNode());
        address actualTokenAddress = address(metaNode);
        
        assertEq(recordedTokenAddress, actualTokenAddress, "Token address mismatch in staking contract");
        assertTrue(recordedTokenAddress != address(0), "Token address should not be zero");
        console.log("+ Token address verification passed");
        
        // 2. 奖励参数验证
        console.log("\n2. Reward Parameter Verification:");
        uint256 recordedRewardPerBlock = metaNodeStake.MetaNodePerBlock();
        uint256 expectedRewardPerBlock = META_NODE_PER_BLOCK; // 100 * 10^18
        
        assertEq(recordedRewardPerBlock, expectedRewardPerBlock, "Reward per block mismatch");
        assertTrue(recordedRewardPerBlock > 0, "Reward per block should be greater than 0");
        assertEq(recordedRewardPerBlock, 100 * 10**18, "Reward should be exactly 100 tokens (100 * 10^18 wei)");
        console.log("+ Reward parameter verification passed");
        
        // 3. 权限角色验证
        console.log("\n3. Permission Role Verification:");
        
        // 检查 DEFAULT_ADMIN_ROLE
        bytes32 defaultAdminRole = metaNodeStake.DEFAULT_ADMIN_ROLE();
        bool hasDefaultAdminRole = metaNodeStake.hasRole(defaultAdminRole, owner);
        assertTrue(hasDefaultAdminRole, "Owner should have DEFAULT_ADMIN_ROLE");
        
        // 检查 UPGRADE_ROLE
        bytes32 upgradeRole = metaNodeStake.UPGRADE_ROLE();
        bool hasUpgradeRole = metaNodeStake.hasRole(upgradeRole, owner);
        assertTrue(hasUpgradeRole, "Owner should have UPGRADE_ROLE");
        
        // 检查 ADMIN_ROLE
        bytes32 adminRole = metaNodeStake.ADMIN_ROLE();
        bool hasAdminRole = metaNodeStake.hasRole(adminRole, owner);
        assertTrue(hasAdminRole, "Owner should have ADMIN_ROLE");
        
        // 验证非授权用户没有这些权限
        console.log("\n4. Non-authorized User Permission Check:");
        bool user1HasDefaultAdmin = metaNodeStake.hasRole(defaultAdminRole, user1);
        bool user1HasUpgrade = metaNodeStake.hasRole(upgradeRole, user1);
        bool user1HasAdmin = metaNodeStake.hasRole(adminRole, user1);
        
        assertTrue(!user1HasDefaultAdmin, "User1 should not have DEFAULT_ADMIN_ROLE");
        assertTrue(!user1HasUpgrade, "User1 should not have UPGRADE_ROLE");
        assertTrue(!user1HasAdmin, "User1 should not have ADMIN_ROLE");
        
        console.log("+ All permission role verifications passed");
    }

    // 安全防护测试：零地址、零参数和二次初始化防护
    function test02_SecurityProtections() public {
        console.log("=== Testing security protections ===");
        
        // 1. 零地址代币防护测试
        console.log("\n1. Zero Address Token Protection Test:");
        
        // 部署逻辑合约
        MetaNodeStake zeroTestLogic = new MetaNodeStake();
        console.log("- Deploy logic contract for zero address test");
        
        // 准备无效的初始化数据（零地址代币）
        bytes memory invalidTokenInitData = abi.encodeWithSelector(
            MetaNodeStake.initialize.selector,
            IERC20(address(0)), // 零地址代币
            META_NODE_PER_BLOCK
        );
        
        // 尝试部署代理合约，应该失败
        vm.prank(owner);
        vm.expectRevert("invalid MetaNode address");
        new ERC1967Proxy(address(zeroTestLogic), invalidTokenInitData);
        
        console.log("+ Zero address token protection test passed");
        
        // 2. 零奖励参数防护测试
        console.log("\n2. Zero Reward Parameter Protection Test:");
        
        // 准备无效的初始化数据（零奖励）
        bytes memory invalidRewardInitData = abi.encodeWithSelector(
            MetaNodeStake.initialize.selector,
            IERC20(address(metaNode)), // 有效的代币地址
            0 // 零奖励
        );
        
        // 尝试部署代理合约，应该失败
        vm.prank(owner);
        vm.expectRevert("invalid MetaNodePerBlock");
        new ERC1967Proxy(address(zeroTestLogic), invalidRewardInitData);
        
        console.log("+ Zero reward parameter protection test passed");
        
        // 3. 二次初始化防护测试
        console.log("\n3. Double Initialization Protection Test:");
        
        // 尝试对已初始化的合约再次初始化
        vm.prank(owner);
        vm.expectRevert(); // 期望任何 revert，不指定具体错误消息
        metaNodeStake.initialize(
            IERC20(address(metaNode)),
            META_NODE_PER_BLOCK
        );
        
        console.log("+ Double initialization protection test passed");
        
        
        // 5. 测试MetaNode合约的二次初始化防护
        console.log("\n5. MetaNode Double Initialization Protection Test:");
        
        vm.prank(owner);
        vm.expectRevert(); // 期望任何 revert，不指定具体错误消息
        metaNode.initialize(owner, owner);
        
        console.log("+ MetaNode double initialization protection test passed");
        
        console.log("\n=== All security protection tests completed successfully ===");
    }

    // 测试用例3：升级权限验证
    function test03_UpgradePermissionVerification() public {
        console.log("=== Testing upgrade permission verification ===");
        
        bytes32 upgradeRole = metaNodeStake.UPGRADE_ROLE();
        
        // 验证合约所有者拥有升级权限
        bool ownerHasUpgradeRole = metaNodeStake.hasRole(upgradeRole, owner);
        console.log("- Owner has UPGRADE_ROLE:", ownerHasUpgradeRole);
        assertTrue(ownerHasUpgradeRole, "Owner should have UPGRADE_ROLE");
        
        // 验证无权限账户没有升级权限
        bool user1HasUpgradeRole = metaNodeStake.hasRole(upgradeRole, user1);
        console.log("- User1 has UPGRADE_ROLE:", user1HasUpgradeRole);
        assertTrue(!user1HasUpgradeRole, "User1 should not have UPGRADE_ROLE");
        
        // 验证user2也没有升级权限
        bool user2HasUpgradeRole = metaNodeStake.hasRole(upgradeRole, user2);
        console.log("- User2 has UPGRADE_ROLE:", user2HasUpgradeRole);
        assertTrue(!user2HasUpgradeRole, "User2 should not have UPGRADE_ROLE");
        
        console.log("+ Upgrade permission verification completed successfully");
    }

    // 测试用例4：升级约束校验
    function test04_UpgradeConstraintValidation() public {
        console.log("=== Testing upgrade constraint validation ===");
        
        // 测试升级到零地址
        console.log("- Testing upgrade to zero address...");
        vm.prank(owner);
        vm.expectRevert("invalid implementation address");
        metaNodeStake.upgradeToAndCall(address(0), "");
        console.log("+ Zero address protection test passed");
        
        // 测试升级到非合约地址（EOA地址）
        console.log("- Testing upgrade to EOA address...");
        vm.prank(owner);
        vm.expectRevert("implementation must be a contract");
        metaNodeStake.upgradeToAndCall(user2, "");
        console.log("+ EOA address protection test passed");
        
        // 测试无权限用户尝试升级
        console.log("- Testing unauthorized upgrade attempt...");
        MetaNodeStakeV2 newLogic = new MetaNodeStakeV2();
        vm.prank(user1); // 使用无权限用户
        vm.expectRevert(); // 期望权限检查失败
        metaNodeStake.upgradeToAndCall(address(newLogic), "");
        console.log("+ Unauthorized upgrade protection test passed");
        
        console.log("+ All upgrade constraint validations completed successfully");
    }

    // 测试用例5：升级流程验证与状态一致性
    function test05_UpgradeProcessAndStateConsistency() public {
        console.log("=== Testing upgrade process and state consistency ===");
        console.log(string.concat("Test Case 3 - Starting block number: ", Strings.toString(block.number)));
        
        bytes32 upgradeRole = metaNodeStake.UPGRADE_ROLE();
        
        // 记录升级前的状态
        console.log("- Recording pre-upgrade state...");
        address preUpgradeToken = address(metaNodeStake.MetaNode());
        uint256 preUpgradeReward = metaNodeStake.MetaNodePerBlock();
        bool preUpgradeOwnerRole = metaNodeStake.hasRole(upgradeRole, owner);
        
        console.log("  Pre-upgrade token address:", preUpgradeToken);
        console.log("  Pre-upgrade reward per block:", preUpgradeReward);
        console.log("  Pre-upgrade owner has UPGRADE_ROLE:", preUpgradeOwnerRole);
        
        // 部署新的逻辑合约
        MetaNodeStakeV2 newLogic = new MetaNodeStakeV2();
        console.log("- New logic contract deployed:", address(newLogic));
        
        // 执行升级操作
        console.log("- Executing upgrade...");
        vm.prank(owner);
        metaNodeStake.upgradeToAndCall(address(newLogic), "");
        
        // 将代理转换为新版本接口
        MetaNodeStakeV2 upgradedStake = MetaNodeStakeV2(payable(address(metaNodeStake)));
        console.log("+ Upgrade execution completed");
        
        // 验证升级后状态一致性
        console.log("- Verifying state consistency after upgrade...");
        address postUpgradeToken = address(upgradedStake.MetaNode());
        uint256 postUpgradeReward = upgradedStake.MetaNodePerBlock();
        bool postUpgradeOwnerRole = upgradedStake.hasRole(upgradeRole, owner);
        
        console.log("  Post-upgrade token address:", postUpgradeToken);
        console.log("  Post-upgrade reward per block:", postUpgradeReward);
        console.log("  Post-upgrade owner has UPGRADE_ROLE:", postUpgradeOwnerRole);
        
        // 验证关键状态保持不变
        assertEq(postUpgradeToken, preUpgradeToken, "Token address should remain unchanged");
        assertEq(postUpgradeReward, preUpgradeReward, "Reward per block should remain unchanged");
        assertTrue(postUpgradeOwnerRole, "Owner should still have UPGRADE_ROLE");
        
        console.log("+ State consistency verification completed successfully");
    }

    // 测试用例6：新功能验证与权限管理
    function test06_NewFeaturesAndPermissionManagement() public {
        console.log("=== Testing new features and permission management ===");
        console.log(string.concat("Test Case 4 - Starting block number: ", Strings.toString(block.number)));
        
        // 首先执行升级（这个测试依赖于升级后的状态）
        MetaNodeStakeV2 newLogic = new MetaNodeStakeV2();
        
        // 准备升级数据，调用 initializeV2 来初始化新的状态变量
        bytes memory upgradeData = abi.encodeWithSelector(
            MetaNodeStakeV2.initializeV2.selector
        );
        
        vm.prank(owner);
        metaNodeStake.upgradeToAndCall(address(newLogic), upgradeData);
        
        MetaNodeStakeV2 upgradedStake = MetaNodeStakeV2(payable(address(metaNodeStake)));
        bytes32 upgradeRole = upgradedStake.UPGRADE_ROLE();
        
        // 测试新功能
        console.log("- Testing new features in V2...");
        
        // 测试版本信息功能
        string memory version = upgradedStake.getVersion();
        console.log("  Contract version:", version);
        assertEq(keccak256(bytes(version)), keccak256(bytes("2.0.0")), "Version should be 2.0.0");
        
        // 测试新特性状态
        bool hasNewFeature = upgradedStake.hasNewFeature();
        console.log("  Has new feature:", hasNewFeature);
        assertTrue(hasNewFeature, "New feature should be enabled by default");
        
        // 测试批量更新功能
        console.log("- Testing batch update functionality...");
        vm.prank(owner);
        upgradedStake.batchUpdateSettings(200 * 10**18, false);
        
        uint256 updatedReward = upgradedStake.MetaNodePerBlock();
        bool updatedFeature = upgradedStake.hasNewFeature();
        
        console.log("  Updated reward per block:", updatedReward);
        console.log("  Updated feature state:", updatedFeature);
        
        assertEq(updatedReward, 200 * 10**18, "Reward should be updated to 200 tokens");
        assertTrue(!updatedFeature, "Feature should be disabled");
        console.log("+ New features verification completed");
        
        // 测试权限管理
        console.log("- Testing permission management...");
        
        // 授予升级权限给新用户
        console.log("  Testing permission granting...");
        vm.prank(owner);
        upgradedStake.grantRole(upgradeRole, user1);
        
        bool user1HasRoleAfterGrant = upgradedStake.hasRole(upgradeRole, user1);
        console.log("  User1 has UPGRADE_ROLE after grant:", user1HasRoleAfterGrant);
        assertTrue(user1HasRoleAfterGrant, "User1 should have UPGRADE_ROLE after grant");
        
        // 撤销升级权限
        console.log("  Testing permission revocation...");
        vm.prank(owner);
        upgradedStake.revokeRole(upgradeRole, user1);
        
        bool user1HasRoleAfterRevoke = upgradedStake.hasRole(upgradeRole, user1);
        console.log("  User1 has UPGRADE_ROLE after revoke:", user1HasRoleAfterRevoke);
        assertTrue(!user1HasRoleAfterRevoke, "User1 should not have UPGRADE_ROLE after revoke");
        
        console.log("+ Permission management test completed successfully");
    }
}
