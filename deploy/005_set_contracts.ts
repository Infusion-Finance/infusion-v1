import { DeployFunction } from "hardhat-deploy/types";
import { ChainId, createExecuteWithLog, deployConfig } from "../deploy-helpers";

const deploy: DeployFunction = async ({
  deployments: { deploy, get },
  getNamedAccounts,
  network,
}) => {
  const { deployer } = await getNamedAccounts();

  const chainId = network.config.chainId;

  if (!chainId)
    throw new Error(
      "Hardhat couldn't find network during deployment of PairFactory"
    );

  const config = deployConfig[chainId as ChainId];

  const Router = await get("Router");

  let executeWithLog = createExecuteWithLog(deployments.execute);

  await executeWithLog(
    "PairFactory",
    { from: deployer },
    "initRouter",
    Router.address
  );

  executeWithLog = createExecuteWithLog(deployments.execute);

  await executeWithLog(
    "LockFactory",
    { from: deployer },
    "initRouter",
    Router.address
  );
};


export default deploy;
