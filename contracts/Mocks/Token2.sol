//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token2 is ERC20{

    constructor() ERC20("test Token2","Token2"){}

    function mint(uint amount) external {
        _mint(msg.sender,amount* 1 ether);
    }

}