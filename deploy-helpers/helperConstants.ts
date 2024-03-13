import { ethers } from "ethers";

export const TOKEN_DECIMALS = ethers.BigNumber.from("10").pow(
  ethers.BigNumber.from("18")
);
export const MILLION = ethers.BigNumber.from("10").pow(
  ethers.BigNumber.from("6")
);

export const FOUR_MILLION = ethers.BigNumber.from("4")
  .mul(MILLION)
  .mul(TOKEN_DECIMALS);
export const TEN_MILLION = ethers.BigNumber.from("10")
  .mul(MILLION)
  .mul(TOKEN_DECIMALS);
export const TWENTY_MILLION = ethers.BigNumber.from("20")
  .mul(MILLION)
  .mul(TOKEN_DECIMALS);
export const PARTNER_MAX = ethers.BigNumber.from("78")
  .mul(MILLION)
  .mul(TOKEN_DECIMALS);
