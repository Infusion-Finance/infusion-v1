import { DeployFunction } from "hardhat-deploy/types";

const deploy: DeployFunction = async ({
  deployments: { deploy, get },
  getNamedAccounts,
}) => {
  const { deployer } = await getNamedAccounts();
  const Router = await get("Router");

  await deploy("InfusionLibrary", {
    from: deployer,
    log: true,
    args: [Router.address],
  });
};

deploy.tags = ["main", "InfusionLibrary"];

export default deploy;
