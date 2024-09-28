// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControlEnumerableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";

import {IPauser, IPauserWrite, IPauserRead} from "./interfaces/IPauser.sol";

interface PauserEvents {
    /// @notice Emitted when a flag has been updated.
    /// @param selector The selector of the flag that was updated.
    /// @param isPaused The new value of the flag.
    /// @param flagName The name of the flag that was updated.
    event FlagUpdated(bytes4 indexed selector, bool indexed isPaused, string flagName);
}

/// @title Pauser
/// @notice Keeps the state of all actions that can be paused in case of exceptional circumstances. Pause state
/// is stored as boolean properties on the contract. This design was intentionally chosen to ensure there are explicit
/// compiler checks for the names and states of the different actions.
contract Pauser is AccessControlEnumerableUpgradeable, IPauser, PauserEvents {
    // Errors.
    error PauserRoleNotRequired(address sender);

    /// @notice Pauser role can pause flags in the contract.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Unpauser role can unpause flags in the contract.
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    /// @inheritdoc IPauserRead
    bool public isStakingPaused;

    /// @inheritdoc IPauserRead
    bool public isAllocationPaused;

    /// @inheritdoc IPauserRead
    bool public isClaimPaused;

    /// @notice Configuration for contract initialization.
    struct Init {
        address admin;
        address pauser;
        address unpauser;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Inititalizes the contract.
    /// @dev MUST be called during the contract upgrade to set up the proxies state.
    function initialize(Init memory init) external initializer {
        __AccessControlEnumerable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, init.admin);
        _grantRole(PAUSER_ROLE, init.pauser);
        _grantRole(UNPAUSER_ROLE, init.unpauser);
    }

    /// @notice Pauses or unpauses deposit.
    /// @dev If pausing, checks if the caller has the pauser role. If unpausing,
    /// checks if the caller has the unpauser role.
    function setIsStakingPaused(bool isPaused) external onlyPauserUnpauserRole(isPaused) {
        _setIsStakingPaused(isPaused);
    }

    /// @notice Pauses or unpauses withdraw requests.
    /// @dev If pausing, checks if the caller has the pauser role. If unpausing,
    /// checks if the caller has the unpauser role.
    function setIsAllocationPaused(bool isPaused) external onlyPauserUnpauserRole(isPaused) {
        _setIsAllocationPaused(isPaused);
    }

    /// @notice Pauses or unpauses swap.
    /// @dev If pausing, checks if the caller has the pauser role. If unpausing,
    /// checks if the caller has the unpauser role.
    function setIsClaimPaused(bool isPaused) external onlyPauserUnpauserRole(isPaused) {
        _setIsClaimPaused(isPaused);
    }

    /// @inheritdoc IPauserWrite
    /// @dev Can be called by the oracle or any account with the pauser role.
    function pauseAll() external {
        _verifyPauser();

        _setIsStakingPaused(true);
        _setIsAllocationPaused(true);
        _setIsClaimPaused(true);
    }

    /// @notice Unpauses all actions.
    function unpauseAll() external onlyRole(UNPAUSER_ROLE) {
        _setIsStakingPaused(false);
        _setIsAllocationPaused(false);
        _setIsClaimPaused(false);
    }

    function _verifyPauser() internal view {
        if (hasRole(PAUSER_ROLE, _msgSender())) {
            return;
        }
        revert PauserRoleNotRequired(_msgSender());
    }

    // Internal setter functions.
    function _setIsStakingPaused(bool isPaused) internal {
        isStakingPaused = isPaused;
        emit FlagUpdated(this.setIsStakingPaused.selector, isPaused, "setIsStakingPaused");
    }

    function _setIsAllocationPaused(bool isPaused) internal {
        isAllocationPaused = isPaused;
        emit FlagUpdated(this.setIsAllocationPaused.selector, isPaused, "setIsAllocationPaused");
    }

    function _setIsClaimPaused(bool isPaused) internal {
        isClaimPaused = isPaused;
        emit FlagUpdated(this.setIsClaimPaused.selector, isPaused, "setIsClaimPaused");
    }

    modifier onlyPauserUnpauserRole(bool isPaused) {
        if (isPaused) {
            _checkRole(PAUSER_ROLE);
        } else {
            _checkRole(UNPAUSER_ROLE);
        }
        _;
    }
}
