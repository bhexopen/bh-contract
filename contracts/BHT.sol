pragma solidity ^0.4.24;

import "./BurnableToken.sol";

/**
 * @title BHT
 * @dev BHEX Token.
 */

contract BHT is BurnableToken {
    // If ether is sent to this address, send it back.
    function () public {
        revert();
    }

    string public constant name = "BHEX Token";
    string public constant symbol = "BHT";
    uint8 public constant decimals = 18;
    uint256 public constant INITIAL_SUPPLY = 2100000000;
    
    /**
    * @dev Constructor that gives msg.sender all of existing tokens.
    */
    constructor() public {
        totalSupply_ = INITIAL_SUPPLY * (10 ** uint256(decimals));
        balances[msg.sender] = totalSupply_;
        emit Transfer(address(0), msg.sender, totalSupply_);
    }
}