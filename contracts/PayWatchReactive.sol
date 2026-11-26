// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {ISystemContract} from "./ISystemContract.sol";

/// @notice Lasna reactive contract: if a watched wallet's ERC-20 Transfer is
///         at or above a threshold, request a callback that records it on
///         AlertBoard (destination chain, live demo: Ethereum Sepolia).
/// @dev "Set It and Forget It" track. The useful automation is a personal
///      large-movement watchdog you can leave running. Demo origin is MockUSD;
///      the same subscriber works against any ERC-20 Transfer log, including
///      testnet USDC, by passing a different token address.
contract PayWatchReactive {
    ISystemContract internal constant SYSTEM =
        ISystemContract(payable(0x8888888888888888888888888888888888888888));

    /// @dev Reactive wildcard ("any topic"). Same value as official docs / Omni demos.
    uint256 public constant REACTIVE_IGNORE =
        0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;

    /// @dev keccak256("Transfer(address,address,uint256)")
    uint256 public constant TRANSFER_TOPIC0 =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    /// @dev Must cover destination `recordAlert` after the callback proxy
    ///      withholds `_extraGas` (150k) + `_maxChargeGas` (50k) and keeps a
    ///      further slice for settlement. On 2026 Sepolia a cold SSTORE is
    ///      ~110k gas, so writing AlertBoard's 8-field struct plus `alertCount`
    ///      costs ~887k. A 1_000_000 gasLimit only forwards ~745k and OOGs,
    ///      which the proxy reports as CallbackFailure. 2_500_000 forwards
    ///      roughly 1.86M, enough with margin. Official examples use 1M or
    ///      500k; live Omni requests on Lasna also use up to 3M.
    uint64 public constant CALLBACK_GAS_LIMIT = 2_500_000;

    address public immutable owner;
    uint256 public immutable originChainId;
    address public immutable token;
    address public immutable watchedWallet; // address(0) = any wallet on this token
    uint256 public immutable threshold;

    address public board;
    uint256 public cooldown = 60; // seconds; timestamps, not block counts
    mapping(address => uint256) public lastAlertAt;
    uint256 public fireCount;

    event Subscribed(uint256 indexed chainId, address indexed token, uint256 indexed topic0);
    event BoardUpdated(address indexed board);
    event CooldownUpdated(uint256 seconds_);
    event ThresholdHit(
        address indexed wallet,
        address indexed counterparty,
        uint256 amount,
        bool incoming,
        uint256 originTxHash
    );

    error OnlyOwner();
    error OnlySystem();
    error ZeroAddress();
    error ZeroThreshold();
    error ZeroChain();

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    constructor(uint256 originChainId_, address token_, address watchedWallet_, uint256 threshold_)
        payable
    {
        if (originChainId_ == 0) revert ZeroChain();
        if (token_ == address(0)) revert ZeroAddress();
        if (threshold_ == 0) revert ZeroThreshold();

        owner = msg.sender;
        originChainId = originChainId_;
        token = token_;
        watchedWallet = watchedWallet_;
        threshold = threshold_;

        SYSTEM.subscribe(
            originChainId_,
            token_,
            TRANSFER_TOPIC0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        emit Subscribed(originChainId_, token_, TRANSFER_TOPIC0);
    }

    /// @notice Attach AlertBoard after it is deployed (reactive contract is deployed first).
    function setBoard(address board_) external onlyOwner {
        if (board_ == address(0)) revert ZeroAddress();
        board = board_;
        emit BoardUpdated(board_);
    }

    function setCooldown(uint256 seconds_) external onlyOwner {
        cooldown = seconds_;
        emit CooldownUpdated(seconds_);
    }

    /// @notice Called by the Reactive system for each subscribed Transfer log.
    function react(ISystemContract.LogRecord calldata log_) external {
        if (msg.sender != address(SYSTEM)) revert OnlySystem();
        if (log_.topic0 != TRANSFER_TOPIC0 || log_.contractAddress != token) return;
        if (log_.chainId != originChainId) return;

        address from_ = _asAddress(log_.topic1);
        address to_ = _asAddress(log_.topic2);
        uint256 amount = log_.data.length >= 32 ? abi.decode(log_.data, (uint256)) : 0;
        if (amount < threshold) return;

        bool incoming;
        address wallet;
        address counterparty;
        if (watchedWallet == address(0)) {
            // Unfiltered token watch: attribute the alert to the recipient.
            incoming = true;
            wallet = to_;
            counterparty = from_;
        } else if (to_ == watchedWallet) {
            incoming = true;
            wallet = watchedWallet;
            counterparty = from_;
        } else if (from_ == watchedWallet) {
            incoming = false;
            wallet = watchedWallet;
            counterparty = to_;
        } else {
            return;
        }

        address dest = board;
        if (dest == address(0)) return;
        if (lastAlertAt[wallet] != 0 && block.timestamp < lastAlertAt[wallet] + cooldown) return;

        lastAlertAt[wallet] = block.timestamp;
        fireCount += 1;
        emit ThresholdHit(wallet, counterparty, amount, incoming, log_.txHash);

        bytes memory payload = abi.encodeWithSignature(
            "recordAlert(address,address,address,address,uint256,bool,uint256,uint256)",
            address(0),
            wallet,
            counterparty,
            token,
            amount,
            incoming,
            log_.chainId,
            log_.txHash
        );

        SYSTEM.requestCallbackV_1_0(
            ISystemContract.CallbackConfiguration_V_1_0({
                chainId: originChainId,
                recipient: dest,
                gasLimit: CALLBACK_GAS_LIMIT,
                payload: payload
            })
        );
    }

    /// @notice Reactive fees are collected by the system contract through this hook.
    function pay(uint256 amount) external {
        if (msg.sender != address(SYSTEM)) revert OnlySystem();
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        require(ok, "pay failed");
    }

    receive() external payable {}

    function _asAddress(uint256 topic) private pure returns (address) {
        return address(uint160(topic));
    }
}
