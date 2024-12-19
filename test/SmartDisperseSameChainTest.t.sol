// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SmartDisperse} from "../src/SmartDisperse.sol";
import {ISuperchainWETH} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainWETH.sol";
import {ISuperchainERC20} from "optimism/packages/contracts-bedrock/src/L2/interfaces/ISuperchainERC20.sol";
import {Predeploys} from "@contracts-bedrock/libraries/Predeploys.sol";

contract SmartDisperseSameChainTest is Test {
    SmartDisperse public smartDisperse;

    address user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address recipient1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address recipient2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address recipient3 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    address payable constant SUPERCHAIN_WETH_TOKEN =
        payable(0x4200000000000000000000000000000000000024);
    ISuperchainERC20 superchainWETH =
        ISuperchainERC20(Predeploys.SUPERCHAIN_WETH);

    uint256 op1Fork = vm.createSelectFork(("http://127.0.0.1:9545 "));

    function setUp() public {
        smartDisperse = new SmartDisperse();

        vm.deal(user, 1000 ether);
        vm.deal(recipient1, 0 ether);
        vm.deal(recipient2, 0 ether);
        vm.deal(recipient3, 0 ether);

        vm.startPrank(user);
        (bool success, ) = SUPERCHAIN_WETH_TOKEN.call{value: 10 ether}("");
        require(success, "WETH minting failed!");
        vm.stopPrank();
    }

    function testDisperseNative_Success() public {
        address[] memory recipients = new address[](3);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        recipients[2] = recipient3;

        uint256[] memory values = new uint256[](3);
        values[0] = 1 ether;
        values[1] = 2 ether;
        values[2] = 3 ether;

        uint256 totalValue = 6 ether;

        smartDisperse.disperseNative{value: totalValue}(recipients, values);

        assertEq(
            recipient1.balance,
            1 ether,
            "Incorrect balance for recipient1"
        );
        assertEq(
            recipient2.balance,
            2 ether,
            "Incorrect balance for recipient2"
        );
        assertEq(
            recipient3.balance,
            3 ether,
            "Incorrect balance for recipient3"
        );
    }

    function testDisperseNative_ExcessRefund() public {
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 2 ether;

        uint256 totalValue = values[0] + values[1];
        uint256 excess = 0.5 ether;

        // Expect the contract to refund excess ETH
        uint256 initialBalance = address(smartDisperse).balance;

        vm.startPrank(user);
        smartDisperse.disperseNative{value: totalValue + excess}(
            recipients,
            values
        );
        vm.stopPrank();

        uint256 finalBalance = address(smartDisperse).balance;

        assertEq(finalBalance, initialBalance, "Excess refund failed");
    }

    function testDisperseNative_MismatchedArrays() public {
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        uint256[] memory values = new uint256[](1);
        values[0] = 1 ether;

        // Expect the transaction to revert
        vm.expectRevert("Mismatched array length");
        smartDisperse.disperseNative{value: 1 ether}(recipients, values);
    }

    function testDisperseNative_InsufficientETH() public {
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        uint256[] memory values = new uint256[](2);
        values[0] = 1 ether;
        values[1] = 2 ether;

        // Insufficient ETH sent
        vm.expectRevert("Insufficient ETH sent");
        smartDisperse.disperseNative{value: 1.5 ether}(recipients, values);
    }

    function testDisperseNative_TransferFailure() public {
        address maliciousRecipient = address(new MaliciousRecipient());

        address[] memory recipients = new address[](1);
        recipients[0] = maliciousRecipient;

        uint256[] memory values = new uint256[](1);
        values[0] = 1 ether;

        vm.expectRevert("Transfer failed to recipient");
        smartDisperse.disperseNative{value: 1 ether}(recipients, values);
    }

    // test disperseTokens function

    function testDisperseTokens_Success() public {
        address[] memory recipients = new address[](3);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        recipients[2] = recipient3;

        uint256[] memory values = new uint256[](3);
        values[0] = 0.1 ether;
        values[1] = 0.2 ether;
        values[2] = 0.3 ether;

        vm.selectFork(op1Fork);
        vm.startPrank(user);

        superchainWETH.approve(address(smartDisperse), 0.6 ether);

        smartDisperse.disperseTokens(
            recipients,
            values,
            address(superchainWETH)
        );

        assertEq(superchainWETH.balanceOf(recipient1), 0.1 ether);
        assertEq(superchainWETH.balanceOf(recipient2), 0.2 ether);
        assertEq(superchainWETH.balanceOf(recipient3), 0.3 ether);
        assertEq(superchainWETH.balanceOf(user), 10 ether - 0.6 ether);
        vm.stopPrank();
    }

    function testDisperseTokens_MismatchedArrayLengths() public {
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        uint256[] memory values = new uint256[](3);
        values[0] = 0.1 ether;
        values[1] = 0.2 ether;
        values[2] = 0.3 ether;

        // Expect revert due to mismatched array lengths
        vm.expectRevert("Mismatched array length");
        smartDisperse.disperseTokens(
            recipients,
            values,
            address(superchainWETH)
        );
    }

    function testDisperseTokens_TransferFromFails() public {
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        uint256[] memory values = new uint256[](2);
        values[0] = 0.1 ether;
        values[1] = 0.2 ether;

        // Don't approve the contract, which will cause transferFrom to fail
        vm.expectRevert();
        smartDisperse.disperseTokens(
            recipients,
            values,
            address(superchainWETH)
        );
    }

    function testDisperseTokens_TransferFailsForRecipient() public {
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        uint256[] memory values = new uint256[](2);
        values[0] = 0.1 ether;
        values[1] = 0.2 ether;

        superchainWETH.approve(address(smartDisperse), 0.3 ether);

        // Make the second recipient's transfer fail (mocked behavior)
        vm.mockCall(
            address(superchainWETH),
            abi.encodeWithSelector(
                superchainWETH.transfer.selector,
                recipient2,
                0.2 ether
            ),
            abi.encode(false)
        );

        vm.expectRevert();
        smartDisperse.disperseTokens(
            recipients,
            values,
            address(superchainWETH)
        );
    }

    function testDisperseTokens_EmptyRecipients() public {
        address[] memory recipients = new address[](0);
        uint256[] memory values = new uint256[](0);

        superchainWETH.approve(address(smartDisperse), 0);

        smartDisperse.disperseTokens(
            recipients,
            values,
            address(superchainWETH)
        );

        assertEq(superchainWETH.balanceOf(user), 10 ether);
    }

    function testDisperseTokens_ZeroValues() public {
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = 0;

        superchainWETH.approve(address(smartDisperse), 0);

        smartDisperse.disperseTokens(
            recipients,
            values,
            address(superchainWETH)
        );

        assertEq(superchainWETH.balanceOf(recipient1), 0);
        assertEq(superchainWETH.balanceOf(recipient2), 0);
        assertEq(superchainWETH.balanceOf(user), 10 ether);
    }
}

contract MaliciousRecipient {
    fallback() external payable {
        revert("I don't accept Ether");
    }
}
