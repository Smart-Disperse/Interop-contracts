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
    SmartDisperse disperse901;
    SmartDisperse disperse902;

    uint256 op1Fork;
    uint256 op2Fork;

    uint256 fromChainId = 901;
    uint256 toChainId = 902;

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
        op1Fork = vm.createSelectFork(vm.envString("OP1_RPC"));
        
        disperse901 = new SmartDisperse{salt: "SmartDisperse"}();

        op2Fork = vm.createSelectFork(vm.envString("OP2_RPC"));
        disperse902 = new SmartDisperse{salt: "SmartDisperse"}();
    }

    function testCrossChainDisperseNative_Success() public {
        
        vm.chainId(fromChainId);
        vm.selectFork(op1Fork);
        uint256 totalAmount =  3 ether;

        uint256 beforeBalance = deployer.balance;

        // Expect the event
        vm.expectEmit(true, true, false, true);
        emit SmartDisperse.NativeTokensSent(block.chainid, toChainId, totalAmount);
        // Call transferTokensTo
        disperse901.crossChainDisperseNative{value: totalAmount}(
            toChainId,
            recipients,
            amounts,
            address(superchainWETH)
        );
    }

    function testReceiveTokens_Success() public{
        vm.chainId(902);
        vm.selectFork(op2Fork);
        vm.stopPrank();
        vm.startPrank(Predeploys.SUPERCHAIN_TOKEN_BRIDGE);
        uint256 totalAmount = 3 ether;
        address superchainTokenBridge = Predeploys.SUPERCHAIN_TOKEN_BRIDGE;
        superchainWETH.crosschainMint(address(disperse902), totalAmount);

        address messenger = Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER;
        vm.startPrank(messenger);

        // to set the CrossDomainMessageSender in L2toL2CrossDomainMessenger Contract
        _mockAndExpect(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeWithSelector(
                IL2ToL2CrossDomainMessenger.crossDomainMessageSender.selector
            ),
            abi.encode(address(disperse901))
        );

        // to set the Destination ChainId as CrossDomainMessageSource in L2toL2CrossDomainMessenger Contract
        _mockAndExpect(
            messenger,
            abi.encodeWithSelector(
                IL2ToL2CrossDomainMessenger.crossDomainMessageSource.selector
            ),
            abi.encode(901)
        );

        disperse902.receiveTokens(
            SmartDisperse.TransferMessage({
                recipients: recipients,
                amounts: amounts,
                tokenAddress: address(superchainWETH),
                totalAmount: totalAmount
            })
        );

        console.log(
            "WETH balance on chain 902: ",
            ISuperchainWETH(SUPERCHAIN_WETH_TOKEN).balanceOf(
                address(disperse902)
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
    
    function testDisperseNative_InvalidArrayLength() public {
        uint256[] memory invalidAmounts = new uint256[](1);
        invalidAmounts[0] = 1 ether;
        
        vm.expectRevert(InvalidArrayLength.selector);
        disperse901.disperseNative{value: 1 ether}(recipients, invalidAmounts);
    }
    
    function testDisperseNative_InsufficientValue() public {
        vm.expectRevert(InvalidAmount.selector);
        disperse901.disperseNative{value: 1 ether}(recipients, amounts); // Total needed is 3 ether
    }
    
    function testDisperseERC20_InvalidArrayLength() public {
        uint256[] memory invalidAmounts = new uint256[](1);
        invalidAmounts[0] = 1 ether;
        
        vm.expectRevert(InvalidArrayLength.selector);
        disperse901.disperseERC20(recipients, invalidAmounts, address(superchainWETH));
    }
    
    function testCrossChainDisperseNative_InvalidArrayLength() public {
        uint256[] memory invalidAmounts = new uint256[](1);
        invalidAmounts[0] = 1 ether;
        
        vm.expectRevert(InvalidArrayLength.selector);
        disperse901.crossChainDisperseNative{value: 1 ether}(
            toChainId,
            recipients,
            invalidAmounts,
            address(superchainWETH)
        );
    }
    
    function testCrossChainDisperseNative_InsufficientValue() public {
        vm.expectRevert(InvalidAmount.selector);
        disperse901.crossChainDisperseNative{value: 1 ether}(
            toChainId,
            recipients,
            amounts,
            address(superchainWETH)
        );
    }
    
    function testCrossChainDisperseERC20_InvalidArrayLength() public {
        uint256[] memory invalidAmounts = new uint256[](1);
        invalidAmounts[0] = 1 ether;
        
        vm.expectRevert(InvalidArrayLength.selector);
        disperse901.crossChainDisperseERC20(
            toChainId,
            recipients,
            invalidAmounts,
            address(superchainWETH)
        );
    }
    
    function testReceiveTokens_InvalidMessenger() public {
        vm.stopPrank();
        vm.chainId(902);
        vm.selectFork(op2Fork);
        
        vm.startPrank(address(0x123)); // Random address that's not the messenger
        
        SmartDisperse.TransferMessage memory message = SmartDisperse.TransferMessage({
            recipients: recipients,
            amounts: amounts,
            tokenAddress: address(superchainWETH),
            totalAmount: 3 ether
        });
        
        vm.expectRevert(CallerNotL2ToL2CrossDomainMessenger.selector);
        disperse902.receiveTokens(message);
    }
    
    function testReceiveTokens_InvalidSender() public {
        vm.stopPrank();
        vm.chainId(902);
        vm.selectFork(op2Fork);
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
        disperse902.receiveTokens(message);
    }
    
    function testDisperseNative_EmptyArrays() public {
        address[] memory emptyRecipients = new address[](0);
        uint256[] memory emptyAmounts = new uint256[](0);
        
        // Should execute successfully with empty arrays
        disperse901.disperseNative{value: 0}(emptyRecipients, emptyAmounts);
    }
    
    function testDisperseNative_RefundExcessValue() public {
        uint256 excessAmount = 1 ether;
        uint256 totalAmount = 3 ether;
        uint256 initialBalance = deployer.balance;
        
        disperse901.disperseNative{value: totalAmount + excessAmount}(recipients, amounts);
        
        assertEq(
            deployer.balance,
            initialBalance - totalAmount,
            "Excess value not refunded correctly"
        );
    }
}
