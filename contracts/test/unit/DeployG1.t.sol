// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {DeployG1Reactive} from "../../script/DeployG1Reactive.s.sol";
import {DeployG1Receiver} from "../../script/DeployG1Receiver.s.sol";
import {G1Reactive} from "../../src/gates/G1Reactive.sol";
import {G1Receiver} from "../../src/gates/G1Receiver.sol";

contract DeployG1Test is Test {
    uint256 internal constant LASNA = 5318007;
    uint256 internal constant BASE_SEPOLIA = 84532;
    address internal constant PROXY = 0x476F44b11F5C942c58f4c8E3d0300E5710743585;

    function test_reactive_deploysOnLasna() public {
        vm.chainId(LASNA);
        G1Reactive reactive = new DeployG1Reactive().run();
        assertTrue(address(reactive).code.length > 0);
    }

    function test_reactive_revertsOffLasna() public {
        vm.chainId(BASE_SEPOLIA);
        DeployG1Reactive script = new DeployG1Reactive();
        vm.expectRevert(abi.encodeWithSelector(DeployG1Reactive.NotLasna.selector, BASE_SEPOLIA));
        script.run();
    }

    function test_receiver_bindsProxyAndReactive() public {
        vm.chainId(BASE_SEPOLIA);
        vm.etch(PROXY, hex"00");
        address reactive = makeAddr("g1Reactive");
        vm.setEnv("G1_REACTIVE", vm.toString(reactive));

        G1Receiver receiver = new DeployG1Receiver().run();

        assertEq(address(receiver._SERVICE_PROVIDER()), PROXY);
        assertEq(receiver._CALLBACK_SENDER(), reactive);
    }

    function test_receiver_revertsOffBaseSepolia() public {
        vm.chainId(LASNA);
        DeployG1Receiver script = new DeployG1Receiver();
        vm.expectRevert(abi.encodeWithSelector(DeployG1Receiver.NotBaseSepolia.selector, LASNA));
        script.run();
    }

    function test_receiver_revertsWhenProxyHasNoCode() public {
        vm.chainId(BASE_SEPOLIA);
        DeployG1Receiver script = new DeployG1Receiver();
        vm.expectRevert(abi.encodeWithSelector(DeployG1Receiver.ProxyMissing.selector, PROXY));
        script.run();
    }
}
