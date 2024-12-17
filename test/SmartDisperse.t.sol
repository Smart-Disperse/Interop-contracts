// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SmartDisperse} from "../src/SmartDisperse.sol";
import {IL2ToL2CrossDomainMessenger} from "@contracts-bedrock/L2/interfaces/IL2ToL2CrossDomainMessenger.sol";
import {ISuperchainERC20} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainERC20.sol";
import {ISuperchainTokenBridge} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainTokenBridge.sol";
import { ISuperchainWETH } from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainWETH.sol";

import {Predeploys} from "@contracts-bedrock/libraries/Predeploys.sol";

contract SmartDisperseTest is Test {

    address public deployer;
    address public crossDomainMessenger = Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER;

    uint256 public toChainId = 902; // OPChainB
    address payable constant SUPERCHAIN_WETH_TOKEN = payable(0x4200000000000000000000000000000000000024);
    
    // Test addresses (replace with actual addresses)
    address[] recipients = [
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];
    uint256[] amounts = [1 ether, 2 ether];

    // Deploy or set the real Superchain WETH contract
    ISuperchainERC20 superchainWETH = ISuperchainERC20(Predeploys.SUPERCHAIN_WETH);
    SmartDisperse disperse901;
    SmartDisperse disperse902;

    uint256 op1Fork;
    uint256 op2Fork;

    function setUp() public {
        deployer = vm.addr(1);
        vm.startPrank(deployer);

        
        // Ensure the deployer has enough tokens
        uint256 initialBalance = 100 ether;
        op1Fork = vm.createSelectFork(vm.envString("OP1_RPC"));
        disperse901 = new SmartDisperse{salt: "SmartDisperse"}();

        (bool success, ) = SUPERCHAIN_WETH_TOKEN.call{value: 10 ether}("");
        require(success, "WETH minting failed!");
        uint256 userBalanceOfWETH = ISuperchainWETH(SUPERCHAIN_WETH_TOKEN).balanceOf(deployer);
        console2.log("WETH balance on chain 901 ", userBalanceOfWETH);


        op2Fork = vm.createSelectFork(vm.envString("OP2_RPC"));
        disperse902 = new SmartDisperse{salt: "SmartDisperse"}();

        
        vm.stopPrank();
    }


    function testTransferTokensTo() public {

        uint256 totalAmount = 3 ether;

        vm.startPrank(deployer);
        vm.selectFork(op1Fork);

        // Ensure the deployer has approved the smart contract to transfer tokens
        superchainWETH.approve(address(disperse901), totalAmount);

        // Perform the actual transfer of tokens
        disperse901.transferTokensTo(toChainId, recipients, amounts, address(superchainWETH));

        vm.stopPrank();
    }

    function testReceiveTokens() public {

        uint256 totalAmount = 3 ether;

        vm.selectFork(op1Fork);
        vm.startPrank(deployer);
        SmartDisperse.TransferMessage memory message = SmartDisperse.TransferMessage({
            recipients: recipients,
            amounts: amounts,
            tokenAddress: address(superchainWETH),
            totalAmount: totalAmount
        });

        vm.stopPrank();
        
        vm.selectFork(op2Fork);
        vm.startPrank(crossDomainMessenger);
        disperse902.receiveTokens(message);
        vm.stopPrank();
    }

    function testInvalidAmountsInReceiveTokens() public {

        uint256 totalAmount = 3 ether; // Mismatched totalAmount

        vm.selectFork(op1Fork);
        vm.startPrank(deployer);

        SmartDisperse.TransferMessage memory message = SmartDisperse.TransferMessage({
            recipients: recipients,
            amounts: amounts,
            tokenAddress: address(superchainWETH),
            totalAmount: totalAmount
        });

        vm.selectFork(op2Fork);

        vm.startPrank(crossDomainMessenger);
        vm.expectRevert("InvalidAmount()");
        disperse902.receiveTokens(message);
        vm.stopPrank();
    }

    // function testMismatchedArrayLengths() public {
    //     address[2] memory recipients = [
    //         0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
    //         0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    //     ];
    //     uint256[1] memory amounts = [1 ether];

    //     vm.startPrank(deployer);
    //     vm.expectRevert(SmartDisperse.InvalidArrayLengths.selector);
    //     smartDisperse.transferTokensTo(toChainId, recipients, amounts, address(superchainWETH));
    //     vm.stopPrank();
    // }

    // function testTokenTransferFailure() public {
    //     address[2] memory recipients = [
    //         0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
    //         0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    //     ];
    //     uint256[2] memory amounts = [1 ether, 2 ether];

    //     uint256 totalAmount = 3 ether;

    //     vm.startPrank(deployer);

    //     // Ensure the deployer has approved the smart contract to transfer tokens
    //     superchainWETH.approve(address(smartDisperse), totalAmount);

    //     // Simulate failure in token transfer
    //     vm.expectRevert(SmartDisperse.TransferFailed.selector);
    //     smartDisperse.transferTokensTo(toChainId, recipients, amounts, address(superchainWETH));

    //     vm.stopPrank();
    // }
}
