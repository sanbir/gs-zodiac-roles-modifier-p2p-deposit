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
    P2pEth2Depositor p2pEth2Depositor = P2pEth2Depositor(0x8e76a33f1aFf7EB15DE832810506814aF4789536);

    function setUp() public {
        vm.createSelectFork("mainnet");
        vm.deal(address(ensSafe), 32 ether);
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
        bytes[] memory _pubkeys = new bytes[](1);
        _pubkeys[0] = bytes(hex'889856edb78ebcd7773d41dd18cf1344cba272dd9fecd6b2e1ec83d833243829b47b4863f43cb89dfb7423b1c13b16bc');

        bytes memory _withdrawal_credentials = bytes(hex'0100000000000000000000004f2083f5fbede34c2714affb3105539775f7fe64');

        bytes[] memory _signatures = new bytes[](1);
        _signatures[0] = bytes(hex'b95f9e5bc3773e6fa71481e3df4bee70b571d8bde180634d7b5294e378c4d2f54536c8969b9fc9e2a0f848b0279091d515fa29046c091575758f50428510590ba4555bc600fd911658bf69a726d691318d3a5be7a768a346269c449233664b3a');

        bytes32[] memory _deposit_data_roots = new bytes32[](1);
        _deposit_data_roots[0] = bytes32(hex'db7dc1b147769b8df692e4abc98460e2f72d2e2176e644446e622c432aa61548');

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
