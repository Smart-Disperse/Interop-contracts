// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SmartDisperse} from "../src/SmartDisperse.sol";
import {IL2ToL2CrossDomainMessenger} from "@contracts-bedrock/L2/interfaces/IL2ToL2CrossDomainMessenger.sol";
import {ISuperchainERC20} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainERC20.sol";
import {ISuperchainTokenBridge} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainTokenBridge.sol";
import {ISuperchainWETH} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainWETH.sol";

import {Predeploys} from "@contracts-bedrock/libraries/Predeploys.sol";

error CallerNotL2ToL2CrossDomainMessenger();
error InvalidCrossDomainSender();
error InvalidAmount();
error TransferFailed();
error InvalidArrayLength();

contract SmartDisperseTest is Test {
    
    address public deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
    address public crossDomainMessenger =
        Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER;

    address payable constant SUPERCHAIN_WETH_TOKEN =
        payable(0x4200000000000000000000000000000000000024);

    // Test addresses (replace with actual addresses)
    address[] recipients = [
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];
    uint256[] amounts = [1 ether, 2 ether];

    // Deploy or set the real Superchain WETH contract
    ISuperchainERC20 superchainWETH =
        ISuperchainERC20(Predeploys.SUPERCHAIN_WETH);
    SmartDisperse disperseOP;
    SmartDisperse disperseBase;
    SmartDisperse disperseZora;

    uint256 opFork;
    uint256 baseFork;
    uint256 zoraFork;

    uint256 fromChainId = 10;
    uint256 toChainId = 8453;

    function _mockAndExpect(
        address _receiver,
        bytes memory _calldata,
        bytes memory _returned
    ) internal {
        vm.mockCall(_receiver, _calldata, _returned);
        vm.expectCall(_receiver, _calldata);
    }

    function setUp() public {
        vm.startPrank(deployer);
        opFork = vm.createSelectFork("http://127.0.0.1:9545");
        
        disperseOP = new SmartDisperse{salt: "SmartDisperse"}();

        baseFork = vm.createSelectFork("http://127.0.0.1:9546");
        disperseBase = new SmartDisperse{salt: "SmartDisperse"}();

        zoraFork = vm.createSelectFork("http://127.0.0.1:9547");
        disperseZora = new SmartDisperse{salt: "SmartDisperse"}();
    }

    function testCrossChainDisperseNative_Success() public {
        
        vm.chainId(fromChainId);
        vm.selectFork(opFork);
        uint256 totalAmount =  3 ether;

        uint256 beforeBalance = deployer.balance;
    
        // Expect the event
        vm.expectEmit(true, true, false, true);
        emit SmartDisperse.NativeTokensSent(block.chainid, toChainId, totalAmount);
        // Call transferTokensTo
        disperseOP.crossChainDisperseNative{value: totalAmount}(
            toChainId,
            recipients,
            amounts
        );
    }

    function testReceiveTokens_Success() public{
        vm.chainId(8453);
        vm.selectFork(baseFork);
        vm.stopPrank();
        vm.startPrank(Predeploys.SUPERCHAIN_TOKEN_BRIDGE);
        uint256 totalAmount = 3 ether;
        address superchainTokenBridge = Predeploys.SUPERCHAIN_TOKEN_BRIDGE;
        superchainWETH.crosschainMint(address(disperseBase), totalAmount);

        address messenger = Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER;
        vm.startPrank(messenger);

        // to set the CrossDomainMessageSender in L2toL2CrossDomainMessenger Contract
        _mockAndExpect(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeWithSelector(
                IL2ToL2CrossDomainMessenger.crossDomainMessageSender.selector
            ),
            abi.encode(address(disperseOP))
        );

        // to set the Destination ChainId as CrossDomainMessageSource in L2toL2CrossDomainMessenger Contract
        _mockAndExpect(
            messenger,
            abi.encodeWithSelector(
                IL2ToL2CrossDomainMessenger.crossDomainMessageSource.selector
            ),
            abi.encode(10)
        );

        disperseBase.receiveTokens(
            SmartDisperse.TransferMessage({
                recipients: recipients,
                amounts: amounts,
                tokenAddress: address(superchainWETH),
                totalAmount: totalAmount
            })
        );

        console.log(
            "WETH balance on chain Base: ",
            ISuperchainWETH(SUPERCHAIN_WETH_TOKEN).balanceOf(
                address(disperseBase)
            )
        );

        // Verify recipients' balances
        for (uint256 i = 0; i < recipients.length; i++) {
            assertEq(
                ISuperchainWETH(SUPERCHAIN_WETH_TOKEN).balanceOf(recipients[i]),
                amounts[i],
                "Tokens not dispersed correctly"
            );
        }
        vm.stopPrank();
    }
    
   
    
    function testCrossChainDisperseNative_InvalidArrayLength() public {
        uint256[] memory invalidAmounts = new uint256[](1);
        invalidAmounts[0] = 1 ether;
        
        vm.expectRevert(InvalidArrayLength.selector);
        disperseOP.crossChainDisperseNative{value: 1 ether}(
            toChainId,
            recipients,
            invalidAmounts
        );
    }
    
    function testCrossChainDisperseNative_InsufficientValue() public {
        vm.expectRevert(InvalidAmount.selector);
        disperseOP.crossChainDisperseNative{value: 1 ether}(
            toChainId,
            recipients,
            amounts
        );
    }
    
    function testCrossChainDisperseERC20_InvalidArrayLength() public {
        uint256[] memory invalidAmounts = new uint256[](1);
        invalidAmounts[0] = 1 ether;
        
        vm.expectRevert(InvalidArrayLength.selector);
        disperseOP.crossChainDisperseERC20(
            toChainId,
            recipients,
            invalidAmounts,
            address(superchainWETH)
        );
    }
    
    function testReceiveTokens_InvalidMessenger() public {
        vm.stopPrank();
        vm.chainId(8453);
        vm.selectFork(baseFork);
        
        vm.startPrank(address(0x123)); // Random address that's not the messenger
        
        SmartDisperse.TransferMessage memory message = SmartDisperse.TransferMessage({
            recipients: recipients,
            amounts: amounts,
            tokenAddress: address(superchainWETH),
            totalAmount: 3 ether
        });
        
        vm.expectRevert(CallerNotL2ToL2CrossDomainMessenger.selector);
        disperseBase.receiveTokens(message);
    }
    
    function testReceiveTokens_InvalidSender() public {
        vm.stopPrank();
        vm.chainId(8453);
        vm.selectFork(baseFork);
        vm.startPrank(crossDomainMessenger);
        
        // Mock the crossDomainMessageSender to return an invalid address
        _mockAndExpect(
            crossDomainMessenger,
            abi.encodeWithSelector(
                IL2ToL2CrossDomainMessenger.crossDomainMessageSender.selector
            ),
            abi.encode(address(0x123))
        );
        
        SmartDisperse.TransferMessage memory message = SmartDisperse.TransferMessage({
            recipients: recipients,
            amounts: amounts,
            tokenAddress: address(superchainWETH),
            totalAmount: 3 ether
        });
        
        vm.expectRevert(InvalidCrossDomainSender.selector);
        disperseBase.receiveTokens(message);
    }
    


    function testCrossChainDisperseNativeMultiChain_Success() public {
        vm.chainId(fromChainId);
        vm.selectFork(opFork);

        uint256 initialBalance = deployer.balance;
        uint256 totalAmount = 8 ether;

        // Create CrossChainTransfer array
        SmartDisperse.CrossChainTransfer[] memory transfers = new SmartDisperse.CrossChainTransfer[](2);

        // Base transfer
        transfers[0] = SmartDisperse.CrossChainTransfer({
            chainId: 8453,
            recipients: new address[](2),
            amounts: new uint256[](2) 
        });
        transfers[0].recipients[0] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
        transfers[0].recipients[1] = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
        transfers[0].amounts[0] = 1.5 ether;
        transfers[0].amounts[1] = 2.5 ether;

        // Zora transfer
        transfers[1] = SmartDisperse.CrossChainTransfer({
            chainId: 7777777,
            recipients: new address[](2),
            amounts: new uint256[](2)
        });
        transfers[1].recipients[0] = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
        transfers[1].recipients[1] = 0x976EA74026E726554dB657fA54763abd0C3a0aa9;
        transfers[1].amounts[0] = 1 ether;
        transfers[1].amounts[1] = 3 ether;

        // Mock and expect calls
        for (uint256 i = 0; i < transfers.length; i++) {
            uint256 chainTotal = 0;
            for (uint256 j = 0; j < transfers[i].amounts.length; j++) {
                chainTotal += transfers[i].amounts[j];
            }

            vm.expectCall(
                Predeploys.SUPERCHAIN_TOKEN_BRIDGE,
                abi.encodeWithSelector(
                    ISuperchainTokenBridge.sendERC20.selector,
                    address(superchainWETH),
                    address(disperseOP),
                    chainTotal,
                    transfers[i].chainId
                )
            );
        }
        // Verify event emission
        for (uint256 i = 0; i < transfers.length; i++) {
            uint256 chainTotal = 0;
            for (uint256 j = 0; j < transfers[i].amounts.length; j++) {
                chainTotal += transfers[i].amounts[j];
            }

            vm.expectEmit(true, true, false, true);
            emit SmartDisperse.NativeTokensSent(block.chainid, transfers[i].chainId, chainTotal);
        }

        // Call the function
        disperseOP.crossChainDisperseNativeMultiChain{value: totalAmount}(
            transfers
        );


        // Verify refund of excess amount
        assertEq(
            deployer.balance,
            initialBalance - totalAmount,
            "Excess value not refunded correctly"
        );
    }

    function testCrossChainDisperseNativeMultiChain_InvalidArrayLength() public {
        vm.chainId(fromChainId);
        vm.selectFork(opFork);

        // Create invalid CrossChainTransfer array
        SmartDisperse.CrossChainTransfer[] memory transfers = new SmartDisperse.CrossChainTransfer[](1);
        transfers[0] = SmartDisperse.CrossChainTransfer({
            chainId: 8453,
            recipients: new address[](1), // Mismatch in array lengths
            amounts: new uint256[](2)
        });
        transfers[0].recipients[0] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
        transfers[0].amounts[0] = 1 ether;
        transfers[0].amounts[1] = 2 ether;

        vm.expectRevert(InvalidArrayLength.selector);
        disperseOP.crossChainDisperseNativeMultiChain{value: 3 ether}(
            transfers
        );
    }

    function testCrossChainDisperseNativeMultiChain_InsufficientValue() public {
        vm.chainId(fromChainId);
        vm.selectFork(opFork);

        // Create CrossChainTransfer array
        SmartDisperse.CrossChainTransfer[] memory transfers = new SmartDisperse.CrossChainTransfer[](1);
        transfers[0] = SmartDisperse.CrossChainTransfer({
            chainId: 8453,
            recipients: new address[](2),
            amounts: new uint256[](2)
        });
        transfers[0].recipients[0] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
        transfers[0].recipients[1] = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
        transfers[0].amounts[0] = 1.5 ether;
        transfers[0].amounts[1] = 2.5 ether;

        vm.expectRevert(InvalidAmount.selector);
        disperseOP.crossChainDisperseNativeMultiChain{value: 3 ether}(
            transfers
        );
    }

}
