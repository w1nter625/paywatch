// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @notice Destination-chain board that records large-transfer alerts.
/// @dev Lives on the destination chain (live demo: Ethereum Sepolia).
///      Only the Reactive callback proxy may call
///      `recordAlert`, and only on behalf of the authorized reactive contract.
contract AlertBoard {
    address public immutable callbackProxy;
    address public immutable reactive;

    uint256 public alertCount;

    struct Alert {
        address wallet;
        address counterparty;
        address token;
        uint256 amount;
        bool incoming;
        uint256 originChainId;
        uint256 originTxHash;
        uint256 recordedAt;
    }

    mapping(uint256 => Alert) public alerts;

    event AlertRecorded(
        uint256 indexed id,
        address indexed wallet,
        address indexed token,
        uint256 amount,
        bool incoming,
        uint256 originTxHash
    );

    error NotProxy();
    error NotReactive();
    error ZeroAddress();

    constructor(address callbackProxy_, address reactive_) payable {
        if (callbackProxy_ == address(0) || reactive_ == address(0)) revert ZeroAddress();
        callbackProxy = callbackProxy_;
        reactive = reactive_;
    }

    /// @notice Called by the Reactive callback proxy.
    /// @dev The proxy overwrites the first address argument with the reactive
    ///      contract that requested the callback, regardless of the payload.
    function recordAlert(
        address reactive_,
        address wallet_,
        address counterparty_,
        address token_,
        uint256 amount_,
        bool incoming_,
        uint256 originChainId_,
        uint256 originTxHash_
    ) external {
        if (msg.sender != callbackProxy) revert NotProxy();
        if (reactive_ != reactive) revert NotReactive();

        uint256 id = ++alertCount;
        alerts[id] = Alert({
            wallet: wallet_,
            counterparty: counterparty_,
            token: token_,
            amount: amount_,
            incoming: incoming_,
            originChainId: originChainId_,
            originTxHash: originTxHash_,
            recordedAt: block.timestamp
        });

        emit AlertRecorded(id, wallet_, token_, amount_, incoming_, originTxHash_);
    }

    receive() external payable {}
}
