pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

/**
 * @title Contract which supports oraclized access
 * @dev This contract to be used for mostly for access modifiers usage
 */
contract Oraclized is Ownable {

    address public oracle;

    constructor(address _oracle) public {
        oracle = _oracle;
    }

    /**
     * @dev Change oracle address
     * @param _oracle Oracle address
     */
    function setOracle(address _oracle) public onlyOwner {
        oracle = _oracle;
    }

    /**
     * @dev Modifier to allow access only by oracle
     */
    modifier onlyOracle() {
        require(msg.sender == oracle);
        _;
    }

    /**
     * @dev Modifier to allow access only by oracle or owner
     */
    modifier onlyOwnerOrOracle() {
        require((msg.sender == oracle) || (msg.sender == owner));
        _;
    }
}