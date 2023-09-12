// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.19;

import { IERC721Receiver } from 'openzeppelin-contracts/interfaces/IERC721Receiver.sol';

interface NounsTokenMinimal {
    function delegate(address delegatee) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

contract NounVesting is IERC721Receiver {
    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *   ERRORS
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    error OnlySenderOrRecipient();
    error OnlyRecipient();
    error OnlySender();
    error NotAcceptingNFTs();
    error OnlyNounsToken();
    error InsufficientETH();
    error VestingNotDone();

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *   EVENTS
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    event NounReceived(address operator, address from, uint256 tokenId, bytes data);
    event NounsBought(address transferTo, uint256[] tokenIds, uint256 ethReceived);
    event ETHWithdrawn(address to, uint256 amount, bool sent);
    event StoppedAcceptingNFTs();

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
    bool public acceptingNFTs;
    uint256[] public receivedNFTs;

    modifier onlySenderOrRecipient() {
        if (msg.sender != sender && msg.sender != recipient) {
            revert OnlySenderOrRecipient();
        }
        _;
    }

    constructor(
        NounsTokenMinimal nounsToken_,
        address sender_,
        address recipient_,
        uint256 vestingEndTimestamp_,
        uint256 pricePerToken_,
        address delegate_
    ) {
        nounsToken = nounsToken_;
        sender = sender_;
        recipient = recipient_;
        vestingEndTimestamp = vestingEndTimestamp_;
        pricePerToken = pricePerToken_;
        acceptingNFTs = true;

        if (delegate_ != address(0)) {
            nounsToken_.delegate(delegate_);
        }
    }

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *   PUBLIC/EXTERNAL
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        if (!acceptingNFTs) revert NotAcceptingNFTs();
        if (msg.sender != address(nounsToken)) revert OnlyNounsToken();

        receivedNFTs.push(tokenId);

        emit NounReceived(operator, from, tokenId, data);

        return this.onERC721Received.selector;
    }

    function delegate(address to) external {
        address recipient_ = recipient;
        if (msg.sender != recipient_) revert OnlyRecipient();

        nounsToken.delegate(to);
    }

    /***
     * @dev Not allowing recipient to select specific tokenIds to buy because it complicates the code a lot.
     * No need to protect from repeat buys because after the first buy all the tokens are transferred.
     */
    function buy(address transferTo) external payable {
        address recipient_ = recipient;
        NounsTokenMinimal nounsToken_ = nounsToken;
        uint256[] memory receivedNFTs_ = receivedNFTs;

        if (msg.sender != recipient_) revert OnlyRecipient();
        if (block.timestamp < vestingEndTimestamp) revert VestingNotDone();
        uint256 expectedETH = receivedNFTs_.length * pricePerToken;
        if (msg.value < expectedETH) revert InsufficientETH();

        for (uint256 i = 0; i < receivedNFTs_.length; i++) {
            nounsToken_.safeTransferFrom(address(this), transferTo, receivedNFTs_[i]);
        }

        emit NounsBought(transferTo, receivedNFTs_, msg.value);
    }

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *   ADMIN FUNCTIONS
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    function withdrawETH(address to) external {
        if (msg.sender != sender) revert OnlySender();

        uint256 value = address(this).balance;
        (bool sent, ) = to.call{ value: value }('');

        emit ETHWithdrawn(to, value, sent);
    }

    function stopAcceptingNFTs() external onlySenderOrRecipient {
        acceptingNFTs = false;

        emit StoppedAcceptingNFTs();
    }
}
