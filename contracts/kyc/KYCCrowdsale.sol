pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/crowdsale/distribution/PostDeliveryCrowdsale.sol";
import "../access/Oraclized.sol";

/**
 * @title Crowdsale which supports KYC crowdsale
 *        All users which invests more then amount specified has to pass KYC to withdraw tokens
 */
contract KYCCrowdsale is Oraclized, PostDeliveryCrowdsale {
    using SafeMath for uint256;

    /**
     * @dev etherPriceInUsd Ether price in cents
     * @dev usdRaised Total USD raised while ICO in cents
     * @dev weiInvested Stores amount of wei invested by each user
     * @dev usdInvested Stores amount of USD invested by each user in cents
     */
    uint256 public etherPriceInUsd;
    uint256 public usdRaised;
    mapping (address => uint256) public weiInvested;
    mapping (address => uint256) public usdInvested;

    /**
     * @dev KYCPassed Registry of users who passed KYC
     * @dev KYCRequired Registry of users who has to passed KYC
     */
    mapping (address => bool) public KYCPassed;
    mapping (address => bool) public KYCRequired;

    /**
     * @dev KYCRequiredAmountInUsd Amount in cents invested starting from which user must pass KYC
     */
    uint256 public KYCRequiredAmountInUsd;

    event EtherPriceUpdated(uint256 _cents);

    /**
     * @param _kycAmountInUsd Amount in cents invested starting from which user must pass KYC
     */
    constructor(uint256 _kycAmountInUsd, uint256 _etherPrice) public {
        require(_etherPrice > 0);

        KYCRequiredAmountInUsd = _kycAmountInUsd;
        etherPriceInUsd = _etherPrice;
    }

    /**
     * @dev Update amount required to pass KYC
     * @param _cents Amount in cents invested starting from which user must pass KYC
     */
    function setKYCRequiredAmount(uint256 _cents) external onlyOwnerOrOracle {
        require(_cents > 0);

        KYCRequiredAmountInUsd = _cents;
    }

    /**
     * @dev Set ether conversion rate
     * @param _cents Price of 1 ETH in cents
     */
    function setEtherPrice(uint256 _cents) public onlyOwnerOrOracle {
        require(_cents > 0);

        etherPriceInUsd = _cents;

        emit EtherPriceUpdated(_cents);
    }

    /**
     * @dev Check if KYC is required for address
     * @param _address Address to check
     */
    function isKYCRequired(address _address) external view returns(bool) {
        return KYCRequired[_address];
    }

    /**
     * @dev Check if KYC is passed by address
     * @param _address Address to check
     */
    function isKYCPassed(address _address) external view returns(bool) {
        return KYCPassed[_address];
    }

    /**
     * @dev Check if KYC is not required or passed
     * @param _address Address to check
     */
    function isKYCSatisfied(address _address) public view returns(bool) {
        return !KYCRequired[_address] || KYCPassed[_address];
    }

    /**
     * @dev Returns wei invested by specific amount
     * @param _account Account you would like to get wei for
     */
    function weiInvestedOf(address _account) external view returns (uint256) {
        return weiInvested[_account];
    }

    /**
     * @dev Returns cents invested by specific amount
     * @param _account Account you would like to get cents for
     */
    function usdInvestedOf(address _account) external view returns (uint256) {
        return usdInvested[_account];
    }

    /**
     * @dev Update KYC status for set of addresses
     * @param _addresses Addresses to update
     * @param _completed Is KYC passed or not
     */
    function updateKYCStatus(address[] _addresses, bool _completed) public onlyOwnerOrOracle {
        for (uint16 index = 0; index < _addresses.length; index++) {
            KYCPassed[_addresses[index]] = _completed;
        }
    }

    /**
     * @dev Override update purchasing state
     *      - update sum of funds invested
     *      - if total amount invested higher than KYC amount set KYC required to true
     */
    function _updatePurchasingState(address _beneficiary, uint256 _weiAmount) internal {
        super._updatePurchasingState(_beneficiary, _weiAmount);

        uint256 usdAmount = _weiToUsd(_weiAmount);
        usdRaised = usdRaised.add(usdAmount);
        usdInvested[_beneficiary] = usdInvested[_beneficiary].add(usdAmount);
        weiInvested[_beneficiary] = weiInvested[_beneficiary].add(_weiAmount);

        if (usdInvested[_beneficiary] >= KYCRequiredAmountInUsd) {
            KYCRequired[_beneficiary] = true;
        }
    }

    /**
     * @dev Override token withdraw
     *      - do not allow token withdraw in case KYC required but not passed
     */
    function withdrawTokens() public {
        require(isKYCSatisfied(msg.sender));

        super.withdrawTokens();
    }

    /**
     * @dev Converts wei to cents
     * @param _wei Wei amount
     */
    function _weiToUsd(uint256 _wei) internal view returns (uint256) {
        return _wei.mul(etherPriceInUsd).div(1e18);
    }

    /**
     * @dev Converts cents to wei
     * @param _cents Cents amount
     */
    function _usdToWei(uint256 _cents) internal view returns (uint256) {
        return _cents.mul(1e18).div(etherPriceInUsd);
    }
}