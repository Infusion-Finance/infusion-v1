import { DeployFunction } from "hardhat-deploy/types";

const deploy: DeployFunction = async ({
  deployments: { deploy },

  getNamedAccounts,
}) => {
  const { deployer } = await getNamedAccounts();

  await deploy("PairFactory", {
    from: deployer,
    log: true,
    args: [],
  });
};

deploy.tags = ["main", "PairFactory"];

export default deploy;

