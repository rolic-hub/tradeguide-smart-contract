require("@nomicfoundation/hardhat-toolbox")
require("@nomiclabs/hardhat-etherscan")
require("@nomiclabs/hardhat-ethers")
require("solidity-coverage")
require("hardhat-gas-reporter")
require("hardhat-deploy")
require("dotenv").config()

const POLYGON_MAINNET_API = process.env.POLYGON_ALCHEMY_API
const MUMBAI_API = process.env.MUMBAI_ALCHEMY_API
const PRIVATE_KEY = process.env.PRIVATE_KEY

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: {
        compilers: [
            {
                version: "0.8.10",
            }
        ],
    },
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            chainId: 31337,
            saveDeployments: true,
            forking: {
                url: POLYGON_MAINNET_API
            },
        },
        localhost: {
            chainId: 31337,
        },
       
        mumbai: {
            url: MUMBAI_API,
            chainId: 80001,
            saveDeployments: true,
            accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
        },
        polygonMainnet: {
            url: POLYGON_MAINNET_API,
            chainId: 137,
            accounts: PRIVATE_KEY !== undefined ? [PRIVATE_KEY] : [],
        },
    },
    etherscan: {
        apiKey: {},
    },
    gasReporter: {
        enabled: false,
        currency: "USD",
        outputFile: "gas-report.txt",
        noColors: true,
    },
    mocha: {
        timeout: 500000,
    },
    namedAccounts: {
        deployer: {
            default: 0, // here this will by default take the first account as deployer
            1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
        },
    },
}


