// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {ISystemContract} from "../contracts/ISystemContract.sol";
import {MockUSD} from "../contracts/MockUSD.sol";
import {AlertBoard} from "../contracts/AlertBoard.sol";
import {PayWatchReactive} from "../contracts/PayWatchReactive.sol";

contract MockSystem {
    event Subscribed(uint256 chainId, address contractAddress, uint256 topic0);
    event CallbackRequested(uint256 chainId, address recipient, uint64 gasLimit, bytes payload);

    uint256 public subscribeCount;
    uint256 public callbackCount;
    ISystemContract.CallbackConfiguration_V_1_0 public lastCallback;

    function subscribe(
        uint256 chainId,
        address contractAddress,
        uint256 topic0,
        uint256,
        uint256,
        uint256
    ) external {
        subscribeCount += 1;
        emit Subscribed(chainId, contractAddress, topic0);
    }

    function requestCallbackV_1_0(ISystemContract.CallbackConfiguration_V_1_0 memory config) external {
        callbackCount += 1;
        lastCallback = config;
        emit CallbackRequested(config.chainId, config.recipient, config.gasLimit, config.payload);
    }

    function lastRecipient() external view returns (address) {
        return lastCallback.recipient;
    }

    function lastChainId() external view returns (uint256) {
        return lastCallback.chainId;
    }
}

/// @notice Stands in for the Base Sepolia callback proxy in unit tests.
contract MockProxy {
    function deliverRecordAlert(
        AlertBoard board,
        address reactive_,
        address wallet_,
        address counterparty_,
        address token_,
        uint256 amount_,
        bool incoming_,
        uint256 originChainId_,
        uint256 originTxHash_
    ) external {
        board.recordAlert(
            reactive_, wallet_, counterparty_, token_, amount_, incoming_, originChainId_, originTxHash_
        );
    }
}

