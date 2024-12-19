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

contract SmartDisperseTest is Test {
    
    SmartDisperse smartDisperse;
    address public crossDomainMessenger = Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER;
    address payable constant SUPERCHAIN_WETH_TOKEN = payable(0x4200000000000000000000000000000000000024);

    address[] recipients = [
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    ];
    uint256[] amounts = [1 ether, 2 ether];

    ISuperchainERC20 superchainWETH = ISuperchainERC20(Predeploys.SUPERCHAIN_WETH);

    function _mockAndExpect(
        address _receiver,
        bytes memory _calldata,
        bytes memory _returned
    ) internal {
        vm.mockCall(_receiver, _calldata, _returned);
        vm.expectCall(_receiver, _calldata);
    }

    function setUp() public {
        vm.startPrank(vm.addr(0));

        ISuperchainWETH(SUPERCHAIN_WETH_TOKEN).deposit{value: 10 ether}();
        uint256 userBalanceOfWETH = ISuperchainWETH(SUPERCHAIN_WETH_TOKEN)
            .balanceOf(deployer);
        console2.log("WETH balance on chain 901 ", userBalanceOfWETH);

        op2Fork = vm.createSelectFork(vm.envString("OP2_RPC"));
        disperse902 = new SmartDisperse{salt: "SmartDisperse"}();

        vm.stopPrank();
    }

    function testTransferTokensTo_Success() public {
        uint256 totalAmount = 3 ether;
        vm.deal(address(this), 10 ether);

        // Source Chain (Chain 901)
        vm.selectFork(op1Fork);
        vm.startBroadcast(deployer);
        vm.chainId(901);

        // Approve tokens for transfer
        superchainWETH.approve(address(disperse901), totalAmount);
        console.log(
            "Before Balance on 901: ",
            ISuperchainWETH(SUPERCHAIN_WETH_TOKEN).balanceOf(deployer)
        );

        // Call transferTokensTo
        disperse901.transferTokensTo(
            toChainId,
            recipients,
            amounts,
            address(superchainWETH)
        );

        console.log(
            "After Balance on 901: ",
            ISuperchainWETH(SUPERCHAIN_WETH_TOKEN).balanceOf(deployer)
        );
        vm.stopBroadcast();

        // Destination Chain (Chain 902)
        vm.chainId(902);
        vm.selectFork(op2Fork);
        vm.roll(block.number + 1);
        vm.startBroadcast(Predeploys.SUPERCHAIN_TOKEN_BRIDGE);
        // Simulate minting on receiver side using the SuperchainTokenBridge
        address superchainTokenBridge = Predeploys.SUPERCHAIN_TOKEN_BRIDGE;
        superchainWETH.crosschainMint(address(disperse902), totalAmount);
        vm.stopBroadcast();

        // Mock the behavior of L2ToL2CrossDomainMessenger
        address messenger = Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER;
        vm.startPrank(messenger);

        // to set the CrossDomainMessageSender in L2toL2CrossDomainMessenger Contract
        _mockAndExpect(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeWithSelector(
                IL2ToL2CrossDomainMessenger.crossDomainMessageSender.selector
            ),
            abi.encode(address(disperse901)) // Invalid address
        );

        // to set the Destination ChainId as CrossDomainMessageSource in L2toL2CrossDomainMessenger Contract
        _mockAndExpect(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER,
            abi.encodeWithSelector(
                IL2ToL2CrossDomainMessenger.crossDomainMessageSource.selector
            ),
            abi.encode(901)
        );

        // console.log("crossdomainmessagesender:  ", IL2ToL2CrossDomainMessenger(messenger).crossDomainMessageSender());
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

    // function testReceiveTokens() public {

    //     uint256 totalAmount = 3 ether;

    //     vm.selectFork(op1Fork);
    //     // vm.startPrank(deployer);
    //     SmartDisperse.TransferMessage memory message = SmartDisperse.TransferMessage({
    //         recipients: recipients,
    //         amounts: amounts,
    //         tokenAddress: address(superchainWETH),
    //         totalAmount: totalAmount
    //     });

    //     // vm.stopPrank();

    //     vm.selectFork(op2Fork);
    //     vm.startPrank(crossDomainMessenger);
    //     disperse902.receiveTokens(message);
    //     vm.stopPrank();
    // }

    // function testMismatchedArrayLengths() public {
    //     address[2] memory recipients = [
    //         0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
    //         0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
    //     ];
    //     uint256[1] memory amounts = [1 ether];

    //     vm.startPrank(deployer);
    //     vm.expectRevert("Arrays length mismatch");
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
