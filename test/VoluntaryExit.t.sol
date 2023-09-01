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
import "../src/P2pMessageSender.sol";

contract VoluntaryExit is Test {
    uint16 constant ROLE = 2;
    MultiSendCallOnly constant multiSendCallOnly = MultiSendCallOnly(0x40A2aCCbd92BCA938b02010E17A5b8929b49130D);

    TimelockController constant ensTimelockController = TimelockController(0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7); // ensSafe owner
    GnosisSafe constant ensSafe = GnosisSafe(0x4F2083f5fBede34C2714aFfb3105539775f7FE64); // roles owner
    Roles constant roles = Roles(0xf20325cf84b72e8BBF8D8984B8f0059B984B390B);
    address constant pilotSafeOwner1 = 0x07cD090220f96EA84F4d22aA68be4877EA286a9E;
    address constant pilotSafeOwner2 = 0x38243c6a32B5e31EA546e3116988EC8100AEA531;
    address constant pilotSafeOwner3 = 0x62497dedbe514fFBA23F3FC8AD976FbAEE439E4f;
    address constant pilotSafeOwner4 = 0xeC8fdF488806DFa8F88cb52e0e5833700F25A245;
    GnosisSafe constant pilotSafe = GnosisSafe(0xb423e0f6E7430fa29500c5cC9bd83D28c8BD8978);
    P2pMessageSender constant p2pMessageSender = P2pMessageSender(0x4E1224f513048e18e7a1883985B45dc0Fe1D917e);

    function setUp() public {
        vm.createSelectFork("mainnet");
    }

    function test_VoluntaryExit() public {
        allowPilotToSendMessage();
        sendExitMessage();
    }

    function sendExitMessage() private {
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

    function getExecTransactionWithRoleCalldata() private pure returns(bytes memory execTransactionWithRoleCalldata) {
        address to = address(p2pMessageSender);
        uint256 value = 0;
        bytes memory data = getExitMessageCalldata();
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

    function getExitMessageCalldata() private pure returns(bytes memory exitCalldata) {
        string memory text = "{\"action\":\"withdraw\",\"pubkeys\":[\"0x889856edb78ebcd7773d41dd18cf1344cba272dd9fecd6b2e1ec83d833243829b47b4863f43cb89dfb7423b1c13b16bc\"]}";
        exitCalldata = abi.encodeWithSelector(
            P2pMessageSender.send.selector, text
        );
    }

    function allowPilotToSendMessage() private {
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

    function getTxsForMultiCall() private pure returns(bytes memory txsForMultCall) {
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

    function getAllowTargetCalldata() private pure returns(bytes memory allowTargetCalldata) {
        uint16 role = ROLE;
        address targetAddress = address(p2pMessageSender);
        Roles.ExecutionOptions options = Roles.ExecutionOptions.Send;

        allowTargetCalldata = abi.encodeWithSelector(
            Roles.allowTarget.selector, role, targetAddress, options
        );
    }

    function getScopeAllowFunctionCalldata() private pure returns(bytes memory scopeAllowFunctionCalldata) {
        uint16 role = ROLE;
        address targetAddress = address(p2pMessageSender);
        bytes4 functionSig = P2pMessageSender.send.selector;
        Roles.ExecutionOptions options = Roles.ExecutionOptions.None;

        scopeAllowFunctionCalldata = abi.encodeWithSelector(
            Roles.scopeAllowFunction.selector, role, targetAddress, functionSig, options
        );
    }
}
