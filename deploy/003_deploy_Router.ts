import { DeployFunction } from "hardhat-deploy/types";
import { ChainId, deployConfig } from "../deploy-helpers";

const deploy: DeployFunction = async ({
  deployments: { deploy, get },
  network,
  getNamedAccounts,
}) => {
  const { deployer } = await getNamedAccounts();

  if (!network.config.chainId)
    throw new Error(
      "Hardhat couldn't find network during deployment of Router"
    );

  const WETH = deployConfig[network.config.chainId as ChainId]?.WETH;

  const PairFactory = await get("PairFactory");
  const LockFactory = await get("LockFactory");

  await deploy("Router", {
    from: deployer,
    log: true,
    args: [PairFactory.address, LockFactory.address, WETH],
  });
};

deploy.tags = ["main", "Router"];

export default deploy;
