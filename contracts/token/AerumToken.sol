pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/PausableToken.sol";

// NOTE: This is not final XRM token. It's just ERC20 used for testing
contract AerumToken is Ownable, PausableToken {
    string public name = "Aerum";
    string public symbol = "XRM";
    uint8 public decimals = 18;
    uint256 public initialSupply = 1000 * 1000 * 1000;

    constructor() public {
        totalSupply_ = initialSupply * (10 ** uint256(decimals));
        balances[owner] = totalSupply_;
    }
}