contract PayWatchTest is Test {
    address internal constant SYSTEM_ADDR = 0x8888888888888888888888888888888888888888;
    uint256 internal constant BASE_SEPOLIA = 84532;
    uint256 internal constant THRESHOLD = 100e6; // 100 pUSD (6 decimals)

    MockSystem internal system;
    MockUSD internal token;
    MockProxy internal proxy;
    PayWatchReactive internal watch;
    AlertBoard internal board;

    address internal owner = makeAddr("owner");
    address internal watched = makeAddr("watched");
    address internal other = makeAddr("other");
    address internal stranger = makeAddr("stranger");

    function setUp() public {
        system = new MockSystem();
        vm.etch(SYSTEM_ADDR, address(system).code);
        // etch copies code but not storage; the mock is stateless enough.
        // We talk to the etched address through the MockSystem interface.
        system = MockSystem(SYSTEM_ADDR);

        token = new MockUSD();
        proxy = new MockProxy();

        vm.deal(owner, 1 ether);
        vm.prank(owner);
        watch = new PayWatchReactive{value: 0.1 ether}(BASE_SEPOLIA, address(token), watched, THRESHOLD);

        board = new AlertBoard(address(proxy), address(watch));

        vm.prank(owner);
        watch.setBoard(address(board));
    }

    function _log(
        address from_,
        address to_,
        uint256 amount,
        uint256 txHash
    ) internal view returns (ISystemContract.LogRecord memory log_) {
        log_.chainId = BASE_SEPOLIA;
        log_.contractAddress = address(token);
        log_.topic0 = watch.TRANSFER_TOPIC0();
        log_.topic1 = uint256(uint160(from_));
        log_.topic2 = uint256(uint160(to_));
        log_.data = abi.encode(amount);
        log_.txHash = txHash;
    }

    function test_constructorSubscribes() public view {
        assertEq(system.subscribeCount(), 1);
        assertEq(watch.originChainId(), BASE_SEPOLIA);
        assertEq(watch.token(), address(token));
        assertEq(watch.watchedWallet(), watched);
        assertEq(watch.threshold(), THRESHOLD);
        assertEq(watch.board(), address(board));
    }

    function test_reactIncomingAboveThresholdRequestsCallback() public {
        ISystemContract.LogRecord memory log_ = _log(other, watched, 250e6, 0xabc);
        vm.prank(SYSTEM_ADDR);
        watch.react(log_);

        assertEq(watch.fireCount(), 1);
        assertEq(system.callbackCount(), 1);
        assertEq(system.lastRecipient(), address(board));
        assertEq(system.lastChainId(), BASE_SEPOLIA);
    }

    function test_reactOutgoingAboveThresholdRequestsCallback() public {
        ISystemContract.LogRecord memory log_ = _log(watched, other, 100e6, 0xdef);
        vm.prank(SYSTEM_ADDR);
        watch.react(log_);
        assertEq(watch.fireCount(), 1);
        assertEq(system.callbackCount(), 1);
    }

    function test_belowThresholdIgnored() public {
        ISystemContract.LogRecord memory log_ = _log(other, watched, 99e6, 1);
        vm.prank(SYSTEM_ADDR);
        watch.react(log_);
        assertEq(watch.fireCount(), 0);
        assertEq(system.callbackCount(), 0);
    }

    function test_unrelatedWalletIgnored() public {
        ISystemContract.LogRecord memory log_ = _log(other, stranger, 1_000e6, 2);
        vm.prank(SYSTEM_ADDR);
        watch.react(log_);
        assertEq(watch.fireCount(), 0);
    }

    function test_wrongTokenIgnored() public {
        ISystemContract.LogRecord memory log_ = _log(other, watched, 1_000e6, 3);
        log_.contractAddress = address(0xBEEF);
        vm.prank(SYSTEM_ADDR);
        watch.react(log_);
        assertEq(watch.fireCount(), 0);
    }

    function test_cooldownSuppressesSecondFire() public {
        ISystemContract.LogRecord memory first = _log(other, watched, 100e6, 4);
        ISystemContract.LogRecord memory second = _log(other, watched, 200e6, 5);
        vm.prank(SYSTEM_ADDR);
        watch.react(first);
        vm.prank(SYSTEM_ADDR);
        watch.react(second);
        assertEq(watch.fireCount(), 1);

        vm.warp(block.timestamp + 60);
        vm.prank(SYSTEM_ADDR);
        watch.react(second);
        assertEq(watch.fireCount(), 2);
    }

    function test_reactOnlySystem() public {
        ISystemContract.LogRecord memory log_ = _log(other, watched, 100e6, 6);
        vm.prank(stranger);
        vm.expectRevert(PayWatchReactive.OnlySystem.selector);
        watch.react(log_);
    }

    function test_setBoardOnlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert(PayWatchReactive.OnlyOwner.selector);
        watch.setBoard(address(0x1));
    }

    function test_noCallbackUntilBoardSet() public {
        vm.prank(owner);
        PayWatchReactive bare =
            new PayWatchReactive(BASE_SEPOLIA, address(token), watched, THRESHOLD);
        ISystemContract.LogRecord memory log_ = _log(other, watched, 100e6, 7);
        uint256 before_ = system.callbackCount();
        vm.prank(SYSTEM_ADDR);
        bare.react(log_);
        assertEq(system.callbackCount(), before_);
        assertEq(bare.fireCount(), 0);
    }

    function test_alertBoardRecordsFromProxy() public {
        proxy.deliverRecordAlert(
            board, address(watch), watched, other, address(token), 250e6, true, BASE_SEPOLIA, 0xabc
        );
        assertEq(board.alertCount(), 1);
        (address wallet,,,,, uint256 originChainId, uint256 originTxHash,) = board.alerts(1);
        assertEq(wallet, watched);
        assertEq(originChainId, BASE_SEPOLIA);
        assertEq(originTxHash, 0xabc);
    }

    function test_alertBoardRejectsNonProxy() public {
        vm.prank(stranger);
        vm.expectRevert(AlertBoard.NotProxy.selector);
        board.recordAlert(address(watch), watched, other, address(token), 1, true, BASE_SEPOLIA, 1);
    }

    function test_alertBoardRejectsWrongReactive() public {
        vm.expectRevert(AlertBoard.NotReactive.selector);
        proxy.deliverRecordAlert(
            board, address(0xBAD), watched, other, address(token), 1, true, BASE_SEPOLIA, 1
        );
    }

    function test_callbackGasLimitCoversSepoliaStorage() public view {
        // 2026 Sepolia cold SSTORE is ~110k; recordAlert needs ~887k after
        // proxy overhead, so 1_000_000 is not enough. See CALLBACK_GAS_LIMIT.
        assertGe(watch.CALLBACK_GAS_LIMIT(), 2_500_000);
    }

    function test_mockUsdTransferEmitsAndMovesBalance() public {
        token.mint(watched, 500e6);
        vm.prank(watched);
        token.transfer(other, 80e6);
        assertEq(token.balanceOf(watched), 420e6);
        assertEq(token.balanceOf(other), 80e6);
    }
}
