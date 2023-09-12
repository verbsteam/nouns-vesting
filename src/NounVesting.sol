// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.19;

import { IERC721Receiver } from "openzeppelin-contracts/interfaces/IERC721Receiver.sol";
import { Initializable } from "openzeppelin-contracts/proxy/utils/Initializable.sol";

interface NounsTokenMinimal {
    function delegate(address delegatee) external;

    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

contract NounVesting is IERC721Receiver, Initializable {
    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *   ERRORS
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    error ClaimingPeriodTooShort();
    error OnlySenderOrRecipient();
    error OnlyRecipient();
    error OnlySender();
    error NotAcceptingNFTs();
    error OnlyNounsToken();
    error InsufficientETH();
    error VestingNotDone();
    error ClaimingHasNotExpiredYet();

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *   EVENTS
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    event NounReceived(address operator, address from, uint256 tokenId, bytes data);
    event NounsBought(
        address transferTo,
        uint256[] tokenIds,
        uint256 ethReceived,
        address ethRecipient,
        bool ethSentToRecipient
    );
    event ETHWithdrawn(address to, uint256 amount, bool sent);
    event StoppedAcceptingNFTs();

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *   CONSTANTS
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */
    uint256 public constant MIN_CLAIMING_PERIOD = 30 days;

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *   STATE
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

    NounsTokenMinimal public nounsToken;
    address public sender;
    address public recipient;
    uint256 public vestingEndTimestamp;
    uint256 public claimExpirationTimestamp;
    uint256 public pricePerToken;
    address public ethRecipient;
    bool public acceptingNFTs;
    uint256[] public receivedNFTs;

    modifier onlySenderOrRecipient() {
        if (msg.sender != sender && msg.sender != recipient) {
            revert OnlySenderOrRecipient();
        }
        _;
    }

    function initialize(
        address sender_,
        address recipient_,
        uint256 vestingEndTimestamp_,
        uint256 claimExpirationTimestamp_,
        uint256 pricePerToken_,
        address ethRecipient_,
        address delegate_
    ) external initializer {
        if (claimExpirationTimestamp_ - vestingEndTimestamp_ < MIN_CLAIMING_PERIOD) {
            revert ClaimingPeriodTooShort();
        }

        sender = sender_;
        recipient = recipient_;
        vestingEndTimestamp = vestingEndTimestamp_;
        claimExpirationTimestamp = claimExpirationTimestamp_;
        pricePerToken = pricePerToken_;
        ethRecipient = ethRecipient_;
        acceptingNFTs = true;

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

    /**
     *
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

        address ethRecipient_ = ethRecipient;
        uint256 value = address(this).balance;
        (bool sent,) = ethRecipient_.call{ value: value }("");

        emit NounsBought(transferTo, receivedNFTs_, msg.value, ethRecipient_, sent);
    }

    /**
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     *   ADMIN FUNCTIONS
     * ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
     */

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

    function withdrawNFTs(address to) external {
        if (msg.sender != sender) revert OnlySender();
        if (block.timestamp < claimExpirationTimestamp) revert ClaimingHasNotExpiredYet();

        NounsTokenMinimal nounsToken_ = nounsToken;
        uint256[] memory receivedNFTs_ = receivedNFTs;

        for (uint256 i = 0; i < receivedNFTs_.length; i++) {
            nounsToken_.safeTransferFrom(address(this), to, receivedNFTs_[i]);
        }
    }

    function stopAcceptingNFTs() external onlySenderOrRecipient {
        acceptingNFTs = false;

        emit StoppedAcceptingNFTs();
    }
}
