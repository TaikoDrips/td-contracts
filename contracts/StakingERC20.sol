// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {ProtocolEvents} from "./interfaces/ProtocolEvents.sol";
import {BareVaultUpgradable} from "./BareVaultUpgradable.sol";
import {LockupUpgradable} from "./LockupUpgradable.sol";
import {IPauser} from "./interfaces/IPauser.sol";

contract StakingERC20 is ProtocolEvents, BareVaultUpgradable, LockupUpgradable, ReentrancyGuardUpgradeable {
    // errors
    error AddressZeroNotExpected();
    error InsufficientWithdrawableBalance();
    error DepositOverBond();
    error Cooldown();
    error Paused();
    error DepositAmountTooSmall(address receiver, uint256 amount, uint256 minStake);

    // event
    event DepositWithDuration(address indexed owner, uint256 lockStart, uint256 amount, uint256 duration);

    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    // ------- LOGICS ------- //
    /// cooldown, minStake, maxStake
    bytes32 public constant STAKING_OPERATOR_ROLE = keccak256("STAKING_OPERATOR_ROLE");

    mapping(address => uint256) internal _userStakeCooldown;

    // The contract for indicating if staking is paused.
    IPauser public pauser;

    // the address of allocator register
    address public allocator;

    /// @notice Stake cooldown, not allowed to unstake when still in cool down duration
    /// This is to prevent high frequency reward sniping; or other borrow / flashloan to stake exploits.
    uint256 public cooldown;

    /// @notice stake min limit, limit on every staking
    uint256 public minStake;

    /// @notice stake max limit, limit on total supply
    uint256 public maxStakeSupply;

    receive() external payable override { revert("Not Allowed"); }
    fallback() external payable { revert("Not Allowed"); }

    // --------- Initialize ---------- //
    /// @notice Init params
    struct Init {
        address admin;
        address operator;
        address pauser;
        address asset;
        uint256 cooldown;
        uint256 minStake;
        uint256 maxStakeSupply;
        address allocator;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(Init calldata init) external initializer {
        __BareVault_init(init.asset);
        __ReentrancyGuard_init();

        // set admin roles
        _setRoleAdmin(STAKING_OPERATOR_ROLE, DEFAULT_ADMIN_ROLE);

        // grant admin roles
        _grantRole(DEFAULT_ADMIN_ROLE, init.admin);

        // grant sub roles
        _grantRole(STAKING_OPERATOR_ROLE, init.operator);

        // set slot
        cooldown = init.cooldown;
        minStake = init.minStake;
        maxStakeSupply = init.maxStakeSupply;
        allocator = init.allocator;
        pauser = IPauser(init.pauser);
        // initial durations
        acceptedDurations.add(60 days);
        acceptedDurations.add(91 days);
        acceptedDurations.add(182 days);
        acceptedDurations.add(365 days);
    }

    function deposit(uint256) public payable override nonReentrant returns (uint256) {
        revert("Not Allowed");
    }

    function deposit(uint256 assets, uint256 duration) public nonReentrant returns (uint256) {
        // only for param checking
        if (pauser.isStakingPaused()) {
            revert Paused();
        }
        uint256 maxAssets = maxDeposit(_msgSender());
        if (assets > maxAssets) {
            revert ExceededMaxDeposit(_msgSender(), assets, maxAssets);
        }
        if (assets < minStake) {
            revert DepositAmountTooSmall(_msgSender(), assets, minStake);
        }
        if (maxStakeSupply != 0 && assets + totalDeposit() > maxStakeSupply) {
            revert DepositOverBond();
        }

        _insertLockUp(_msgSender(), assets, duration * 24 * 3600);
        _updateLockUp(_msgSender());

        _userStakeCooldown[_msgSender()] = block.timestamp;
        _deposit(_msgSender(), assets);
        emit DepositWithDuration(_msgSender(), block.timestamp, assets, duration * 24 * 3600);

        return assets;
    }

    function withdraw(uint256 assets, address receiver) public override nonReentrant returns (uint256) {
        (bool inCooldown,) = this.userStakeCooldown(_msgSender());
        if (inCooldown) {
            revert Cooldown();
        }
        if (pauser.isStakingPaused()) {
            revert Paused();
        }
        _updateLockUp(_msgSender());
        UserLockStorage storage userLock = _getUserLockStorage();
        (,uint256 userLocked) = userLock._userLocked.tryGet(_msgSender());
        uint256 deposited_ = deposited(_msgSender());
        if (deposited_ - userLocked < assets) {
            revert InsufficientWithdrawableBalance();
        }
        return super.withdraw(assets, receiver);
    }

    function userStakeCooldown(address depositor) public view returns (bool, uint256) {
        if (depositor == address(0)) {
            revert AddressZeroNotExpected();
        }
        if (_userStakeCooldown[depositor] == 0) {
            return (false, 0);
        }

        if (block.timestamp < _userStakeCooldown[depositor]) {
            // unexpected time, won't happen
            return (true, 0);
        }
        if (block.timestamp >= _userStakeCooldown[depositor] + cooldown) {
            return (false, 0);
        }

        uint256 cooldown_ = cooldown - (block.timestamp - _userStakeCooldown[depositor]);
        return (true, cooldown_);
    }

    function setCooldown(uint256 newCooldown) external onlyRole(STAKING_OPERATOR_ROLE) {
        cooldown = newCooldown;
        emit ProtocolConfigChanged(this.setCooldown.selector, "setCooldown(uint256)", abi.encode(newCooldown));
    }

    function setMinStake(uint256 newMinStake) external onlyRole(STAKING_OPERATOR_ROLE) {
        minStake = newMinStake;
        emit ProtocolConfigChanged(this.setMinStake.selector, "setMinStake(uint256)", abi.encode(newMinStake));
    }

    function setMaxStakeSupply(uint256 newMaxStakeSupply) external onlyRole(STAKING_OPERATOR_ROLE) {
        maxStakeSupply = newMaxStakeSupply;
        emit ProtocolConfigChanged(this.setMaxStakeSupply.selector, "setMaxStakeSupply(uint256)", abi.encode(newMaxStakeSupply));
    }

    // emergency unlock in advance
    function unlockLockups(address[] memory users, uint256[] memory amounts) external onlyRole(STAKING_OPERATOR_ROLE) {
        require(users.length == amounts.length, "length must be equal");
        uint256 unlockAmount;
        for (uint256 i; i < users.length; i++) {
            _updateLockUp(users[i]);
            uint256 lockAmount = getUserLockUps(users[i]);
            if (lockAmount >= amounts[i]) {
                unlockAmount = _unlock(users[i], amounts[i]);
            }
        }
    }

    function addLockDuration(uint256 duration) external onlyRole(STAKING_OPERATOR_ROLE) returns (bool) {
        emit ProtocolConfigChanged(this.addLockDuration.selector, "addLockDuration(uint256)", abi.encode(duration));
        return _addLockDuration(duration);
    }

    function removeLockDuration(uint256 duration) external onlyRole(STAKING_OPERATOR_ROLE) returns (bool) {
        emit ProtocolConfigChanged(this.removeLockDuration.selector, "removeLockDuration(uint256)", abi.encode(duration));
        return _removeLockDuration(duration);
    }
}
