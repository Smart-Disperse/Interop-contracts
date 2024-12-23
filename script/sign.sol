// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import { console} from "forge-std/console.sol";

contract ErrorSelectors {
    function getErrorSelectors() public pure returns (bytes4[] memory, string[] memory) {
        bytes4[] memory selectors = new bytes4[](11);
        string[] memory names = new string[](11);
        
        // NotEntered
        selectors[0] = bytes4(keccak256("NotEntered()"));
        names[0] = "NotEntered";
        
        // IdOriginNotL2ToL2CrossDomainMessenger
        selectors[1] = bytes4(keccak256("IdOriginNotL2ToL2CrossDomainMessenger()"));
        names[1] = "IdOriginNotL2ToL2CrossDomainMessenger";
        
        // EventPayloadNotSentMessage
        selectors[2] = bytes4(keccak256("EventPayloadNotSentMessage()"));
        names[2] = "EventPayloadNotSentMessage";
        
        // MessageDestinationSameChain
        selectors[3] = bytes4(keccak256("MessageDestinationSameChain()"));
        names[3] = "MessageDestinationSameChain";
        
        // MessageDestinationNotRelayChain
        selectors[4] = bytes4(keccak256("MessageDestinationNotRelayChain()"));
        names[4] = "MessageDestinationNotRelayChain";
        
        // MessageTargetCrossL2Inbox
        selectors[5] = bytes4(keccak256("MessageTargetCrossL2Inbox()"));
        names[5] = "MessageTargetCrossL2Inbox";
        
        // MessageTargetL2ToL2CrossDomainMessenger
        selectors[6] = bytes4(keccak256("MessageTargetL2ToL2CrossDomainMessenger()"));
        names[6] = "MessageTargetL2ToL2CrossDomainMessenger";
        
        // MessageAlreadyRelayed
        selectors[7] = bytes4(keccak256("MessageAlreadyRelayed()"));
        names[7] = "MessageAlreadyRelayed";
        
        // ReentrantCall
        selectors[8] = bytes4(keccak256("ReentrantCall()"));
        names[8] = "ReentrantCall";
        
        // TargetCallFailed
        selectors[9] = bytes4(keccak256("TargetCallFailed()"));
        names[9] = "TargetCallFailed";

        return (selectors, names);
    }
    
    // Helper function to print selectors (can be called in tests)
    function run() public view  returns (string memory) {
        (bytes4[] memory selectors, string[] memory names) = getErrorSelectors();
        
        string memory output;
        for(uint i = 0; i < selectors.length; i++) {
                console.log(string(abi.encodePacked(
                output,
                names[i],
                ": 0x",
                toHexString(uint32(selectors[i])),
                "\n"
            )));
        }
        return output;
    }
    
    // Helper function to convert bytes to hex string
    function toHexString(uint32 value) internal pure returns (string memory) {
        bytes memory buffer = new bytes(8);
        for (uint256 i = 7; i >= 0; i--) {
            buffer[i] = bytes1(
                uint8(48 + uint256(value & 0xf))
            );
            if (uint8(buffer[i]) > 57) {
                buffer[i] = bytes1(uint8(buffer[i]) + 39);
            }
            value >>= 4;
            if (value == 0) break;
        }
        return string(buffer);
    }
}