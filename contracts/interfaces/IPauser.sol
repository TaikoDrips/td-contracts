// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IPauserRead {
    /// @notice Flag indicating if staking is paused.
    function isStakingPaused() external view returns (bool);

    /// @notice Flag indicating if allocation is paused.
    function isAllocationPaused() external view returns (bool);

    /// @notice Flag indicating if claim is paused.
    function isClaimPaused() external view returns (bool);
}

interface IPauserWrite {
    /// @notice Pauses all actions.
    function pauseAll() external;

    /// @notice unPauses all actions.
    function unpauseAll() external;
}

interface IPauser is IPauserRead, IPauserWrite {}
