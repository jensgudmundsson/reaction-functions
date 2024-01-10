// SPDX-License-Identifier: GPL-3.0

// CoordinatingContract.sol
pragma solidity ^0.8.0;

// Define the interface for the IndividualContract
interface X {
    function getMax() external pure returns (uint256);
    function reaction(uint256[] memory investments) external view returns (uint256); 
    function finalize(uint256 amount) external;
}

error InvalidHash(bytes32 required, bytes32 passed);
error InsufficientDeposit(uint256 required, uint256 passed);

contract CoordinatingContract {
    bool public commitPhase = true;
    bool public connectPhase = false;
    uint256[][] public searchPoints;

    struct Player {
        bytes32 commitHash;
        uint256 max;
        address contractAddress;
        bool done;
    }

    address[] public addresses;
    mapping(address => bool) public isPlayer;
    mapping(address => Player) public players;

    constructor(address[] memory _addresses) {
        addresses = _addresses;
    
        for (uint256 i = 0; i < addresses.length; i++) {
            isPlayer[addresses[i]] = true;
            players[addresses[i]].done = false;
        }
    }

    modifier onlyPlayer() {
        require(isPlayer[msg.sender], "Only player addresses can call this function.");
        _;
    }    
    
    modifier onlyCommit() {
        require(commitPhase, "Commit phase is inactive.");
        _;
    }

    modifier onlyConnect() {
        require(connectPhase, "Connect phase is inactive.");
        _;
    }

    function commit(bytes32 _commitHash) external onlyPlayer onlyCommit {
        players[msg.sender].commitHash = _commitHash;
        players[msg.sender].done = true;

        // Checks whether all have committed to contracts
        bool allDone = true;
        for (uint256 i = 0; i < addresses.length; i++) {
            if (!players[addresses[i]].done) {
                allDone = false;
                break;
            }
        }

        // If all have commited, start 'connect' phase
        if (allDone) {
            commitPhase = false;
            connectPhase = true;
            for (uint256 i = 0; i < addresses.length; i++) {
                players[addresses[i]].done = false;
            }
        }
    }

    function connect(address _address) external onlyPlayer onlyConnect {
        // Verify commitment hash
        bytes32 codehash = _address.codehash;
        if (codehash != players[msg.sender].commitHash) {
            revert InvalidHash({
                required: players[msg.sender].commitHash,
                passed: codehash
            });
        }

        // Check if deposit is sufficient
        uint256 max = X(_address).getMax();
        if (_address.balance < max) {
            revert InsufficientDeposit({
                required: max,
                passed: _address.balance
            });
        }
        
        players[msg.sender].max = max; 
        players[msg.sender].contractAddress = _address;
        players[msg.sender].done = true;

        // Checks whether all are connected
        bool allDone = true;
        for (uint256 i = 0; i < addresses.length; i++) {
            if (!players[addresses[i]].done) {
                allDone = false;
                break;
            }
        }

        // If all have connected, start fixed point search
        if (allDone) {
            connectPhase = false;
            search();
        }
    }

    function search() internal {
        uint256[] memory x = new uint256[](addresses.length);
        uint256[] memory z = new uint256[](addresses.length);
        
        // Initialization at max values
        for (uint256 i = 0; i < addresses.length; i++) {
            x[i] = 0;
            z[i] = players[addresses[i]].max;
        }

        while (!inSearchPoints(z)) {
            searchPoints.push(z);
            x = z;    
            // Find reactions
            for (uint256 i = 0; i < addresses.length; i++) {
                uint256[] memory y = new uint256[](x.length - 1);
                uint256 index = 0;
                for (uint256 j = 0; j < x.length; j++) {
                    if (i != j) {
                        y[index] = x[j];
                        index ++;
                    }
                }
                z[i] = X(players[addresses[i]].contractAddress).reaction(y);
            }
        }

        // Checks if actual fixed point
        bool fixedPoint = true;
        for (uint256 i = 0; i < addresses.length; i++) {
            if (x[i] != z[i]) {
                fixedPoint = false;
            }
        }
        if (!fixedPoint) {
            for (uint256 i = 0; i < addresses.length; i++) {
                z[i] = 0;
            }
        }
        invest(z);
    }

    function inSearchPoints(uint256[] memory z) internal view returns (bool) {
        for (uint i = 0; i < searchPoints.length; i++) {
            uint256[] memory x;
            x = searchPoints[i];
            bool matches = true;
            for (uint j = 0; j < x.length; j++) {
                if (x[j] != z[j]) {
                    matches = false;
                    continue;
                }
            }
            if (matches) {
                return true;
            }
        }
        return false;
    }

    function invest(uint256[] memory z) internal {
        for (uint256 i = 0; i < addresses.length; i++) {
            X(players[addresses[i]].contractAddress).finalize(z[i]);
        }
    }

    receive() external payable {}
}