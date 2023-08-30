// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

interface P2pEth2Depositor {
    struct FeeRecipient {
        uint96 basisPoints;
        address payable recipient;
    }

    function deposit(
        bytes[] calldata _pubkeys,
        bytes calldata _withdrawal_credentials,
        bytes[] calldata _signatures,
        bytes32[] calldata _deposit_data_roots,
        FeeRecipient calldata _clientConfig,
        FeeRecipient calldata _referrerConfig
    ) external payable;
}
