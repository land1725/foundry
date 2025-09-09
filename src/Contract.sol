// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

contract Contract {
    // Addition function
    function add(uint256 a, uint256 b) public pure returns (uint256 c) {
        assembly {
            c := add(a, b)
        }
    }

    // Subtraction function
    function sub(uint256 a, uint256 b) public pure returns (uint256) {
        return a - b;
    }
}
