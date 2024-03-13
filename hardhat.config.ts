import '@nomicfoundation/hardhat-ethers'
import '@nomicfoundation/hardhat-verify'
import '@nomicfoundation/hardhat-chai-matchers'
import 'solidity-coverage'
import 'hardhat-dependency-compiler'
import 'hardhat-deploy'
import 'hardhat-gas-reporter'
import 'solidity-docgen';
import 'dotenv'
import '@typechain/hardhat'
import { HardhatUserConfig } from 'hardhat/types'
import { resolve } from "path";
import { config as dotenvConfig } from "dotenv";

dotenvConfig({ path: resolve(__dirname, "./.env") });

const packageJson = require("./package.json");

const config: HardhatUserConfig = {
  networks: {
    baseSepolia: {
      url: "https://base-sepolia.publicnode.com",
      accounts: [process.env.PRIVATE_KEY!],
      chainId: 84532,
    },
    baseGoerli: {
      url: "https://base-goerli.publicnode.com",
      accounts: [process.env.PRIVATE_KEY!],
      chainId: 84531,
    },
    base: {
      url: "https://base.publicnode.com",
      accounts: [process.env.PRIVATE_KEY!],
      chainId: 8453,
    },
    goerli: {
      url: "https://ethereum-goerli.publicnode.com",
      accounts: [process.env.PRIVATE_KEY!],
      chainId: 5,
    },
    sepolia: {
      url: "https://ethereum-sepolia.publicnode.com",
      accounts: [process.env.PRIVATE_KEY!],
      chainId: 11155111,
    },
  },
  solidity: {
    compilers: [
      { version: "0.8.20",
        settings: {
          optimizer: {
          enabled: true,
          runs: 200,
          },
        }
      },
    ]
  },
  etherscan: {
    apiKey: {
      base: process.env.BASE_SCAN_API_KEY!,
      goerli: process.env.GOERLI_SCAN_API_KEY!,
      baseGoerli: process.env.BASE_GOERLI_SCAN_API_KEY!,
      baseSepolia: process.env.BASE_SEPOLIA_SCAN_API_KEY!,
    },
  },

  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  docgen: {},
  paths: {
    deployments: `deployments/${packageJson.version}`,
  },
};

export default config;
