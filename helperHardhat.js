const networkConfig = {
  31337: {
    name: "localhost",
    linkToken: "0xb0897686c545045aFc77CF20eC7A532E3120E0F1",
    swapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
    aaveOracle: "0xb023e699F5a33916Ea823A16485e259257cA8Bd1",
    registry: "0x02777053d6764996e594c3E88AF1D58D5363a2e6",
    registrar: "0xDb8e8e2ccb5C033938736aa89Fe4fa1eDfD15a1d",
    dai: "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063",
    weth: "0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",

   
  },

  80001: {
    name: "polygon mumbai",
    linkToken: "0x326C977E6efc84E512bB9C30f76E30c160eD06FB",
    swapRouter: "0xE592427A0AEce92De3Edee1F18E0157C05861564",
    registry: "0xE16Df59B887e3Caa439E0b29B42bA2e7976FD8b2",
    registrar: "0x57A4a13b35d25EE78e084168aBaC5ad360252467"
  },
};

const impersonateAcc = "0xc58Bb74606b73c5043B75d7Aa25ebe1D5D4E7c72"

module.exports = {
  networkConfig,
  impersonateAcc
};
