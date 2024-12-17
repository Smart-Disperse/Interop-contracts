// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// import "forge-std/Test.sol";
// import "forge-std/console.sol";
// import {SmartDisperse} from "../src/SmartDisperse.sol";
// import {IL2ToL2CrossDomainMessenger} from "@contracts-bedrock/L2/interfaces/IL2ToL2CrossDomainMessenger.sol";
// import {ISuperchainERC20} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainERC20.sol";
// import {ISuperchainTokenBridge} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainTokenBridge.sol";
// import {Predeploys} from "@contracts-bedrock/libraries/Predeploys.sol";

// contract SmartDisperseTest is Test {
//     SmartDisperse public smartDisperse;

//     address public deployer;
//     address public recipient1 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
//     address public recipient2 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
//     address public superchainWETH = Predeploys.SUPERCHAIN_WETH;
//     address public crossDomainMessenger = Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER;

//     uint256 public toChainId = 902; // OPChainB

//     function setUp() public {
//         deployer = vm.addr(1);
//         vm.startPrank(deployer);
//         smartDisperse = new SmartDisperse({salt: "SmartDisperse"});
//         vm.stopPrank();
//     }

//     function testTransferTokensTo() public {
//         uint256[] memory amounts = new uint256[](2);
//         amounts[0] = 1 ether;
//         amounts[1] = 2 ether;

//         address[] memory recipients = new address[](2);
//         recipients[0] = recipient1;
//         recipients[1] = recipient2;

//         uint256 totalAmount = 3 ether;

//         // Mock token behavior
//         vm.mockCall(
//             superchainWETH,
//             abi.encodeWithSelector(ISuperchainERC20.transferFrom.selector, deployer, address(smartDisperse), totalAmount),
//             abi.encode(true)
//         );

//         vm.mockCall(
//             Predeploys.SUPERCHAIN_TOKEN_BRIDGE,
//             abi.encodeWithSelector(ISuperchainTokenBridge.sendERC20.selector, superchainWETH, address(smartDisperse), totalAmount, toChainId),
//             abi.encode()
//         );

//         vm.startPrank(deployer);
//         smartDisperse.transferTokensTo(toChainId, recipients, amounts, superchainWETH);
//         vm.stopPrank();
//     }

//     function testReceiveTokens() public {
//         uint256[] memory amounts = new uint256[](2);
//         amounts[0] = 1 ether;
//         amounts[1] = 2 ether;

//         address[] memory recipients = new address[](2);
//         recipients[0] = recipient1;
//         recipients[1] = recipient2;

//         uint256 totalAmount = 3 ether;

//         SmartDisperse.TransferMessage memory message = SmartDisperse.TransferMessage({
//             recipients: recipients,
//             amounts: amounts,
//             tokenAddress: superchainWETH,
//             totalAmount: totalAmount
//         });

//         vm.mockCall(
//             superchainWETH,
//             abi.encodeWithSelector(ISuperchainERC20.transfer.selector, recipient1, 1 ether),
//             abi.encode(true)
//         );

//         vm.mockCall(
//             superchainWETH,
//             abi.encodeWithSelector(ISuperchainERC20.transfer.selector, recipient2, 2 ether),
//             abi.encode(true)
//         );

//         vm.startPrank(crossDomainMessenger);
//         vm.mockCall(
//             crossDomainMessenger,
//             abi.encodeWithSelector(IL2ToL2CrossDomainMessenger.crossDomainMessageSender.selector),
//             abi.encode(address(smartDisperse))
//         );

//         smartDisperse.receiveTokens(message);
//         vm.stopPrank();
//     }

//     function testInvalidAmountsInReceiveTokens() public {
//         uint256[] memory amounts = new uint256[](2);
//         amounts[0] = 1 ether;
//         amounts[1] = 1 ether; // Invalid totalAmount

//         address[] memory recipients = new address[](2);
//         recipients[0] = recipient1;
//         recipients[1] = recipient2;

//         uint256 totalAmount = 3 ether; // Mismatched totalAmount

//         SmartDisperse.TransferMessage memory message = SmartDisperse.TransferMessage({
//             recipients: recipients,
//             amounts: amounts,
//             tokenAddress: superchainWETH,
//             totalAmount: totalAmount
//         });

//         vm.startPrank(crossDomainMessenger);
//         vm.expectRevert(SmartDisperse.InvalidAmount.selector);
//         smartDisperse.receiveTokens(message);
//         vm.stopPrank();
//     }

//     function testMismatchedArrayLengths() public {
//         uint256[] memory amounts = new uint256[](2);
//         amounts[0] = 1 ether;
//         amounts[1] = 2 ether;

//         address[] memory recipients = new address[](1); // Mismatched length
//         recipients[0] = recipient1;

//         vm.startPrank(deployer);
//         vm.expectRevert(SmartDisperse.InvalidArrayLengths.selector);
//         smartDisperse.transferTokensTo(toChainId, recipients, amounts, superchainWETH);
//         vm.stopPrank();
//     }

//     function testTokenTransferFailure() public {
//         uint256[] memory amounts = new uint256[](2);
//         amounts[0] = 1 ether;
//         amounts[1] = 2 ether;

//         address[] memory recipients = new address[](2);
//         recipients[0] = recipient1;
//         recipients[1] = recipient2;

//         uint256 totalAmount = 3 ether;

//         vm.mockCall(
//             superchainWETH,
//             abi.encodeWithSelector(ISuperchainERC20.transferFrom.selector, deployer, address(smartDisperse), totalAmount),
//             abi.encode(false) // Simulate failure
//         );

//         vm.startPrank(deployer);
//         vm.expectRevert(SmartDisperse.TokenTransferFailed.selector);
//         smartDisperse.transferTokensTo(toChainId, recipients, amounts, superchainWETH);
//         vm.stopPrank();
//     }
// }
