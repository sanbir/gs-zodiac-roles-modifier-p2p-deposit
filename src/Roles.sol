// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

interface Roles {
    enum Operation {Call, DelegateCall}

    enum ExecutionOptions {
        None,
        Send,
        DelegateCall,
        Both
    }

    function execTransactionWithRole(
        address to,
        uint256 value,
        bytes calldata data,
        Operation operation,
        uint16 role,
        bool shouldRevert
    ) external returns (bool success);

    function assignRoles(
        address module,
        uint16[] calldata _roles,
        bool[] calldata memberOf
    ) external;

    function allowTarget(
        uint16 role,
        address targetAddress,
        ExecutionOptions options
    ) external;

    function scopeAllowFunction(
        uint16 role,
        address targetAddress,
        bytes4 functionSig,
        ExecutionOptions options
    ) external;
}
