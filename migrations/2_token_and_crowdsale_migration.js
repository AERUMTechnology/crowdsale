var AerumToken = artifacts.require("AerumToken");
var AerumCrowdsale = artifacts.require("AerumCrowdsale");

module.exports = function (deployer, network, accounts) {
  deployer.deploy(AerumToken).then(function () {
    if(network === "development") {
      return deployDevCrowdsale(deployer, network, accounts);
    } else {
      return deployTestCrowdsale(deployer, network, accounts);
    }
  });

  function deployDevCrowdsale(deployer, network, accounts) {
    console.log('Deploy development crowdsale');
    const wallet = accounts[0];
    const whitelistedRate = 200;
    const publicRate = 100;
    const kycAmountInUsd = 1000 * 100;
    const etherPriceInUsd = 200 * 100;
    const startDelay = 0;
    const startTime = Math.floor(new Date().getTime() / 1000) + startDelay;
    const pledgeDurationInDays = 1;
    const icoDurationInDays = 2;
    const secondsInDay = 60 * 60 * 24;
    const pledgeClosingTime = startTime + (secondsInDay * pledgeDurationInDays);
    const endTime = startTime + (secondsInDay * icoDurationInDays);
    const pledgePercentage = 10;

    return deployer.deploy(AerumCrowdsale,
      AerumToken.address, wallet,
      whitelistedRate, publicRate,
      startTime, endTime,
      pledgeClosingTime, pledgePercentage,
      kycAmountInUsd, etherPriceInUsd
    );
  }

  function deployTestCrowdsale(deployer, network, accounts) {
    console.log('Deploy test crowdsale');
    const wallet = accounts[0];
    const whitelistedRate = 200;
    const publicRate = 100;
    const kycAmountInUsd = 1000 * 100;
    const etherPriceInUsd = 200 * 100;
    const startDelay = 60;
    const startTime = Math.floor(new Date().getTime() / 1000) + startDelay;
    const pledgeDurationInDays = 14;
    const icoDurationInDays = 28;
    const secondsInDay = 60 * 60 * 24;
    const pledgeClosingTime = startTime + (secondsInDay * pledgeDurationInDays);
    const endTime = startTime + (secondsInDay * icoDurationInDays);
    const pledgePercentage = 10;

    return deployer.deploy(AerumCrowdsale,
      AerumToken.address, wallet,
      whitelistedRate, publicRate,
      startTime, endTime,
      pledgeClosingTime, pledgePercentage,
      kycAmountInUsd, etherPriceInUsd
    );
  }
};