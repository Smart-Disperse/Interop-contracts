// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IL2ToL2CrossDomainMessenger} from "@contracts-bedrock/L2/interfaces/IL2ToL2CrossDomainMessenger.sol";
import {ISuperchainERC20} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainERC20.sol";
import {Predeploys} from "@contracts-bedrock/libraries/Predeploys.sol";
import {ISuperchainTokenBridge} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainTokenBridge.sol";

error CallerNotL2ToL2CrossDomainMessenger();
error InvalidCrossDomainSender();
error InvalidAmount();
error TransferFailed();

/// @notice Structure to hold transfer details
struct TransferMessage {
    address[] recipients;
    uint256[] amounts;
    address tokenAddress;
    uint256 totalAmount;
}

contract SmartDisperse {
    event TokensSent(uint256 indexed fromChainId, uint256 indexed toChainId, uint256 totalAmount);
    event TokensReceived(uint256 indexed fromChainId, uint256 indexed toChainId, uint256 totalAmount);

    IL2ToL2CrossDomainMessenger internal messenger = IL2ToL2CrossDomainMessenger(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);

    modifier onlyCrossDomainCallback() {
        if (msg.sender != address(messenger)) revert CallerNotL2ToL2CrossDomainMessenger();
        if (messenger.crossDomainMessageSender() != address(this)) revert InvalidCrossDomainSender();
        _;
    }

    /**
     * @notice Transfers tokens to multiple recipients on another chain
     * @param _toChainId The destination chain ID
     * @param _recipients Array of recipient addresses
     * @param _amounts Array of amounts for each recipient
     * @param _token Address of the ERC20 token
     */
    function transferTokensTo(
        uint256 _toChainId,
        address[] calldata _recipients,
        uint256[] calldata _amounts,
        address _token
    ) external {
        require(_recipients.length == _amounts.length, "Arrays length mismatch");
        
        uint256 totalAmount = 0; bool success = SafeCall.call(target, msg.value, message);

        if (!success) {
            revert TargetCallFailed();
        }

        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }


        // Transfer tokens from sender to this contract
        bool success = ISuperchainERC20(_token).transferFrom(msg.sender, address(this), totalAmount);
        if (!success) revert TransferFailed();

        ISuperchainTokenBridge(Predeploys.SUPERCHAIN_TOKEN_BRIDGE).sendERC20(
            Predeploys.SUPERCHAIN_WETH,
            address(this),
            totalAmount,
            _toChainId
        );

        // Create transfer message
        TransferMessage memory message = TransferMessage({
            recipients: _recipients,
            amounts: _amounts,
            tokenAddress: _token,
            totalAmount: totalAmount
        });

        // Send message to destination chain
        messenger.sendMessage(
            _toChainId,
            address(this),
            abi.encodeCall(this.receiveTokens, (message))
        );
        
        emit TokensSent(block.chainid, _toChainId, totalAmount);
    }

    /**
     * @notice Receives tokens and distributes them to recipients
     * @dev Only callable by the L2ToL2CrossDomainMessenger
     * @param _message The transfer message containing recipients and amounts
     */
    function receiveTokens(TransferMessage memory _message) external onlyCrossDomainCallback {
        uint256 verifyTotal = 0;
        // Distribute tokens to all recipients
        for (uint256 i = 0; i < _message.recipients.length; i++) {
            verifyTotal += _message.amounts[i];
            bool success = ISuperchainERC20(_message.tokenAddress).transfer(_message.recipients[i], _message.amounts[i]);
            if (!success) revert TransferFailed();
        }

        // require(verifyTotal <= address(this).balance, "Insufficient WETH minted");


        // Verify total amount matches
        if (verifyTotal != _message.totalAmount) revert InvalidAmount();

        emit TokensReceived(
            messenger.crossDomainMessageSource(),
            block.chainid,
            _message.totalAmount
        );
    }

    receive() external payable {
        // Handle direct Ether transfers
    }

    // Triggered for calls to non-existing functions or with extra data
    fallback() external payable {
        // Handle unexpected calls or transfers
    }
}