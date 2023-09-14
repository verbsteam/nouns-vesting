// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.19;

import { IERC721Receiver } from "openzeppelin-contracts/interfaces/IERC721Receiver.sol";
import { IERC721 } from "openzeppelin-contracts/interfaces/IERC721.sol";
import { Initializable } from "openzeppelin-contracts/proxy/utils/Initializable.sol";

interface NounsTokenMinimal {
    function delegate(address delegatee) external;
}

contract NounVesting is IERC721Receiver, Initializable {
    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *   ERRORS
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    error OnlyRecipient();
    error OnlySender();
    error InsufficientETH();
    error VestingNotDone();
    error TokensBelongToRecipientNow();
    error OnlyPendingRecipient();

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *   EVENTS
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    event NFTReceived(address nft, address operator, address from, uint256 tokenId, bytes data);
    event NFTsBought(
        address transferTo,
        address nft,
        uint256[] tokenIds,
        uint256 ethReceived,
        address ethRecipient,
        bool ethSentToRecipient
    );
    event ETHWithdrawn(address to, uint256 amount, bool sent);
    event PendingRecipientSet(address pendingRecipient);
    event RecipientSet(address oldRecipient, address newRecipient);

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *   STATE
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    NounsTokenMinimal public nounsToken;
    address public sender;
    address public recipient;
    uint256 public vestingEndTimestamp;
    uint256 public pricePerToken;
    address public ethRecipient;
    address public pendingRecipient;

    function initialize(
        address sender_,
        address recipient_,
        uint256 vestingEndTimestamp_,
        uint256 pricePerToken_,
        address ethRecipient_,
        address delegate_
    ) external initializer {
        sender = sender_;
        recipient = recipient_;
        vestingEndTimestamp = vestingEndTimestamp_;
        pricePerToken = pricePerToken_;
        ethRecipient = ethRecipient_;

        if (delegate_ != address(0)) {
            nounsToken.delegate(delegate_);
        }
    }

    constructor(NounsTokenMinimal nounsToken_) {
        nounsToken = nounsToken_;

        _disableInitializers();
    }

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *   PUBLIC/EXTERNAL
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        emit NFTReceived(msg.sender, operator, from, tokenId, data);
        return this.onERC721Received.selector;
    }

    function delegate(address to) external {
        if (msg.sender != recipient) revert OnlyRecipient();

        nounsToken.delegate(to);
    }

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *   RECIPIENT FUNCTIONS
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    /**
     *
     * @dev Not allowing recipient to select specific tokenIds to buy because it complicates the code a lot.
     * No need to protect from repeat buys because after the first buy all the tokens are transferred.
     */
    function buyNFTs(address nft, uint256[] calldata tokenIds, address transferTo) external payable {
        address recipient_ = recipient;

        if (tokenIds.length == 0) revert();
        if (msg.sender != recipient_) revert OnlyRecipient();
        if (block.timestamp <= vestingEndTimestamp) revert VestingNotDone();
        uint256 expectedETH = tokenIds.length * pricePerToken;
        if (msg.value < expectedETH) revert InsufficientETH();

        for (uint256 i = 0; i < tokenIds.length; i++) {
            IERC721(nft).transferFrom(address(this), transferTo, tokenIds[i]);
        }

        address ethRecipient_ = ethRecipient;
        uint256 value = address(this).balance;
        (bool sent,) = ethRecipient_.call{ value: value }("");

        emit NFTsBought(transferTo, nft, tokenIds, msg.value, ethRecipient_, sent);
    }

    function setPendingRecipient(address pendingRecipient_) external {
        if (msg.sender != recipient) revert OnlyRecipient();

        pendingRecipient = pendingRecipient_;

        emit PendingRecipientSet(pendingRecipient_);
    }

    function acceptRecipient() external {
        address oldRecipient = recipient;
        address newRecipient = pendingRecipient;

        if (msg.sender != newRecipient) revert OnlyPendingRecipient();

        recipient = newRecipient;
        pendingRecipient = address(0);

        emit RecipientSet(oldRecipient, newRecipient);
    }

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *   SENDER FUNCTIONS
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    function withdrawNFTs(address nft, uint256[] calldata tokenIds, address to) external {
        if (msg.sender != sender) revert OnlySender();
        if (block.timestamp > vestingEndTimestamp) revert TokensBelongToRecipientNow();

        for (uint256 i = 0; i < tokenIds.length; i++) {
            IERC721(nft).transferFrom(address(this), to, tokenIds[i]);
        }
    }

    /**
     *
     * @dev A safety function in case the ETH auto sending fails.
     */
    function withdrawETH(address to) external {
        if (msg.sender != sender) revert OnlySender();

        uint256 value = address(this).balance;
        (bool sent,) = to.call{ value: value }("");

        emit ETHWithdrawn(to, value, sent);
    }
}
