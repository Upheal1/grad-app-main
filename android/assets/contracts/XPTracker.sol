// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract XPTracker {
    struct Event {
        string description;
        uint256 timestamp;
    }

    mapping(address => Event[]) public userEvents;

    function addEvent(string memory description) public {
        userEvents[msg.sender].push(Event(description, block.timestamp));
    }

    function getEvents(address user) public view returns (Event[] memory) {
        return userEvents[user];
    }
}
