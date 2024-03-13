type DeployConfig = {
  // Tokens:
  WETH: string;
  USDC: string;

  // Addresses
  teamEOA: string;
  teamMultisig: string;
};

export enum ChainId {
  Mainnet = 1,
  Ropsten = 3,
  Rinkeby = 4,
  Goerli = 5,
  Sepolia = 11155111,
  ThunderCoreTestnet = 18,
  Canto = 7700,
  CantoTestnet = 740,
  Cronos = 25,
  CronosTestnet = 338,
  Kovan = 42,
  BSC = 56,
  BSCTestnet = 97,
  xDai = 100,
  Gnosis = 100,
  ThunderCore = 108,
  Polygon = 137,
  Theta = 361,
  ThetaTestnet = 365,
  Moonriver = 1285,
  Moonbeam = 1284,
  Mumbai = 80001,
  Harmony = 1666600000,
  Palm = 11297108109,
  PalmTestnet = 11297108099,
  Localhost = 1337,
  Hardhat = 31337,
  Fantom = 250,
  FantomTestnet = 4002,
  Avalanche = 43114,
  AvalancheTestnet = 43113,
  Celo = 42220,
  CeloAlfajores = 44787,
  Songbird = 19,
  Flare = 14,
  FlareCostonTestnet = 16,
  FlareCoston2Testnet = 114,
  MoonbaseAlpha = 1287,
  OasisEmerald = 42262,
  OasisEmeraldTestnet = 42261,
  Stardust = 588,
  Andromeda = 1088,
  OptimismGoerli = 420,
  OptimismKovan = 69,
  Optimism = 10,
  Arbitrum = 42161,
  ArbitrumRinkeby = 421611,
  ArbitrumGoerli = 421613,
  Aurora = 1313161554,
  AuroraTestnet = 1313161555,
  Velas = 106,
  VelasTestnet = 111,
  ZkSync = 324,
  ZkSyncTestnet = 280,
  ArbitrumRedditTestnet = 5391184,
  RootstockMainnet = 30,
  RootstockTestnet = 31,
  KlaytnTestnet = 1001,
  Klaytn = 8217,
  BaseGoerli = 84531,
  Base = 8453,
  ScrollAlpha = 534353,
  ScrollSepolia = 534351,
  Linea = 59144,
  LineaTestnet = 59140,
  ArbitrumNova = 42170,
  MantleTestnet = 5001,
  Kroma = 255,
  KromaSepolia = 2358,
  BaseSepolia = 84532,
}

export type DeployConfigs = {
  [key in ChainId]: DeployConfig;
};
