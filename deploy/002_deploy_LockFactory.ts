import { DeployFunction } from "hardhat-deploy/types";

const deploy: DeployFunction = async ({
  deployments: { deploy },

  getNamedAccounts,
}) => {
  const { deployer } = await getNamedAccounts();

  const MAX_LOCK_DAYS = 90;

  await deploy("LockFactory", {
    from: deployer,
    log: true,
    args: [MAX_LOCK_DAYS],
  });
};

deploy.tags = ["main", "LockFactory"];

export default deploy;

