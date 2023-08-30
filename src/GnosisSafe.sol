// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

interface GnosisSafe {
    enum Operation {Call, DelegateCall}

    function VERSION() external returns(string memory);

    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) external payable returns (bool success);
}
