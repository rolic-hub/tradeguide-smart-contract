const { network } = require("hardhat");
const { networkConfig } = require("../helperHardhat");
const { ethers } = require("ethers");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const chain = network.config.chainId;
  let arguments = [
    networkConfig[chain]["swapRouter"],
    networkConfig[chain]["linkToken"],
    networkConfig[chain]["registrar "],
    networkConfig[chain]["aaveOracle"],
    networkConfig[chain]["registry"],
  ];
  log(
    "----------------------------------------------------------------------------"
  );

  await deploy("TradeGuide", {
    from: deployer,
    args: arguments,
    log: true,
    //gasLimit: 9000000
  });

  log(
    "----------------------------------deployed aave contract ---------------------------"
  );
};

module.exports.tags = ["all"];
