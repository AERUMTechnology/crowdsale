pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "../kyc/KYCRefundableCrowdsale.sol";

/**
 * @title Aerum crowdsale contract
 */
contract AerumCrowdsale is KYCRefundableCrowdsale {
    using SafeMath for uint256;

    /**
     * @dev minInvestmentInUsd Minimal investment allowed in cents
     */
    uint256 public minInvestmentInUsd;

    /**
     * @dev tokensSold Amount of tokens sold by this time
     */
    uint256 public tokensSold;

    /**
     * @dev pledgeTotal Total pledge collected from all investors
     * @dev pledgeClosingTime Time when pledge is closed & it's not possible to pledge more or use pledge more
     * @dev pledges Mapping of all pledges done by investors
     */
    uint256 public pledgeTotal;
    uint256 public pledgeClosingTime;
    mapping (address => uint256) public pledges;

    /**
     * @dev whitelistedRate Rate which is used while whitelisted sale (XRM to ETH)
     * @dev publicRate Rate which is used white public crowdsale (XRM to ETH)
     */
    uint256 public whitelistedRate;
    uint256 public publicRate;


    event MinInvestmentUpdated(uint256 _cents);
    event RateUpdated(uint256 _whitelistedRate, uint256 _publicRate);
    event Withdraw(address indexed _account, uint256 _amount);

    /**
     * @param _token ERC20 compatible token on which crowdsale is done
     * @param _wallet Address where all ETH funded will be sent after ICO finishes
     * @param _whitelistedRate Rate which is used while whitelisted sale
     * @param _publicRate Rate which is used white public crowdsale
     * @param _openingTime Crowdsale open time
     * @param _closingTime Crowdsale close time
     * @param _pledgeClosingTime Time when pledge is closed & no more active
\\
     * @param _kycAmountInUsd Amount on which KYC will be required in cents
     * @param _etherPriceInUsd ETH price in cents
     */
    constructor(
        ERC20 _token, address _wallet,
        uint256 _whitelistedRate, uint256 _publicRate,
        uint256 _openingTime, uint256 _closingTime,
        uint256 _pledgeClosingTime,
        uint256 _kycAmountInUsd, uint256 _etherPriceInUsd)
    Oraclized(msg.sender)
    Crowdsale(_whitelistedRate, _wallet, _token)
    TimedCrowdsale(_openingTime, _closingTime)
    KYCCrowdsale(_kycAmountInUsd, _etherPriceInUsd)
    KYCRefundableCrowdsale()
    public {
        require(_openingTime < _pledgeClosingTime && _pledgeClosingTime < _closingTime);
        pledgeClosingTime = _pledgeClosingTime;

        whitelistedRate = _whitelistedRate;
        publicRate = _publicRate;

        minInvestmentInUsd = 25 * 100;
    }

    /**
     * @dev Update minimal allowed investment
     */
    function setMinInvestment(uint256 _cents) external onlyOwnerOrOracle {
        minInvestmentInUsd = _cents;

        emit MinInvestmentUpdated(_cents);
    }

    /**
     * @dev Update closing time
     * @param _closingTime Closing time
     */
    function setClosingTime(uint256 _closingTime) external onlyOwner {
        require(_closingTime >= openingTime);

        closingTime = _closingTime;
    }

    /**
     * @dev Update pledge closing time
     * @param _pledgeClosingTime Pledge closing time
     */
    function setPledgeClosingTime(uint256 _pledgeClosingTime) external onlyOwner {
        require(_pledgeClosingTime >= openingTime && _pledgeClosingTime <= closingTime);

        pledgeClosingTime = _pledgeClosingTime;
    }

    /**
     * @dev Update rates
     * @param _whitelistedRate Rate which is used while whitelisted sale (XRM to ETH)
     * @param _publicRate Rate which is used white public crowdsale (XRM to ETH)
     */
    function setRate(uint256 _whitelistedRate, uint256 _publicRate) public onlyOwnerOrOracle {
        require(_whitelistedRate > 0);
        require(_publicRate > 0);

        whitelistedRate = _whitelistedRate;
        publicRate = _publicRate;

        emit RateUpdated(_whitelistedRate, _publicRate);
    }

    /**
     * @dev Update rates & ether price. Done to not make 2 requests from oracle.
     * @param _whitelistedRate Rate which is used while whitelisted sale
     * @param _publicRate Rate which is used white public crowdsale
     * @param _cents Price of 1 ETH in cents
     */
    function setRateAndEtherPrice(uint256 _whitelistedRate, uint256 _publicRate, uint256 _cents) external onlyOwnerOrOracle {
        setRate(_whitelistedRate, _publicRate);
        setEtherPrice(_cents);
    }

    /**
     * @dev Send remaining tokens back
     * @param _to Address to send
     * @param _amount Amount to send
     */
    function sendTokens(address _to, uint256 _amount) external onlyOwner {
        if (!isFinalized || goalReached) {
            // NOTE: if crowdsale not finished or successful we should keep at least tokens sold
            _ensureTokensAvailable(_amount);
        }

        token.transfer(_to, _amount);
    }

    /**
     * @dev Get balance fo tokens bought
     * @param _address Address of investor
     */
    function balanceOf(address _address) external view returns (uint256) {
        return balances[_address];
    }

    /**
     * @dev Check if all tokens were sold
     */
    function capReached() public view returns (bool) {
        return tokensSold >= token.balanceOf(this);
    }

    /**
     * @dev Returns percentage of tokens sold
     */
    function completionPercentage() external view returns (uint256) {
        uint256 balance = token.balanceOf(this);
        if (balance == 0) {
            return 0;
        }

        return tokensSold.mul(100).div(balance);
    }

    /**
     * @dev Returns remaining tokens based on stage
     */
    function tokensRemaining() external view returns(uint256) {
        return token.balanceOf(this).sub(_tokensLocked());
    }

    /**
     * @dev Override. Withdraw tokens only after crowdsale ends.
     * Adding withdraw event
     */
    function withdrawTokens() public {
        uint256 amount = balances[msg.sender];
        super.withdrawTokens();

        emit Withdraw(msg.sender, amount);
    }

    /**
     * @dev Override crowdsale pre validate. Check:
     *      - is amount invested larger than minimal
     *      - there is enough tokens on balance of contract to proceed
     *      - check if pledges amount are not more than total coins (in case of pledge period)
     */
    function _preValidatePurchase(address _beneficiary, uint256 _weiAmount) internal {
        super._preValidatePurchase(_beneficiary, _weiAmount);

        require(_totalInvestmentInUsd(_beneficiary, _weiAmount) >= minInvestmentInUsd);
        _ensureTokensAvailableExcludingPledge(_beneficiary, _getTokenAmount(_weiAmount));
    }

    /**
     * @dev Returns total investment of beneficiary including current one in cents
     * @param _beneficiary Address to check
     * @param _weiAmount Current amount being invested in wei
     */
    function _totalInvestmentInUsd(address _beneficiary, uint256 _weiAmount) internal view returns(uint256) {
        return usdInvested[_beneficiary].add(_weiToUsd(_weiAmount));
    }

    /**
     * @dev Override process purchase
     *      - additionally sum tokens sold
     */
    function _processPurchase(address _beneficiary, uint256 _tokenAmount) internal {
        super._processPurchase(_beneficiary, _tokenAmount);

        tokensSold = tokensSold.add(_tokenAmount);

        if (pledgeOpen()) {
            // NOTE: In case of buying tokens inside pledge it doesn't matter how we decrease pledge as we change it anyway
            _decreasePledge(_beneficiary, _tokenAmount);
        }
    }

    /**
     * @dev Decrease pledge of account by specific token amount
     * @param _beneficiary Account to increase pledge
     * @param _tokenAmount Amount of tokens to decrease pledge
     */
    function _decreasePledge(address _beneficiary, uint256 _tokenAmount) internal {
        if (pledgeOf(_beneficiary) <= _tokenAmount) {
            pledges[_beneficiary] = 0;
        } else {
            pledges[_beneficiary] = pledges[_beneficiary].sub(_tokenAmount);
        }
    }

    /**
     * @dev Override to use whitelisted or public crowdsale rates
     */
    function _getTokenAmount(uint256 _weiAmount) internal view returns (uint256) {
        uint256 currentRate = getCurrentRate();
        return _weiAmount.mul(currentRate);
    }

    /**
     * @dev Returns current XRM to ETH rate based on stage
     */
    function getCurrentRate() public view returns (uint256) {
        if (pledgeOpen()) {
            return whitelistedRate;
        }
        return publicRate;
    }

    /**
     * @dev Check if pledge period is still open
     */
    function pledgeOpen() public view returns (bool) {
        return (openingTime <= block.timestamp) && (block.timestamp <= pledgeClosingTime);
    }

    /**
     * @dev Returns amount of pledge for account
     */
    function pledgeOf(address _address) public view returns (uint256) {
        return pledges[_address];
    }

    /**
     * @dev Check if all tokens were pledged
     */
    function pledgeCapReached() public view returns (bool) {
        return pledgeTotal.add(tokensSold) >= token.balanceOf(this);
    }

    /**
     * @dev Returns percentage of tokens pledged
     */
    function pledgeCompletionPercentage() external view returns (uint256) {
        uint256 balance = token.balanceOf(this);
        if (balance == 0) {
            return 0;
        }

        return pledgeTotal.add(tokensSold).mul(100).div(balance);
    }

    /**
     * @dev Pledges
     * @param _addresses list of addresses
     * @param _tokens List of tokens to drop
     */
    function pledge(address[] _addresses, uint256[] _tokens) external onlyOwnerOrOracle {
        require(_addresses.length == _tokens.length);
        _ensureTokensListAvailable(_tokens);

        for (uint16 index = 0; index < _addresses.length; index++) {
            pledgeTotal = pledgeTotal.sub(pledges[_addresses[index]]).add(_tokens[index]);
            pledges[_addresses[index]] = _tokens[index];
        }
    }

    /**
     * @dev Air drops tokens to users
     * @param _addresses list of addresses
     * @param _tokens List of tokens to drop
     */
    function airDropTokens(address[] _addresses, uint256[] _tokens) external onlyOwnerOrOracle {
        require(_addresses.length == _tokens.length);
        _ensureTokensListAvailable(_tokens);

        for (uint16 index = 0; index < _addresses.length; index++) {
            balances[_addresses[index]] = balances[_addresses[index]].add(_tokens[index]);
        }
    }

    /**
     * @dev Ensure token list total is available
     * @param _tokens list of tokens amount
     */
    function _ensureTokensListAvailable(uint256[] _tokens) internal {
        uint256 total;
        for (uint16 index = 0; index < _tokens.length; index++) {
            total = total.add(_tokens[index]);
        }

        _ensureTokensAvailable(total);
    }

    /**
     * @dev Ensure amount of tokens you would like to buy or pledge is available
     * @param _tokens Amount of tokens to buy or pledge
     */
    function _ensureTokensAvailable(uint256 _tokens) internal view {
        require(_tokens.add(_tokensLocked()) <= token.balanceOf(this));
    }

    /**
     * @dev Ensure amount of tokens you would like to buy or pledge is available excluding pledged for account
     * @param _account Account which is checked for pledge
     * @param _tokens Amount of tokens to buy or pledge
     */
    function _ensureTokensAvailableExcludingPledge(address _account, uint256 _tokens) internal view {
        require(_tokens.add(_tokensLockedExcludingPledge(_account)) <= token.balanceOf(this));
    }

    /**
     * @dev Returns locked or sold tokens based on stage
     */
    function _tokensLocked() internal view returns(uint256) {
        uint256 locked = tokensSold;

        if (pledgeOpen()) {
            locked = locked.add(pledgeTotal);
        }

        return locked;
    }

    /**
     * @dev Returns locked or sold tokens based on stage excluding pledged for account
     * @param _account Account which is checked for pledge
     */
    function _tokensLockedExcludingPledge(address _account) internal view returns(uint256) {
        uint256 locked = _tokensLocked();

        if (pledgeOpen()) {
            locked = locked.sub(pledgeOf(_account));
        }

        return locked;
    }
}