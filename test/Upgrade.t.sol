// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import { NounVesting, NounsTokenMinimal } from "../src/NounVesting.sol";
import { NounVestingFactory } from "../src/NounVestingFactory.sol";
import { NounVestingBeacon } from "../src/NounVestingBeacon.sol";
import { ERC1967Proxy } from "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract NounsTokenMock is NounsTokenMinimal {
    function delegate(address delegatee) public { }
}

contract NounVestingV2 is NounVesting {
    constructor(NounsTokenMinimal nounsToken_) NounVesting(nounsToken_) { }

    function v2Function() public pure returns (bool) {
        return true;
    }
}

contract UpgradeTest is Test {
    address owner = makeAddr("owner");
    NounsTokenMock nounsTokenMock;
    NounVestingBeacon beacon;
    NounVesting vestingImpl;
    NounVestingFactory factoryImpl;
    NounVestingFactory factoryProxy;

    address recipient1 = makeAddr("recipient1");
    address recipient2 = makeAddr("recipient2");
    uint256 vestingEnd;
    uint256 pricePerToken = 0.0001 ether;

    function setUp() public {
        nounsTokenMock = new NounsTokenMock();
        vestingImpl = new NounVesting(nounsTokenMock);
        beacon = new NounVestingBeacon(owner, address(vestingImpl));

        assertEq(beacon.implementation(), address(vestingImpl));

        factoryImpl = new NounVestingFactory();
        factoryProxy = NounVestingFactory(address(new ERC1967Proxy(address(factoryImpl), '')));
        factoryProxy.initialize(owner, address(beacon));

        vestingEnd = block.timestamp + 365 days;
    }

    function test_deployTwoVestingClones_upgradeImpl_testBothUpgraded() public {
        // deploy two different vesting contracts
        address predictAddress1 =
            factoryProxy.predictAddress(address(this), owner, recipient1, vestingEnd, pricePerToken, owner, recipient1);
        address vesting1 =
            factoryProxy.createVesting(owner, recipient1, vestingEnd, pricePerToken, owner, recipient1, predictAddress1);

        address predictAddress2 =
            factoryProxy.predictAddress(address(this), owner, recipient2, vestingEnd, pricePerToken, owner, recipient2);
        address vesting2 =
            factoryProxy.createVesting(owner, recipient2, vestingEnd, pricePerToken, owner, recipient2, predictAddress2);

        // sanity test that vesting 1 and 2 are different
        assertEq(NounVesting(vesting1).recipient(), recipient1);
        assertEq(NounVesting(vesting2).recipient(), recipient2);

        // showing current impl doesn't have the v2Function
        vm.expectRevert();
        NounVestingV2(vesting1).v2Function();
        vm.expectRevert();
        NounVestingV2(vesting2).v2Function();

        // upgrade via beacon
        vm.startPrank(owner);
        beacon.upgradeTo(address(new NounVestingV2(nounsTokenMock)));
        vm.stopPrank();

        // show that both vesting instances have the new function
        assertTrue(NounVestingV2(vesting1).v2Function());
        assertTrue(NounVestingV2(vesting2).v2Function());
    }
}
