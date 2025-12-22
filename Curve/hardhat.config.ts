import type { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    hardhat:{
      forking: {
        url: "https://eth-mainnet.g.alchemy.com/v2/c4KikJbthtWDAlrUE2MuRTDUrSuzmnsq",
        // url: process.env.MAINNET_RPC_URL!,
        // blockNumber: 19000000,
      },
      gasPrice: 20_000_000_000,
    }
  }
};

export default config;
