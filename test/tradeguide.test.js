const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers, deployments, network } = require("hardhat");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect, assert } = require("chai");
const { impersonateAcc } = require("../helperHardhat");

describe("TradeGuide test", function () {
  let getContract, _signer, TradeGuide;

  beforeEach(async () => {
    getContract = await deployments.get("TradeGuide"); // _signer = await ethers.getSigner(impersonateAcc);

    TradeGuide = await ethers.getContractAt("TradeGuide", getContract.address);
  });
  describe("Checking default params", () => {
    it("should check the default parameters of the smart contract ", async () => {
      const checkUser = await TradeGuide.users();
      const trades = await TradeGuide.totalOfTrades();
      const tradesArray = await TradeGuide.getTrades();
      assert.equal(checkUser.toString(), "0");
      assert.equal(trades.toString(), "0");
      assert.equal(tradesArray.length.toString(), "0");
    });
  });
  

  // await network.provider.request({
  //   method: "hardhat_impersonateAccount",
  //   params: [impersonateAcc],
  // });
});
