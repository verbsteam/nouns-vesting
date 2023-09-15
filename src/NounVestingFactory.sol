// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.19;

import { NounVesting } from "./NounVesting.sol";
import { OwnableUpgradeable } from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import { BeaconProxy } from "openzeppelin-contracts/proxy/beacon/BeaconProxy.sol";
import { UUPSUpgradeable } from "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import { Create2 } from "openzeppelin-contracts/utils/Create2.sol";

contract NounVestingFactory is OwnableUpgradeable, UUPSUpgradeable {
    error UnexpectedVestingAddress();

    event VestingCreated(
        address indexed msgSender,
        address indexed sender,
        address indexed recipient,
        uint256 vestingEndTimestamp,
        uint256 pricePerToken,
        address ethRecipient,
        address delegate,
        address instance
    );

    address beacon;

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_, address beacon_) public initializer {
        _transferOwnership(owner_);
        beacon = beacon_;
    }

    function createVesting(
        address sender,
        address recipient,
        uint256 vestingEndTimestamp,
        uint256 pricePerToken,
        address ethRecipient,
        address delegate,
        address predictedAddress
    ) external returns (address) {
        address instance = Create2.deploy(
            0,
            salt(msg.sender, sender, recipient, vestingEndTimestamp, pricePerToken, ethRecipient, delegate),
            getCreationBytecode(
                address(beacon),
                abi.encodeWithSelector(
                    NounVesting.initialize.selector,
                    sender,
                    recipient,
                    vestingEndTimestamp,
                    pricePerToken,
                    ethRecipient,
                    delegate
                )
            )
        );

        if (instance != predictedAddress) revert UnexpectedVestingAddress();

        emit VestingCreated(
            msg.sender, sender, recipient, vestingEndTimestamp, pricePerToken, ethRecipient, delegate, instance
        );

        return address(instance);
    }

    function getCreationBytecode(address beacon_, bytes memory data) public pure returns (bytes memory) {
        bytes memory bytecode = type(BeaconProxy).creationCode;
        return abi.encodePacked(bytecode, abi.encode(beacon_, data));
    }

    function predictAddress(
        address msgSender,
        address sender,
        address recipient,
        uint256 vestingEndTimestamp,
        uint256 pricePerToken,
        address ethRecipient,
        address delegate
    ) public view returns (address) {
        return Create2.computeAddress(
            salt(msgSender, sender, recipient, vestingEndTimestamp, pricePerToken, ethRecipient, delegate),
            keccak256(
                getCreationBytecode(
                    address(beacon),
                    abi.encodeWithSelector(
                        NounVesting.initialize.selector,
                        sender,
                        recipient,
                        vestingEndTimestamp,
                        pricePerToken,
                        ethRecipient,
                        delegate
                    )
                )
            ),
            address(this)
        );
    }

    function salt(
        address msgSender,
        address sender,
        address recipient,
        uint256 vestingEndTimestamp,
        uint256 pricePerToken,
        address ethRecipient,
        address delegate
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(msgSender, sender, recipient, vestingEndTimestamp, pricePerToken, ethRecipient, delegate)
        );
    }

    /**
     * @dev Reverts when `msg.sender` is not the owner of this contract; in the case of Noun DAOs it should be the
     * DAO's treasury contract.
     */
    function _authorizeUpgrade(address) internal view override onlyOwner { }
}
