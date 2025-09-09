// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "src/Contract.sol";

contract TestContract is Test {
    Contract c;

    function setUp() public {
        console.log("Setting up test environment...");
        c = new Contract();
        console.log("Contract deployed at address:", address(c));
        console.log("Test setup completed");
    }
    function testAdd() public {
        uint256 a = 5;
        uint256 b = 3;
        uint256 result = c.add(a, b);
        console.log("Testing add function with inputs:", a, b);
        assertEq(result, 8, "Addition result should be 8");
    }
    function testSub() public {
        uint256 a = 5;
        uint256 b = 3;
        uint256 result = c.sub(a, b);
        console.log("Testing sub function with inputs:", a, b);
        assertEq(result, 2, "Subtraction result should be 2");
        }
}
