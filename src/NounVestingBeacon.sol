// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.19;

import { UpgradeableBeacon } from "openzeppelin-contracts/proxy/beacon/UpgradeableBeacon.sol";

contract NounVestingBeacon is UpgradeableBeacon {
    constructor(address owner_, address implementation_) UpgradeableBeacon(implementation_) {
        _transferOwnership(owner_);
    }
}
