// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IL2ToL2CrossDomainMessenger} from "@contracts-bedrock/L2/interfaces/IL2ToL2CrossDomainMessenger.sol";
import {ISuperchainERC20} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainERC20.sol";
import {ISuperchainWETH} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainWETH.sol";
import {Predeploys} from "@contracts-bedrock/libraries/Predeploys.sol";
import {ISuperchainTokenBridge} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainTokenBridge.sol";
import {ReentrancyGuard} from "optimism/packages/contracts-bedrock/lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";


// Custom error definitions for better gas efficiency
error CallerNotL2ToL2CrossDomainMessenger();
error InvalidCrossDomainSender();
error InvalidAmount();
error TransferFailed();
error InvalidArrayLength();


contract SmartDisperse is ReentrancyGuard {

    /// @notice Structure to hold transfer details for cross-chain token distribution
    struct TransferMessage {
        address[] recipients; // Addresses of the recipients
        uint256[] amounts;    // Amounts to be sent to each recipient
        address tokenAddress;  // Address of the token being transferred
        uint256 totalAmount;   // Total amount of tokens to be distributed
    }

    struct CrossChainTransfer {
        uint256 chainId;
        address[] recipients;
        uint256[] amounts;
    }

    /*******************************     EVENTS      ***********************************/

    event NativeTokensSent(
        uint256 indexed fromChainId,
        uint256 indexed toChainId,
        uint256 totalAmount
    );

    event ERC20TokensSent(
        uint256 indexed fromChainId,
        uint256 indexed toChainId,
        uint256 totalAmount
    );

    event TokensReceived(
        uint256 indexed fromChainId,
        uint256 indexed toChainId,
        uint256 totalAmount
    );

    event NativeTokensDispersed(
        address indexed sender,
        address[] indexed recipients,
        uint256[] values
    );

    event TokensDispersed(
        address indexed sender,
        address[] indexed recipients,
        uint256[] values,
        address token
    );

    IL2ToL2CrossDomainMessenger internal messenger =
        IL2ToL2CrossDomainMessenger(Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER);

    /*******************************     MODIFIERS      ***********************************/

    modifier onlyCrossDomainCallback() {
        if (msg.sender != address(messenger))
            revert CallerNotL2ToL2CrossDomainMessenger();
        if (messenger.crossDomainMessageSender() != address(this))
            revert InvalidCrossDomainSender();
        _;
    }

    /*******************************     SAME-CHAIN TRANSFER FUNCTIONS      ******************************/

    /**
     * @notice Transfers Native tokens (ETH) to multiple recipients on the same chain
     * @param _recipients The array of addresses to receive the native tokens
     * @param _amounts The corresponding amounts of native tokens to transfer to each recipient
     */
    function disperseNative(
        address[] memory _recipients,
        uint256[] memory _amounts
    ) external payable nonReentrant {
        if(_recipients.length != _amounts.length) revert InvalidArrayLength();

        uint256 requiredAmount = 0;

        for (uint256 i = 0; i < _amounts.length; i++) {
            requiredAmount += _amounts[i];
        }

        if(msg.value < requiredAmount) revert InvalidAmount();

        // Refund any excess ETH
        uint256 refund = msg.value - requiredAmount;
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }

        for (uint256 i = 0; i < _recipients.length; i++) {
            (bool success, ) = _recipients[i].call{value: _amounts[i]}("");
            require(success, "Transfer failed to recipient");
        }

        emit NativeTokensDispersed(msg.sender, _recipients, _amounts);
    }

    /**
     * @notice Transfers ISuperchainERC20 tokens to multiple recipients on the same chain
     * @param _recipients The array of addresses to receive the tokens
     * @param _amounts The corresponding amounts of tokens to transfer to each recipient
     * @param token The address of the token to be transferred
     */
    function disperseERC20(
        address[] memory _recipients,
        uint256[] memory _amounts,
        address token
    ) external nonReentrant {
        if(_recipients.length != _amounts.length) revert InvalidArrayLength();

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }

        bool success = ISuperchainERC20(token).transferFrom(
            msg.sender,
            address(this),
            totalAmount
        );
        require(success, "TransferFrom failed");

        for (uint256 i = 0; i < _recipients.length; i++) {
            success = ISuperchainERC20(token).transfer(
                _recipients[i],
                _amounts[i]
            );
            require(
                success,
                string(
                    abi.encodePacked(
                        "Transfer failed for address: ",
                        _recipients[i]
                    )
                )
            );
        }
        emit TokensDispersed(msg.sender, _recipients, _amounts, token);
    }

    /*******************************    CROSS-CHAIN TRANSFER FUNCTIONS      ***********************************/

    /**
     * @notice Transfers Native tokens to multiple recipients on another chain
     * @param _toChainId The destination chain ID
     * @param _recipients Array of recipient addresses
     * @param _amounts Array of amounts for each recipient
     * @param _token Address of the ERC20 token
     */
    function crossChainDisperseNative(
        uint256 _toChainId,
        address[] calldata _recipients,
        uint256[] calldata _amounts,
        address _token
    ) external payable {
        if(_recipients.length != _amounts.length) revert InvalidArrayLength();

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }

        if(msg.value < totalAmount) revert InvalidAmount();

        // Wrap ETH to WETH
        ISuperchainWETH(payable(Predeploys.SUPERCHAIN_WETH)).deposit{value: totalAmount}();

        // Send the Token to the bridge for cross-chain transfer
        ISuperchainTokenBridge(Predeploys.SUPERCHAIN_TOKEN_BRIDGE).sendERC20(
            _token,
            address(this),
            totalAmount,
            _toChainId
        );

        // Create transfer message for recipients
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

        // Refund any excess ETH
        uint256 refund = msg.value - totalAmount;
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }
        
        emit NativeTokensSent(block.chainid, _toChainId, totalAmount);
    }

    /**
     * @notice Transfers SuperchainERC20 tokens to multiple recipients on another chain
     * @param _toChainId The destination chain ID
     * @param _recipients Array of recipient addresses
     * @param _amounts Array of amounts for each recipient
     * @param _token Address of the ERC20 token
     */
    function crossChainDisperseERC20(
        uint256 _toChainId,
        address[] calldata _recipients,
        uint256[] calldata _amounts,
        address _token
    ) external {
        if(_recipients.length != _amounts.length) revert InvalidArrayLength();

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }

        // Transfer tokens from sender to this contract
        bool success = ISuperchainERC20(_token).transferFrom(
            msg.sender,
            address(this),
            totalAmount
        );
        require(success, "TransferFrom failed");

        // Send the Token to the bridge for cross-chain transfer
        ISuperchainTokenBridge(Predeploys.SUPERCHAIN_TOKEN_BRIDGE).sendERC20(
            _token,
            address(this),
            totalAmount,
            _toChainId
        );

        // Create transfer message for recipients
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

        

        emit ERC20TokensSent(block.chainid, _toChainId, totalAmount);
    }

    function crossChainDisperseNativeMultiChain(
        CrossChainTransfer[] calldata transfers,
        address _token
    ) external payable {
        uint256 totalAmount = _validateAndCalculateTotal(transfers);
        
        if (msg.value < totalAmount) revert InvalidAmount();
        
        ISuperchainWETH(payable(Predeploys.SUPERCHAIN_WETH)).deposit{value: totalAmount}();
        
        for (uint256 i = 0; i < transfers.length; i++) {
            _processTransfer(transfers[i], _token);
        }
        
        uint256 refund = msg.value - totalAmount;
        if (refund > 0) {
            payable(msg.sender).transfer(refund);
        }
    }

    function _validateAndCalculateTotal(
        CrossChainTransfer[] calldata transfers
    ) internal pure returns (uint256 totalAmount) {
        for (uint256 i = 0; i < transfers.length; i++) {
            if (transfers[i].recipients.length != transfers[i].amounts.length)
                revert InvalidArrayLength();
            
            for (uint256 j = 0; j < transfers[i].amounts.length; j++) {
                totalAmount += transfers[i].amounts[j];
            }
        }
    }

    function _processTransfer(
        CrossChainTransfer calldata transfer,
        address _token
    ) internal {
        uint256 chainTotal = 0;
        for (uint256 j = 0; j < transfer.amounts.length; j++) {
            chainTotal += transfer.amounts[j];
        }
        
        ISuperchainTokenBridge(Predeploys.SUPERCHAIN_TOKEN_BRIDGE).sendERC20(
            _token,
            address(this),
            chainTotal,
            transfer.chainId
        );
        
        TransferMessage memory message = TransferMessage({
            recipients: transfer.recipients,
            amounts: transfer.amounts,
            tokenAddress: _token,
            totalAmount: chainTotal
        });
        
        messenger.sendMessage(
            transfer.chainId,
            address(this),
            abi.encodeCall(this.receiveTokens, (message))
        );
        
        emit NativeTokensSent(block.chainid, transfer.chainId, chainTotal);
    }


    /*******************************     DESTINATION CHAIN EXECUTION      ***********************************/

    /**
     * @notice Receives tokens and distributes them to recipients
     * @dev Only callable by the L2ToL2CrossDomainMessenger
     * @param _message The transfer message containing recipients and amounts
     */
    function receiveTokens(
        TransferMessage memory _message
    ) external onlyCrossDomainCallback {
        uint256 verifyTotal = 0;

        // Distribute tokens to all recipients
        for (uint256 i = 0; i < _message.recipients.length; i++) {
            verifyTotal += _message.amounts[i];
            bool success = ISuperchainERC20(_message.tokenAddress).transfer(
                _message.recipients[i],
                _message.amounts[i]
            );
            require(success, "Transfer failed");
        }

        // Verify total amount matches the expected total require(verifyTotal == _message.totalAmount, "Invalid amount");

        emit TokensReceived(
            messenger.crossDomainMessageSource(),
            block.chainid,
            _message.totalAmount
        );
    }

    /*******************************     WITHDRAW FUNCTIONS      ***********************************/
    // :TODO

}