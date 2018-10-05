pragma solidity 0.4.24;

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
     * @dev pledgePercentage Percentage which is required to invest to pledge some tokens amount
     * @dev pledges Mapping of all pledges done by investors
     */
    uint256 public pledgeTotal;
    uint256 public pledgeClosingTime;
    uint256 public pledgePercentage;
    mapping (address => uint256) public pledges;

    /**
     * @dev whitelistedRate Rate which is used while whitelisted sale
     * @dev publicRate Rate which is used white public crowdsale
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
     * @param _pledgePercentage Percentage of pledge which should be invested to make it active
     * @param _kycAmountInUsd Amount on which KYC will be required in cents
     * @param _etherPriceInUsd ETH price in cents
     */
    constructor(
        ERC20 _token, address _wallet,
        uint256 _whitelistedRate, uint256 _publicRate,
        uint256 _openingTime, uint256 _closingTime,
        uint256 _pledgeClosingTime, uint256 _pledgePercentage,
        uint256 _kycAmountInUsd, uint256 _etherPriceInUsd)
    Oraclized(msg.sender)
    Crowdsale(_whitelistedRate, _wallet, _token)
    TimedCrowdsale(_openingTime, _closingTime)
    KYCCrowdsale(_kycAmountInUsd, _etherPriceInUsd)
    KYCRefundableCrowdsale()
    public {
        require(_openingTime < _pledgeClosingTime && _pledgeClosingTime < _closingTime);
        pledgeClosingTime = _pledgeClosingTime;
        pledgePercentage = _pledgePercentage;

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
     * @param _whitelistedRate Rate which is used while whitelisted sale
     * @param _publicRate Rate which is used white public crowdsale
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
        if (!hasClosed() || goalReached) {
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
        require(_weiToUsd(_weiAmount) >= minInvestmentInUsd);
        _ensureTokensAvailable(_getTokenAmount(_weiAmount));

        super._preValidatePurchase(_beneficiary, _weiAmount);
    }

    /**
     * @dev Ensure amount of tokens you would like to buy or pledge is available
     * @param _tokens Amount of tokens to buy or pledge
     */
    function _ensureTokensAvailable(uint256 _tokens) internal {
        uint256 tokensRequired = _tokens.add(tokensSold);

        if (pledgeOpen()) {
            tokensRequired = tokensRequired.add(pledgeTotal);
        }

        require(tokensRequired <= token.balanceOf(this));
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

    function getCurrentRate() public view returns (uint256) {
        if (pledgeOpen()) {
            return whitelistedRate;
        }
        return publicRate;
    }

    /**
     * @dev Set pledge percentage required to activate it
     * @param _percentage Required pledge percentage (no decimals)
     */
    function setPledgePercentage(uint256 _percentage) external onlyOwnerOrOracle {
        pledgePercentage = _percentage;
    }

    /**
     * @dev Check if pledge period is still open
     */
    function pledgeOpen() public view returns (bool) {
        return block.timestamp <= pledgeClosingTime;
    }

    /**
     * @dev Returns amount of pledge for account
     */
    function pledgeOf(address _address) public view returns (uint256) {
        return pledges[_address];
    }

    /**
     * @dev Pledge tokens while whitelisted round.
     * Account should have at least pledgePercentage % of tokens bought or buy with this method.
     * @param _amount Amount of tokens to pledge
     */
    function pledge(uint256 _amount) external payable {
        require(pledgeOpen());
        _ensureTokensAvailable(_amount.add(_getTokenAmount(msg.value)));

        uint256 originalPledge = pledges[msg.sender];

        if (msg.value > 0) {
            buyTokens(msg.sender);
        }

        // NOTE: Check if we bought enough amount to pledge
        require(balances[msg.sender] >= _amount.mul(pledgePercentage).div(100));
        pledges[msg.sender] = _amount;
        pledgeTotal = pledgeTotal.sub(originalPledge).add(_amount);
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
     * @dev Air drops tokens to users
     * @param _addresses list of addresses
     * @param _tokens List of tokens to drop
     */
    function airDropTokens(address[] _addresses, uint256[] _tokens) external onlyOwnerOrOracle {
        require(_addresses.length == _tokens.length);

        uint256 total;
        for (uint16 index = 0; index < _addresses.length; index++) {
            total = total.add(_tokens[index]);
        }

        _ensureTokensAvailable(total);

        for (index = 0; index < _addresses.length; index++) {
            balances[_addresses[index]] = balances[_addresses[index]].add(_tokens[index]);
        }
    }
}