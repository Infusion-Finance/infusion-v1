import { ChainId, DeployConfigs } from "./types";

export const deployConfig: Partial<DeployConfigs> = {
  [ChainId.Base]: {
    WETH: "0x4200000000000000000000000000000000000006",
  },
  [ChainId.BaseSepolia]: {
    WETH: "0xF0372016fd3708898dc600bcC0e6b7350Ba17864",
    USDC: "0x31d57a8a4BC4031E6fcE28Bf658Ade7679b4d798",
  },
  [ChainId.BaseGoerli]: {
    WETH: "0xbEBA8Db9af905e96132FF410Bb9dC1647412f0ce",
    USDC: "0xb5A0c827E9d840CE49C426Da839685727B374590",
  },
  [ChainId.Sepolia]: {
    WETH: "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9",
    USDC: "0x31d57a8a4BC4031E6fcE28Bf658Ade7679b4d798",
  },
};
