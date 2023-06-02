const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers, deployments, network } = require("hardhat");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect, assert } = require("chai");
const {impersonateAcc} = require("../helperHardhat")

describe("Lock", function () {
  async function deployTrade() {
    const getContract = await deployments.get(["TradeGuide"]);
    const _signer = await ethers.getSigner(impersonateAcc);

    const TradeGuide = await ethers.getContractAt(
      "TradeGuide",
      getContract.address,
     _signer
    );

    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [impersonateAcc],
    });




  }
});
