function invest(web3, contract, from, ether) {
  return web3.eth.sendTransaction({
    from: from,
    to: contract.address,
    value: web3.toWei(ether, 'ether'),
    gas: 2000000
  });
}

async function weiRaised(crowdsale) {
  const wei = await crowdsale.weiRaised();
  return wei.toNumber();
}

async function usdRaised(crowdsale) {
  const wei = await crowdsale.usdRaised();
  return wei.toNumber();
}

async function pledgeTotal(crowdsale) {
  const tokens = await crowdsale.pledgeTotal();
  return tokens.toNumber();
}

async function weiInvested(crowdsale, address) {
  const wei = await crowdsale.weiInvested(address);
  return wei.toNumber();
}

async function tokenCap(crowdsale) {
  const wei = await crowdsale.tokenCap();
  return wei.toNumber();
}

async function tokenBalanceOf(crowdsale, account) {
  const wei = await crowdsale.balanceOf(account);
  return wei.toNumber();
}

async function pledgeOf(crowdsale, account) {
  const wei = await crowdsale.pledgeOf(account);
  return wei.toNumber();
}

async function isKYCRequired(crowdsale, account) {
  const required = await crowdsale.isKYCRequired(account);
  return required.valueOf();
}

function now() {
  return Math.floor(new Date().getTime() / 1000);
}

module.exports = {
  invest,
  weiRaised,
  usdRaised,
  weiInvested,
  tokenCap,
  tokenBalanceOf,
  pledgeOf,
  pledgeTotal,
  isKYCRequired,
  now
};