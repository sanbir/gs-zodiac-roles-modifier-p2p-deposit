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

//    TimelockController constant ensTimelockController = TimelockController(0xFe89cc7aBB2C4183683ab71653C4cdc9B02D44b7); // ensSafe owner
//    GnosisSafe constant ensSafe = GnosisSafe(0x4F2083f5fBede34C2714aFfb3105539775f7FE64); // roles owner
//    Roles constant roles = Roles(0xf20325cf84b72e8BBF8D8984B8f0059B984B390B);
//    GnosisSafe constant pilotSafe = GnosisSafe(0xb423e0f6E7430fa29500c5cC9bd83D28c8BD8978);

    TimelockController constant ensTimelockController = TimelockController(0x77777776dD9e859b22c029ab230E94779F83A541); // ensSafe owner
    GnosisSafe constant ensSafe = GnosisSafe(0x14d91faAca6a7aa4C1ac371C15425eAc5A75dADB); // roles owner
    Roles constant roles = Roles(0xa8824FE7760a06E2587C86b33640C981b5E31e0D);
    GnosisSafe constant pilotSafe = GnosisSafe(0x32795D2374A047e1B8591463cDB8E5B34c6dd89D);
    P2pEth2Depositor p2pEth2Depositor = P2pEth2Depositor(0x2E0743aAAB3118945564b715598B7DF10e083dC1);

    function setUp() public {
        // vm.createSelectFork("mainnet");
        vm.createSelectFork("goerli", 9594710);
    }

    function test_Deposit() public {
        string memory version = ensSafe.VERSION();
        console.log(version);

        vm.startPrank(address(ensTimelockController));

        bytes memory assignRolesCalldata = getAssignRolesCalldata();
        console.logBytes(assignRolesCalldata);

        bytes memory allowTargetCalldata = getAllowTargetCalldata();
        console.logBytes(allowTargetCalldata);

        bytes memory scopeAllowFunctionCalldata = getScopeAllowFunctionCalldata();
        console.logBytes(scopeAllowFunctionCalldata);
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
