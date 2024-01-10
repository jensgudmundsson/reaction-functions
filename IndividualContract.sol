// SPDX-License-Identifier: GPL-3.0

// IndividualContract.sol
pragma solidity ^0.8.0;

contract IndividualContract {
    address public owner;

    // 1. Address of coordinating contract
    address constant public coordinatingContract = 0x1234567890123456789012345678901234567890;

    constructor() payable {
        owner = msg.sender;
    }

    // 2. Player's maximum investment
    // Example: 40 ETH
    uint256 constant public max = 40 * 1000000000000000000;

    modifier onlyCoordinatingContract() {
        require(msg.sender == coordinatingContract, "Only the coordinating contract can call this function.");
        _;
    }

    function reaction(uint256[] memory investments) external view onlyCoordinatingContract returns (uint256) {
        /* REACTION FUNCTION
        Returns integer reaction to 'investments', an (n-1)-tuple of the other players' investments.
        Can only be called by the coordinating contract.
        */
        // Example:
        uint256 sum = 0;
        for (uint256 i = 0; i < investments.length; i++) {
            sum += investments[i];
        }
        return sum/(investments.length+1) + 10 * 1000000000000000000;
    }

    function finalize(uint256 amount) external payable onlyCoordinatingContract {
        /* FINALIZE FUNCTION
        Transfers 'amount' to the coordinating contract and the remaining balance to the player.
        Can only be called by the coordinating contract.
        */
        payable(coordinatingContract).transfer(amount);
        payable(owner).transfer(address(this).balance);
    }

    function getMax() external pure returns (uint256) {
        return max;
    }

    // For debugging purposes
    function getCodeHash() public view returns (bytes32) {
        return address(this).codehash;
    }
    
    receive() external payable {}
}