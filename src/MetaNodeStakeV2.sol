// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

// 升级版本的 MetaNodeStake 合约 - 用于测试升级功能
contract MetaNodeStakeV2 is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;
    using Address for address;
    using Math for uint256;

    // ************************************** CONSTANTS **************************************

    bytes32 public constant ADMIN_ROLE = keccak256("admin_role");
    bytes32 public constant UPGRADE_ROLE = keccak256("upgrade_role");

    uint256 public constant ETH_PID = 0;

    // ************************************** DATA STRUCTURE **************************************
    /*
    Basically, any point in time, the amount of MetaNodes entitled to a user but is pending to be distributed is:

    pending MetaNode = (user.stAmount * pool.accMetaNodePerST) - user.finishedMetaNode

    Whenever a user deposits or withdraws staking tokens to a pool. Here's what happens:
    1. The pool's `accMetaNodePerST` (and `lastRewardBlock`) gets updated.
    2. User receives the pending MetaNode sent to his/her address.
    3. User's `stAmount` gets updated.
    4. User's `finishedMetaNode` gets updated.
    */
    struct Pool {
        // Address of staking token
        address stTokenAddress;
        // Weight of pool
        uint256 poolWeight;
        // Last block number that MetaNodes distribution occurs for pool
        uint256 lastRewardBlock;
        // Accumulated MetaNodes per staking token of pool
        uint256 accMetaNodePerST;
        // Staking token amount
        uint256 stTokenAmount;
        // Min staking amount
        uint256 minDepositAmount;
        // Withdraw locked blocks
        uint256 unstakeLockedBlocks;
    }

    struct UnstakeRequest {
        // Request withdraw amount
        uint256 amount;
        // The blocks when the request withdraw amount can be released
        uint256 unlockBlocks;
    }

    struct User {
        // Staking token amount that user provided
        uint256 stAmount;
        // Finished distributed MetaNodes to user
        uint256 finishedMetaNode;
        // Pending to claim MetaNodes
        uint256 pendingMetaNode;
        // Withdraw request list
        UnstakeRequest[] requests;
    }

    // ************************************** STATE VARIABLES **************************************
    
    // 注意：为了保持存储布局兼容性，必须与 MetaNodeStake.sol 保持相同的变量顺序
    // 新的状态变量只能添加在末尾
    
    // MetaNode token reward per block
    uint256 public MetaNodePerBlock;

    // 细粒度暂停控制
    bool public stakingPaused;     // 暂停质押功能
    bool public unstakingPaused;   // 暂停解除质押功能
    bool public withdrawPaused;    // 暂停提取功能
    bool public claimPaused;       // 暂停领奖功能

    // MetaNode token
    IERC20 public MetaNode;

    // Total pool weight / Sum of all pool weights
    uint256 public totalPoolWeight;
    Pool[] public pool;

    // pool id => user address => user info
    mapping(uint256 => mapping(address => User)) public user;

    // ****** V2 新增状态变量 - 必须在末尾添加 ******
    
    // 新增：版本标识
    string public version;

    // 新增：额外功能标识
    bool public hasNewFeature;

    // ************************************** EVENTS **************************************

    event Upgraded(string newVersion);
    event NewFeatureEnabled(bool enabled);

    // ************************************** INITIALIZER **************************************

    function initialize(
        IERC20 _MetaNode,
        uint256 _MetaNodePerBlock
    ) public initializer {
        require(address(_MetaNode) != address(0), "invalid MetaNode address");
        require(_MetaNodePerBlock > 0, "invalid MetaNodePerBlock");

        __AccessControl_init();
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADE_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        MetaNode = _MetaNode;
        MetaNodePerBlock = _MetaNodePerBlock;
        version = "2.0.0";
        hasNewFeature = true;

        emit Upgraded(version);
    }

    // V2 专用初始化函数 - 在升级时调用
    function initializeV2() external reinitializer(2) {
        version = "2.0.0";
        hasNewFeature = true;
        emit Upgraded(version);
        emit NewFeatureEnabled(hasNewFeature);
    }

    /**
     * @notice Constructor that disables initializers for the implementation contract
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal view override onlyRole(UPGRADE_ROLE) {
        // 升级权限检查
        require(newImplementation != address(0), "Invalid implementation address");
        require(newImplementation.code.length > 0, "Implementation must be a contract");
    }

    // ************************************** NEW FEATURES IN V2 **************************************

    /**
     * @notice 新增功能：获取版本信息
     */
    function getVersion() external view returns (string memory) {
        return version;
    }

    /**
     * @notice 新增功能：切换新特性
     */
    function toggleNewFeature() external onlyRole(ADMIN_ROLE) {
        hasNewFeature = !hasNewFeature;
        emit NewFeatureEnabled(hasNewFeature);
    }

    /**
     * @notice 新增功能：批量更新设置
     */
    function batchUpdateSettings(
        uint256 _newMetaNodePerBlock,
        bool _newFeatureState
    ) external onlyRole(ADMIN_ROLE) {
        require(_newMetaNodePerBlock > 0, "invalid MetaNodePerBlock");
        
        MetaNodePerBlock = _newMetaNodePerBlock;
        hasNewFeature = _newFeatureState;
        
        emit NewFeatureEnabled(_newFeatureState);
    }

    // ************************************** ADMIN FUNCTIONS **************************************

    function setMetaNode(IERC20 _MetaNode) public onlyRole(ADMIN_ROLE) {
        require(address(_MetaNode) != address(0), "invalid MetaNode address");
        MetaNode = _MetaNode;
    }

    /**
     * @notice 暂停全局功能
     */
    function pauseGlobal(bool _paused) external onlyRole(ADMIN_ROLE) {
        if (_paused) {
            _pause();
        } else {
            _unpause();
        }
    }
}
