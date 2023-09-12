// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.19;

import { Clones } from "openzeppelin-contracts/proxy/Clones.sol";
import { NounVesting } from "./NounVesting.sol";

contract NounVestingFactory {
    using Clones for address;

    event VestingCreated(
        address indexed msgSender,
        address indexed sender,
        address indexed recipient,
        uint256 vestingEndTimestamp,
        uint256 claimExpirationTimestamp,
        uint256 pricePerToken,
        address ethRecipient,
        address delegate,
        address instance
    );

    address public immutable implementation;

    constructor(address implementation_) {
        implementation = implementation_;
    }

    function createVesting(
        address sender,
        address recipient,
        uint256 vestingEndTimestamp,
        uint256 claimExpirationTimestamp,
        uint256 pricePerToken,
        address ethRecipient,
        address delegate
    ) external returns (address) {
        address instance = implementation.cloneDeterministic(
            salt(
                msg.sender,
                sender,
                recipient,
                vestingEndTimestamp,
                claimExpirationTimestamp,
                pricePerToken,
                ethRecipient,
                delegate
            )
        );

        NounVesting nv = NounVesting(instance);
        nv.initialize(
            sender, recipient, vestingEndTimestamp, claimExpirationTimestamp, pricePerToken, ethRecipient, delegate
        );

        emit VestingCreated(
            msg.sender,
            sender,
            recipient,
            vestingEndTimestamp,
            claimExpirationTimestamp,
            pricePerToken,
            ethRecipient,
            delegate,
            instance
        );

        return instance;
    }

    function salt(
        address msgSender,
        address sender,
        address recipient,
        uint256 vestingEndTimestamp,
        uint256 claimExpirationTimestamp,
        uint256 pricePerToken,
        address ethRecipient,
        address delegate
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                msgSender,
                sender,
                recipient,
                vestingEndTimestamp,
                claimExpirationTimestamp,
                pricePerToken,
                ethRecipient,
                delegate
            )
        );
    }
}
