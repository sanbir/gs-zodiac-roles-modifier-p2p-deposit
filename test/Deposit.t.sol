// SPDX-FileCopyrightText: 2023 P2P Validator <info@p2p.org>
// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";

import "../src/GnosisSafe.sol";
import "../src/Roles.sol";
import "../src/TimelockController.sol";
import "../src/MultiSendCallOnly.sol";
import "../src/P2pEth2Depositor.sol";

contract Deposit is Test {
    uint16 constant ROLE = 1;
    MultiSendCallOnly constant multiSendCallOnly = MultiSendCallOnly(0x40A2aCCbd92BCA938b02010E17A5b8929b49130D);

    TimelockController constant ensTimelockController = TimelockController(0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7); // ensSafe owner
    GnosisSafe constant ensSafe = GnosisSafe(0x4F2083f5fBede34C2714aFfb3105539775f7FE64); // roles owner
    Roles constant roles = Roles(0xf20325cf84b72e8BBF8D8984B8f0059B984B390B);
    address constant pilotSafeOwner1 = 0x07cD090220f96EA84F4d22aA68be4877EA286a9E;
    address constant pilotSafeOwner2 = 0x38243c6a32B5e31EA546e3116988EC8100AEA531;
    address constant pilotSafeOwner3 = 0x62497dedbe514fFBA23F3FC8AD976FbAEE439E4f;
    address constant pilotSafeOwner4 = 0xeC8fdF488806DFa8F88cb52e0e5833700F25A245;
    GnosisSafe constant pilotSafe = GnosisSafe(0xb423e0f6E7430fa29500c5cC9bd83D28c8BD8978);

//    TimelockController constant ensTimelockController = TimelockController(0x77777776dD9e859b22c029ab230E94779F83A541); // ensSafe owner
//    GnosisSafe constant ensSafe = GnosisSafe(0x14d91faAca6a7aa4C1ac371C15425eAc5A75dADB); // roles owner
//    Roles constant roles = Roles(0xa8824FE7760a06E2587C86b33640C981b5E31e0D);
//    address constant pilotSafeOwner = 0x000A0660FC6c21B6C8638c56f7a8BbE22DCC9000;
//    GnosisSafe constant pilotSafe = GnosisSafe(0x32795D2374A047e1B8591463cDB8E5B34c6dd89D);

    P2pEth2Depositor p2pEth2Depositor = P2pEth2Depositor(0x2E0743aAAB3118945564b715598B7DF10e083dC1);

    function setUp() public {
        vm.createSelectFork("mainnet");
        // vm.createSelectFork("goerli", 9601060);
    }

    function test_Deposit() public {
        allowPilotToDeposit();

        deposit();
    }

    function deposit() private {
        bytes memory execTransactionWithRoleCalldata = getExecTransactionWithRoleCalldata();

        address to = address(roles);
        uint256 value = 0;
        bytes memory data = execTransactionWithRoleCalldata;
        GnosisSafe.Operation operation = GnosisSafe.Operation.Call;
        uint256 safeTxGas = 0;
        uint256 baseGas = 0;
        uint256 gasPrice = 0;
        address gasToken = address(0);
        address payable refundReceiver = payable(address(0));

        uint256 nonce = pilotSafe.nonce();
        bytes32 txHash = pilotSafe.getTransactionHash(
            to,
            value,
            data,
            operation,
            safeTxGas,
            baseGas,
            gasPrice,
            gasToken,
            refundReceiver,
            nonce
        );

        vm.startPrank(address(pilotSafeOwner1));
        pilotSafe.approveHash(txHash);
        vm.stopPrank();

        bytes memory signatures = abi.encodePacked(
            hex'000000000000000000000000', address(pilotSafeOwner1), hex'00', uint256(1),
            hex'000000000000000000000000', address(pilotSafeOwner2), hex'00', uint256(1)
        );

        vm.startPrank(address(pilotSafeOwner2));
        pilotSafe.execTransaction(
            to,
            value,
            data,
            operation,
            safeTxGas,
            baseGas,
            gasPrice,
            gasToken,
            refundReceiver,
            signatures
        );
        vm.stopPrank();
    }

    function getExecTransactionWithRoleCalldata() private view returns(bytes memory execTransactionWithRoleCalldata) {
        address to = address(p2pEth2Depositor);
        uint256 value = 32 ether;
        bytes memory data = getDepositCalldata();
        Roles.Operation operation = Roles.Operation.Call;
        uint16 role = ROLE;
        bool shouldRevert = false;
        execTransactionWithRoleCalldata = abi.encodeWithSelector(
            Roles.execTransactionWithRole.selector,
            to,
            value,
            data,
            operation,
            role,
            shouldRevert
        );
    }

    function getDepositCalldata() private pure returns(bytes memory depositCalldata) {
        // IMPORTANT!!!
        // REPLACE with values with real ones!!!!

        bytes[] memory _pubkeys = new bytes[](1);
        _pubkeys[0] = bytes(hex'83a4ef7601d0cfb1c2eab8faac139742f4715e75ea0056ce15c8828796f1cf98d66285ebf50a369657ebe26e4b74487f');

        bytes memory _withdrawal_credentials = bytes(hex'01000000000000000000000014d91faaca6a7aa4c1ac371c15425eac5a75dadb');

        bytes[] memory _signatures = new bytes[](1);
        _signatures[0] = bytes(hex'82674fe50bf4c31fbd083a5942ffaf8b16dd656b721d08f7b1d0eab2afde193a2c84505d26aa051e0fbdf93a0dc5b6290c7aa50edae2cf77916ca3969fd84276c90fdcb4bff017af9041756d3a7ce5d3f0a8538b7b81ad2251d1d4a012a6b526');

        bytes32[] memory _deposit_data_roots = new bytes32[](1);
        _deposit_data_roots[0] = bytes32(hex'25be029c244762325fa02e572de477c994efa2d27a70a6425d14eea86da78de4');

        P2pEth2Depositor.FeeRecipient memory _clientConfig = P2pEth2Depositor.FeeRecipient({
            recipient: payable(address(ensSafe)),
            basisPoints: 10000
        });
        P2pEth2Depositor.FeeRecipient memory _referrerConfig = P2pEth2Depositor.FeeRecipient({
            recipient: payable(address(0)),
            basisPoints: 0
        });

        depositCalldata = abi.encodeWithSelector(
            P2pEth2Depositor.deposit.selector,
            _pubkeys,
            _withdrawal_credentials,
            _signatures,
            _deposit_data_roots,
            _clientConfig,
            _referrerConfig
        );
    }

    function allowPilotToDeposit() private {
        bytes memory txsForMultCall = getTxsForMultiCall();
        bytes memory multiSendCallData = abi.encodeWithSelector(
            MultiSendCallOnly.multiSend.selector, txsForMultCall
        );

        address to = address(multiSendCallOnly);
        uint256 value = 0;
        bytes memory data = multiSendCallData;
        GnosisSafe.Operation operation = GnosisSafe.Operation.DelegateCall;
        uint256 safeTxGas = 0;
        uint256 baseGas = 0;
        uint256 gasPrice = 0;
        address gasToken = address(0);
        address payable refundReceiver = payable(address(0));
        bytes memory signatures = abi.encodePacked(hex'000000000000000000000000', address(ensTimelockController), hex'00', uint256(1));

        vm.startPrank(address(ensTimelockController));
        ensSafe.execTransaction(
            to,
            value,
            data,
            operation,
            safeTxGas,
            baseGas,
            gasPrice,
            gasToken,
            refundReceiver,
            signatures
        );
        vm.stopPrank();
    }

    function getTxsForMultiCall() private view returns(bytes memory txsForMultCall) {
        bytes memory assignRolesCalldata = getAssignRolesCalldata();
        bytes memory allowTargetCalldata = getAllowTargetCalldata();
        bytes memory scopeAllowFunctionCalldata = getScopeAllowFunctionCalldata();

        bytes memory assignRolesTxForMultiSend = getTxForMultiSend(assignRolesCalldata);
        bytes memory allowTargetTxForMultiSend = getTxForMultiSend(allowTargetCalldata);
        bytes memory scopeAllowFunctionTxForMultiSend = getTxForMultiSend(scopeAllowFunctionCalldata);

        txsForMultCall = abi.encodePacked(assignRolesTxForMultiSend, allowTargetTxForMultiSend, scopeAllowFunctionTxForMultiSend);
    }

    function getTxForMultiSend(bytes memory data) private pure returns(bytes memory txForMultiSend) {
        uint8 operation = uint8(0);
        address to = address(roles);
        uint256 value = 0;
        uint256 dataLength = data.length;
        txForMultiSend = abi.encodePacked(operation, to, value, dataLength, data);
    }

    function getAssignRolesCalldata() private pure returns(bytes memory assignRolesCalldata) {
        address module = address(pilotSafe);
        uint16[] memory _roles = new uint16[](1);
        _roles[0] = ROLE;
        bool[] memory memberOf = new bool[](1);
        memberOf[0] = true;
        assignRolesCalldata = abi.encodeWithSelector(
            Roles.assignRoles.selector, module, _roles, memberOf
        );
    }

    function getAllowTargetCalldata() private view returns(bytes memory allowTargetCalldata) {
        uint16 role = ROLE;
        address targetAddress = address(p2pEth2Depositor);
        Roles.ExecutionOptions options = Roles.ExecutionOptions.Send;

        allowTargetCalldata = abi.encodeWithSelector(
            Roles.allowTarget.selector, role, targetAddress, options
        );
    }

    function getScopeAllowFunctionCalldata() private view returns(bytes memory scopeAllowFunctionCalldata) {
        uint16 role = ROLE;
        address targetAddress = address(p2pEth2Depositor);
        bytes4 functionSig = P2pEth2Depositor.deposit.selector;
        Roles.ExecutionOptions options = Roles.ExecutionOptions.None;

        scopeAllowFunctionCalldata = abi.encodeWithSelector(
            Roles.scopeAllowFunction.selector, role, targetAddress, functionSig, options
        );
    }
}
