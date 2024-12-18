// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {SmartDisperse} from "../src/SmartDisperse.sol";

contract SmartDisperseSameChainTest is Test {
    SmartDisperse public smartDisperse;

    address user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address recipient1 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address recipient2 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address recipient3 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    address payable constant SUPERCHAIN_WETH_TOKEN =
        payable(0x4200000000000000000000000000000000000024);

    function setUp() public {
        smartDisperse = new SmartDisperse();

        vm.deal(user, 1000 ether);
        vm.deal(recipient1, 0 ether);
        vm.deal(recipient2, 0 ether);
        vm.deal(recipient3, 0 ether);
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

        vm.prank(user);
        smartDisperse.disperseNative{value: totalValue + excess}(
            recipients,
            values
        );

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
        // Use a recipient that reverts when receiving Ether
        address maliciousRecipient = address(new MaliciousRecipient());

        address[] memory recipients = new address[](1);
        recipients[0] = maliciousRecipient;

        uint256[] memory values = new uint256[](1);
        values[0] = 1 ether;

        // Expect the transaction to revert due to transfer failure
        vm.expectRevert("Transfer failed to recipient");
        smartDisperse.disperseNative{value: 1 ether}(recipients, values);
    }
}

contract MaliciousRecipient {
    fallback() external payable {
        revert("I don't accept Ether");
    }
}
