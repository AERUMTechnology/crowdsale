var AerumToken = artifacts.require("AerumToken");
var AerumCrowdsale = artifacts.require("AerumCrowdsale");

const utils = require("./utils");

contract('AerumCrowdsale', (accounts) => {

  const whitelistedRate = 200;
  const rate = 100;
  const etherPriceInUsd = 200 * 100;

  const owner = accounts[0];
  const notKYCCustomer = accounts[1];
  const KYCCustomer = accounts[2];
  const multiPayingCustomer = accounts[3];
  const KYCCustomerNotConfirmed = accounts[4];
  const pledgeCustomer1 = accounts[5];
  const pledgeCustomer2 = accounts[6];
  const airDropCustomer1 = accounts[7];
  const airDropCustomer2 = accounts[8];
  const failedCrowdsaleCustomer = accounts[9];

  let token;
  let crowdsale;

  before(async () => {
    token = await AerumToken.deployed();
    crowdsale = await AerumCrowdsale.deployed();

    // NOTE: We send 8000 tokens. Hard cap will be 80 ETH
    await token.transfer(crowdsale.address, 8000 * Math.pow(10, 18), {from: owner});
  });

  it("Contract should exist", async () => {
    assert.isTrue(!!crowdsale, 'Contract is not deployed');
  });

  it("Crowdsale should be running", async () => {
    assert.isTrue(utils.now() >= await crowdsale.openingTime(), 'Crowdsale not started');
    assert.isTrue(utils.now() <= await crowdsale.closingTime(), 'Crowdsale has finished');
    assert.isTrue(!await crowdsale.goalReached(), 'Crowdsale goal reached');
    assert.isTrue(!await crowdsale.isFinalized(), 'Crowdsale finalized');
    assert.isTrue(!await crowdsale.capReached(), 'Crowdsale cap reached');
    assert.isTrue(await crowdsale.pledgeOpen(), 'Pledge should be opened');
    const currentRate = await crowdsale.getCurrentRate();
    assert.equal(currentRate.toNumber(), whitelistedRate);
  });

  it("Should be able to pledge tokens by owner", async () => {
    const pledge1 = 2000 * Math.pow(10, 18);
    const pledge2 = 1000 * Math.pow(10, 18);
    await crowdsale.pledge([pledgeCustomer1, pledgeCustomer2], [pledge1, pledge2], {from: owner});
    assert.equal(await crowdsale.pledgeOf(pledgeCustomer1), pledge1);
    assert.equal(await crowdsale.pledgeOf(pledgeCustomer2), pledge2);
  });

  it("Should be able to change pledge", async () => {
    const pledge = 1000 * Math.pow(10, 18);
    await crowdsale.pledge([pledgeCustomer1], [pledge], {from: owner});
    assert.equal(await crowdsale.pledgeOf(pledgeCustomer1), pledge);
  });

  it("Should NOT be able to send back tokens which were pledged", async () => {
    const beforeSendBalance = await token.balanceOf(crowdsale.address);
    try {
      await crowdsale.sendTokens(owner, 7000 * Math.pow(10, 18), {from: owner});
      assert.fail("Should NOT be able to send back tokens which were pledged");
    } catch (e) {
    }
    const afterSendBalance = await token.balanceOf(crowdsale.address);
    assert.equal(beforeSendBalance.toNumber(), afterSendBalance.toNumber());
  });

  it("Should NOT be able to pledge more tokens than possible", async () => {
    try {
      const pledge = 10000 * Math.pow(10, 18);
      await crowdsale.pledge([pledgeCustomer1], [pledge], {from: owner});
      assert.fail("Should NOT be able to pledge more tokens than possible");
    } catch (e) {
      const previousPledge = 1000 * Math.pow(10, 18);
      assert.equal(await crowdsale.pledgeOf(pledgeCustomer1), previousPledge);
    }
  });

  it("Should NOT be able to buy more tokens than remaining of pledged & sold", async () => {
    try {
      const tokensSold = await crowdsale.tokensSold();
      const pledgeTotal = await crowdsale.pledgeTotal();
      const customerPledge = await utils.pledgeOf(crowdsale, pledgeCustomer1);
      const tokenBalance = await token.balanceOf(crowdsale.address);
      // NOTE: Try to buy more than allowed (more than left)
      const maxInvestmentPossible = (tokenBalance.toNumber() - (tokensSold.toNumber() + pledgeTotal.toNumber()) + customerPledge) / (whitelistedRate * Math.pow(10, 18));
      const notAllowedInvestment = maxInvestmentPossible + 1;
      const etherBalance = web3.fromWei(await web3.eth.getBalance(pledgeCustomer1), 'ether');
      assert.isTrue(notAllowedInvestment <= etherBalance.toNumber());
      await utils.invest(web3, crowdsale, pledgeCustomer1, notAllowedInvestment);
      assert.fail("Should NOT be able to buy more tokens than remaining of pledged & sold");
    } catch (e) {
      const previousPledge = 1000 * Math.pow(10, 18);
      assert.equal(await utils.pledgeOf(crowdsale, pledgeCustomer1), previousPledge);
      assert.equal(await utils.tokenBalanceOf(crowdsale, pledgeCustomer1), 0);
    }
  });

  it("Should be able to switch to public round", async () => {
    // NOTE: Simulate end of pledge period
    await crowdsale.setPledgeClosingTime(utils.now() - 1);

    assert.isTrue(!await crowdsale.pledgeOpen(), 'Pledge should be closed');
    const currentRate = await crowdsale.getCurrentRate();
    assert.equal(currentRate.toNumber(), rate);
  });

  it("Should be able to invest with no KYC required", async () => {
    const investment = 1;
    const weiRaisedBefore = await utils.weiRaised(crowdsale);
    const usdRaisedBefore = await utils.usdRaised(crowdsale);
    await utils.invest(web3, crowdsale, notKYCCustomer, investment);
    assert.equal(await utils.weiRaised(crowdsale), weiRaisedBefore + parseInt(web3.toWei(investment, 'ether')));
    assert.equal(await utils.usdRaised(crowdsale), usdRaisedBefore + investment * etherPriceInUsd);
    assert.equal(await utils.tokenBalanceOf(crowdsale, notKYCCustomer), investment * rate * Math.pow(10, 18));
    assert.equal(await utils.isKYCRequired(crowdsale, notKYCCustomer), false);
  });

  it("Should be able to invest with KYC required", async () => {
    const investment = 5;
    const weiRaisedBefore = await utils.weiRaised(crowdsale);
    await utils.invest(web3, crowdsale, KYCCustomer, investment);
    assert.equal(await utils.weiRaised(crowdsale), weiRaisedBefore + parseInt(web3.toWei(investment, 'ether')));
    assert.equal(await utils.tokenBalanceOf(crowdsale, KYCCustomer), investment * rate * Math.pow(10, 18));
    assert.equal(await utils.isKYCRequired(crowdsale, KYCCustomer), true);

    // NOTE: Invest for other customer for future tests
    await utils.invest(web3, crowdsale, KYCCustomerNotConfirmed, investment);
  });

  it("Should be able to invest few times", async () => {
    const weiRaisedBefore = await utils.weiRaised(crowdsale);
    await utils.invest(web3, crowdsale, multiPayingCustomer, 0.5);
    await utils.invest(web3, crowdsale, multiPayingCustomer, 0.3);
    assert.equal(await utils.weiRaised(crowdsale), weiRaisedBefore + parseInt(web3.toWei(0.8, 'ether')));
    assert.equal(await utils.tokenBalanceOf(crowdsale, multiPayingCustomer), 0.8 * rate * Math.pow(10, 18));
  });

  it("Should not be able to withdraw till end of ICO", async () => {
    try {
      await crowdsale.withdrawTokens({from: owner});
      assert.fail("Should not allow withdraw till end of ICO");
    } catch (e) {
    }
  });

  it("Should not be able to invest below minimal amount", async () => {
    let wei = await utils.weiRaised(crowdsale);
    try {
      await utils.invest(web3, crowdsale, owner, 0.00001);
      assert.fail("Should not allow sending too small amounts");
    } catch (e) {
      assert.equal(await utils.weiRaised(crowdsale), wei);
    }
  });

  it("Should not be able to invest more than hard cap", async () => {
    const wei = await utils.weiRaised(crowdsale);
    try {
      await utils.invest(web3, crowdsale, owner, 81);
      assert.fail("Should not allow invest more than hard cap");
    } catch (e) {
      assert.equal(await utils.weiRaised(crowdsale), wei);
    }
  });

  it("Should be able to send some tokens back", async () => {
    const sendAmount = 1000 * Math.pow(10, 18);
    const initBalance = await token.balanceOf(crowdsale.address);
    await crowdsale.sendTokens(owner, sendAmount);
    const afterSendBalance = await token.balanceOf(crowdsale.address);
    assert.equal(initBalance - sendAmount, afterSendBalance);
  });

  it("Should NOT be able to get tokens back till crowdsale not finalized", async () => {
    try {
      await crowdsale.withdrawTokens({from: notKYCCustomer});
      assert.fail("Should NOT be able to get tokens back till crowdsale not finalized");
    } catch (e) {
    }
  });

  it("Should be able to update KYC status", async () => {
    await crowdsale.updateKYCStatus([KYCCustomer], true);
    assert.isTrue(await crowdsale.isKYCPassed(KYCCustomer));
  });

  it("Owner should get funds", async () => {
    const initOwnerBalance = web3.eth.getBalance(owner);
    await crowdsale.ownerWithdraw(web3.toWei(1, 'ether'));
    const ownerBalance = web3.eth.getBalance(owner);
    assert.isTrue(ownerBalance.toNumber() > initOwnerBalance.toNumber());
  });

  it("Should be able to finalize crowdsale (even before closing time)", async () => {
    await crowdsale.setGoalReached(true, {from: owner});
    await crowdsale.finalize({from: owner});
    // NOTE: wait finalization & closing time pass
    await timeout(1000);
    assert.isTrue(await crowdsale.isFinalized());
    assert.isTrue(await crowdsale.goalReached());
  });

  it("Should be able to update KYC status after finalize", async () => {
    await crowdsale.updateKYCStatus([KYCCustomer], true);
    assert.isTrue(await crowdsale.isKYCPassed(KYCCustomer));
  });

  it("Should be able to get tokens back in case of no KYC", async () => {
    const investment = 1;
    const expectedBalance = investment * rate * Math.pow(10, 18);
    assert.equal(await token.balanceOf(notKYCCustomer), 0);
    assert.equal(await utils.tokenBalanceOf(crowdsale, notKYCCustomer), expectedBalance);

    // NOTE: Do some timeout to make sure ICO finalized
    await timeout(1000);
    await crowdsale.withdrawTokens({from: notKYCCustomer});

    assert.equal(await token.balanceOf(notKYCCustomer), expectedBalance);
    assert.equal(await utils.tokenBalanceOf(crowdsale, notKYCCustomer), 0);
  });

  it("Should be able to get tokens back in case of KYC confirmed", async () => {
    const investment = 5;
    const expectedBalance = investment * rate * Math.pow(10, 18);
    assert.equal(await token.balanceOf(KYCCustomer), 0);
    assert.equal(await utils.tokenBalanceOf(crowdsale, KYCCustomer), expectedBalance);

    // NOTE: Do some timeout to make sure ICO finalized
    await timeout(1000);
    await crowdsale.withdrawTokens({from: KYCCustomer});

    assert.equal(await token.balanceOf(KYCCustomer), expectedBalance);
    assert.equal(await utils.tokenBalanceOf(crowdsale, KYCCustomer), 0);
  });

  it("Should NOT be able to refund in case of crowdsale success", async () => {
    try {
      await crowdsale.claimRefund({from: KYCCustomer});
      assert.fail("Should NOT be able to refund in case of token withdraw success");
    } catch (e) {
    }
  });

  it("Should NOT be able to get tokens back in case of KYC NOT confirmed", async () => {
    try {
      await crowdsale.withdrawTokens({from: KYCCustomerNotConfirmed});
      assert.fail("Should NOT be able to get tokens back in case of KYC NOT confirmed");
    } catch (e) {
      const tokenBalance = await token.balanceOf(KYCCustomerNotConfirmed);
      assert.equal(tokenBalance.toNumber(), 0);
    }
  });

  it("Should be able to airdrop tokens while & after ICO", async () => {
    const tokensBeforeDrop1 = await utils.tokenBalanceOf(crowdsale, airDropCustomer1);
    const tokensBeforeDrop2 = await utils.tokenBalanceOf(crowdsale, airDropCustomer2);
    await crowdsale.airDropTokens([airDropCustomer1, airDropCustomer2], [60, 10], {from: owner});
    const tokensAfterDrop1 = await utils.tokenBalanceOf(crowdsale, airDropCustomer1);
    const tokensAfterDrop2 = await utils.tokenBalanceOf(crowdsale, airDropCustomer2);
    assert.equal(tokensAfterDrop1, tokensBeforeDrop1 + 60);
    assert.equal(tokensAfterDrop2, tokensBeforeDrop2 + 10);
  });

  it("Should be able to get funds after KYC is confirmed after finalization", async () => {
    await crowdsale.updateKYCStatus([KYCCustomerNotConfirmed], true, { from: owner });
    await crowdsale.withdrawTokens({from: KYCCustomerNotConfirmed});
    assert.equal(await utils.tokenBalanceOf(crowdsale, KYCCustomerNotConfirmed), 0);
    assert.isTrue(await token.balanceOf(KYCCustomerNotConfirmed) > 0);
  });

  it("Should be able to get refund in case of crowdsale failed", async () => {
    // deploy
    const failedCrowdsale = await deployCrowdsale();

    // invest
    await utils.invest(web3, failedCrowdsale, failedCrowdsaleCustomer, 1);
    assert.isTrue(await utils.tokenBalanceOf(failedCrowdsale, failedCrowdsaleCustomer) > 0);
    assert.isTrue(!await failedCrowdsale.goalReached());
    const initBalance = await web3.eth.getBalance(failedCrowdsaleCustomer);

    // finalize (not successful)
    await failedCrowdsale.finalize({from: owner});

    // NOTE: Wait till crowdsale is finalized
    await timeout(1000);

    assert.isTrue(await failedCrowdsale.hasClosed());
    assert.isTrue(await failedCrowdsale.isFinalized());

    // refund
    await failedCrowdsale.claimRefund({from: failedCrowdsaleCustomer});
    const finalBalance = await web3.eth.getBalance(failedCrowdsaleCustomer);
    const difference = web3.fromWei(finalBalance.toNumber() - initBalance.toNumber(), 'ether');
    assert.isTrue(0.95 <= difference && difference <= 1);

    try {
      await failedCrowdsale.withdrawTokens({from: failedCrowdsaleCustomer});
      assert.fail("Should not be able to withdraw tokens in case of failed crowdsale & refund");
    } catch (e) {
      const tokenBalance = await token.balanceOf(failedCrowdsaleCustomer);
      assert.equal(tokenBalance.toNumber(), 0);
    }
  });

  it("Should be able to get PARTIAL refund in case of crowdsale failed but some funds used", async () => {
    // deploy
    const failedCrowdsale = await deployCrowdsale();

    // invest
    await utils.invest(web3, failedCrowdsale, failedCrowdsaleCustomer, 1);
    await utils.invest(web3, failedCrowdsale, multiPayingCustomer, 1);
    assert.isTrue(await utils.tokenBalanceOf(failedCrowdsale, failedCrowdsaleCustomer) > 0);
    assert.isTrue(!await failedCrowdsale.goalReached());
    assert.equal(web3.fromWei(await web3.eth.getBalance(failedCrowdsale.address), 'ether').toNumber(), 2);
    const initBalance1 = await web3.eth.getBalance(failedCrowdsaleCustomer);
    const initBalance2 = await web3.eth.getBalance(multiPayingCustomer);

    // owner takes 50% of funds
    await failedCrowdsale.ownerWithdraw(web3.toWei(1, 'ether'), {from: owner});
    assert.equal(web3.fromWei(await web3.eth.getBalance(failedCrowdsale.address), 'ether').toNumber(), 1);

    // finalize (not successful)
    await failedCrowdsale.finalize({from: owner});

    // NOTE: Wait till crowdsale is finalized
    await timeout(1000);

    assert.isTrue(await failedCrowdsale.hasClosed());
    assert.isTrue(await failedCrowdsale.isFinalized());

    // refund one customer
    await failedCrowdsale.claimRefund({from: failedCrowdsaleCustomer});
    const finalBalance1 = await web3.eth.getBalance(failedCrowdsaleCustomer);
    const difference1 = web3.fromWei(finalBalance1.toNumber() - initBalance1.toNumber(), 'ether');
    // NOTE: Key thing here we get only ~0.5 ETH here back
    assert.isTrue(0.49 <= difference1 && difference1 <= 0.5);

    // refund second customer
    await failedCrowdsale.claimRefund({from: multiPayingCustomer});
    const finalBalance2 = await web3.eth.getBalance(multiPayingCustomer);
    const difference2 = web3.fromWei(finalBalance2.toNumber() - initBalance2.toNumber(), 'ether');
    // NOTE: Key thing here we get only ~0.5 ETH here back
    assert.isTrue(0.49 <= difference2 && difference2 <= 0.5);
  });

  it("Should NOT be able to invest after closingTime", async () => {
    // deploy
    const failedCrowdsale = await deployCrowdsale();

    await failedCrowdsale.setClosingTime(utils.now() - 1, {from: owner});
    assert.isTrue(await failedCrowdsale.hasClosed());

    try {
      await utils.invest(web3, failedCrowdsale, failedCrowdsaleCustomer, 1);
      assert.fail("Should NOT be able to invest after closingTime");
    } catch (e) {
    }
  });

  it("Should NOT be able to invest after finalization", async () => {
    // deploy
    const finalizeCrowdsale = await deployCrowdsale();

    await finalizeCrowdsale.setGoalReached(true, {from: owner});
    await finalizeCrowdsale.finalize({from: owner});

    // NOTE: Wait till crowdsale is finalized
    await timeout(1000);

    assert.isTrue(await finalizeCrowdsale.hasClosed());
    assert.isTrue(await finalizeCrowdsale.isFinalized());

    try {
      await utils.invest(web3, finalizeCrowdsale, notKYCCustomer, 1);
      assert.fail("Should NOT be able to invest after finalization");
    } catch (e) {
    }
  });

  async function deployCrowdsale(config) {
    config = config || {};
    const aerumCrowdsale = await AerumCrowdsale.new(
      config.token || token.address,
      config.wallet || owner,
      config.whitelistedRate || 200,
      config.publicRate || 100,
      config.openingTime || utils.now(),
      config.closingTime || utils.now() + 300,
      config.pledgeClosingTime || utils.now() + 100,
      config.kycAmount || 1000 * 100,
      config.etherPriceInUsd || 200 * 100,
      { from: owner }
    );

    // NOTE: We send 8000 tokens. Hard cap will be 80 ETH
    await token.transfer(aerumCrowdsale.address, 8000 * Math.pow(10, 18), {from: owner});

    // NOTE: Wait for deployment to finish
    await timeout(1000);

    return aerumCrowdsale;
  }

  function timeout(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
});
