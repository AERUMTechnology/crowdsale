pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./KYCCrowdsale.sol";

/**
 * @title KYC Crowdsale which supports refundability
 */
contract KYCRefundableCrowdsale is KYCCrowdsale {
    using SafeMath for uint256;

    /**
     * @dev percentage multiplier to present percentage as decimals. 5 decimal by default
     */
    uint256 private percentage = 100 * 1000;

    /**
     * @dev goalReached specifies if crowdsale goal is reached
     * @dev isFinalized is crowdsale finished
     */
    bool public goalReached = false;
    bool public isFinalized = false;

    event Refund(address indexed _account, uint256 _amountInvested, uint256 _amountRefunded);
    event Finalized();
    event OwnerWithdraw(uint256 _amount);

    /**
     * @dev Set is goal reached or not
     * @param _success Is goal reached or not
     */
    function setGoalReached(bool _success) external onlyOwner {
        require(!isFinalized);
        goalReached = _success;
    }

    /**
     * @dev Investors can claim refunds here if crowdsale is unsuccessful
     */
    function claimRefund() public {
        require(isFinalized);
        require(!goalReached);

        uint256 refundPercentage = _refundPercentage();
        uint256 amountInvested = weiInvested[msg.sender];
        uint256 amountRefunded = amountInvested.mul(refundPercentage).div(percentage);
        weiInvested[msg.sender] = 0;
        usdInvested[msg.sender] = 0;
        msg.sender.transfer(amountRefunded);

        emit Refund(msg.sender, amountInvested, amountRefunded);
    }

    /**
     * @dev Must be called after crowdsale ends, to do some extra finalization works.
     */
    function finalize() public onlyOwner {
        require(!isFinalized);

        // NOTE: We do this because we would like to allow withdrawals earlier than closing time in case of crowdsale success
        closingTime = block.timestamp;
        isFinalized = true;

        emit Finalized();
    }

    /**
     * @dev Override. Withdraw tokens only after crowdsale ends.
     * Make sure crowdsale is successful & finalized
     */
    function withdrawTokens() public {
        require(isFinalized);
        require(goalReached);

        super.withdrawTokens();
    }

    /**
     * @dev Is called by owner to send funds to ICO wallet.
     * params _amount Amount to be sent.
     */
    function ownerWithdraw(uint256 _amount) external onlyOwner {
        require(_amount > 0);

        wallet.transfer(_amount);

        emit OwnerWithdraw(_amount);
    }

    /**
     * @dev Override. Determines how ETH is stored/forwarded on purchases.
     */
    function _forwardFunds() internal {
        // NOTE: Do nothing here. Keep funds in contract by default
    }

    /**
     * @dev Calculates refund percentage in case some funds will be used by dev team on crowdsale needs
     */
    function _refundPercentage() internal view returns (uint256) {
        return address(this).balance.mul(percentage).div(weiRaised);
    }
}