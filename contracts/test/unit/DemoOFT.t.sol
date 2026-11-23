// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {SendParam, MessagingFee} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

import {DemoOFT} from "../../src/demo/DemoOFT.sol";

/// @notice Checks that DemoOFT compiles with the pinned toolchain and moves tokens between two mocked LayerZero
///         endpoints. Mocked endpoints only: this is not evidence of testnet delivery (that is gate G2).
contract DemoOFTTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 private constant EID_A = 1;
    uint32 private constant EID_B = 2;
    uint256 private constant INITIAL_SUPPLY = 1_000 ether;
    uint128 private constant LZ_RECEIVE_GAS = 200_000;

    DemoOFT private tokenA;
    DemoOFT private tokenB;

    address private owner = makeAddr("owner");
    address private holder = makeAddr("holder");

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        tokenA = DemoOFT(
            _deployOApp(
                type(DemoOFT).creationCode,
                abi.encode("Demo OFT", "DEMO", address(endpoints[EID_A]), address(this), INITIAL_SUPPLY)
            )
        );
        tokenB = DemoOFT(
            _deployOApp(
                type(DemoOFT).creationCode, abi.encode("Demo OFT", "DEMO", address(endpoints[EID_B]), address(this), 0)
            )
        );

        address[] memory oapps = new address[](2);
        oapps[0] = address(tokenA);
        oapps[1] = address(tokenB);
        this.wireOApps(oapps);

        tokenA.transferOwnership(owner);
        tokenB.transferOwnership(owner);
    }

    function test_constructor_mintsInitialSupplyToOwner() public view {
        assertEq(tokenA.totalSupply(), INITIAL_SUPPLY);
        assertEq(tokenA.balanceOf(address(this)), INITIAL_SUPPLY);
        assertEq(tokenB.totalSupply(), 0);
    }

    function test_peers_areWiredBothWays() public view {
        assertEq(tokenA.peers(EID_B), addressToBytes32(address(tokenB)));
        assertEq(tokenB.peers(EID_A), addressToBytes32(address(tokenA)));
    }

    function test_send_movesTokensFromAToB() public {
        uint256 amount = 10 ether;
        assertTrue(tokenA.transfer(holder, amount));

        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(LZ_RECEIVE_GAS, 0);
        SendParam memory sendParam = SendParam(EID_B, addressToBytes32(holder), amount, amount, options, "", "");
        MessagingFee memory fee = tokenA.quoteSend(sendParam, false);

        vm.deal(holder, fee.nativeFee);
        vm.prank(holder);
        tokenA.send{value: fee.nativeFee}(sendParam, fee, payable(holder));
        verifyPackets(EID_B, addressToBytes32(address(tokenB)));

        assertEq(tokenA.balanceOf(holder), 0);
        assertEq(tokenB.balanceOf(holder), amount);
        assertEq(tokenA.totalSupply(), INITIAL_SUPPLY - amount);
        assertEq(tokenB.totalSupply(), amount);
    }
}
