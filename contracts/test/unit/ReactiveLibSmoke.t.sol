// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {AbstractReactive} from "@reactive/src/base/AbstractReactive.sol";
import {AbstractPayer} from "@reactive/src/base/AbstractPayer.sol";

/// @notice Minimal reactive contract. It only proves that reactive-lib-omni compiles with the pinned toolchain and
///         that `onlySystem` guards `react()`. It is not AlarmReactive and is never deployed.
contract MinimalReactive is AbstractReactive {
    uint256 public reactCount;

    function react(LogRecord calldata) external onlySystem {
        reactCount++;
    }
}

contract ReactiveLibSmokeTest is Test {
    address private constant SYSTEM_CONTRACT = 0x8888888888888888888888888888888888888888;

    MinimalReactive private reactive;

    function setUp() public {
        reactive = new MinimalReactive();
    }

    function test_serviceProvider_isSystemContract() public view {
        assertEq(address(reactive._SERVICE_PROVIDER()), SYSTEM_CONTRACT);
    }

    function test_react_acceptsSystemContract() public {
        MinimalReactive.LogRecord memory log;
        vm.prank(SYSTEM_CONTRACT);
        reactive.react(log);
        assertEq(reactive.reactCount(), 1);
    }

    function test_react_rejectsOtherCallers() public {
        MinimalReactive.LogRecord memory log;
        address stranger = makeAddr("stranger");
        vm.expectRevert(abi.encodeWithSelector(AbstractPayer.NotAuthorized.selector, stranger, SYSTEM_CONTRACT));
        vm.prank(stranger);
        reactive.react(log);
    }
}
