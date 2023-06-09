const { ethers, deployments, network } = require("hardhat");
const { networkConfig, impersonateAcc } = require("../helperHardhat");
const {
  impersonateAccount,
} = require("@nomicfoundation/hardhat-network-helpers");
const abi = require("../constants/abi.json");

async function main() {
  await deployments.fixture(["swap"]);
  const chain = network.config.chainId;
  const signer = await ethers.getSigner(impersonateAcc);
  const dai = networkConfig[chain]["dai"];
  const weth = networkConfig[chain]["weth"];
  const wethValue = ethers.utils.parseEther("0.5");

  const contractAddress = await deployments.get("SwapTest");

  const tradeGuideContract = await ethers.getContractAt(
    "SwapTest",
    contractAddress.address,
    signer
  );
  await getBalance(dai, signer, signer.address, "dai");

  await approveERC20(
    weth,
    signer,
    signer.address,
    "weth",
    tradeGuideContract.address,
    wethValue
  );
  console.log("before swapping tokens ");

  const swapFunction = await tradeGuideContract.swapExactInputSingle(wethValue);
  const res = await swapFunction.wait();
  console.log("swapped ");

  await getBalance(weth, signer, signer.address, "weth");
  await getBalance(dai, signer, signer.address, "dai");
}
async function approveERC20(address, signer, user, name, spender, value) {
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [impersonateAcc],
  });
  const token = new ethers.Contract(address, abi, signer);
  await getBalance(address, signer, user, name);
  const approve = await token.approve(spender, value);
  const res = await approve.wait();
  console.log("approved");
}

async function getBalance(address, signer, user, name) {
  const token = new ethers.Contract(address, abi, signer);
  const balance = await token.balanceOf(user);
  console.log(`${user} has ${balance} of ${name}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
