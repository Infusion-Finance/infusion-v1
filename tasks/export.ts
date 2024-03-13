import glob from "fast-glob";
import fs from "fs";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import path from "path";

async function main(hre: HardhatRuntimeEnvironment) {
  const { config } = hre;
  const deploymentPath = config.paths.deployments;

  const dirs = await glob(`${deploymentPath}/*`, { onlyDirectories: true });
  const output: Record<string, any> = {};

  for (const dir of dirs) {
    const chainId = fs.readFileSync(
      path.resolve(path.join(dir, ".chainId")),
      "utf8"
    );

    const files = await glob(`${dir}/*.json`);

    const contracts = files.reduce((acc, file) => {
      const json = fs.readFileSync(file, "utf8");
      const { address, receipt } = JSON.parse(json);
      const name = path.basename(file, ".json");
      acc[name] = { address, blockNumber: receipt.blockNumber };
      return acc;
    }, {} as Record<string, { address: string; blockNumber: number }>);

    output[chainId] = contracts;
  }

  fs.writeFileSync(
    path.resolve(path.join(process.cwd(), "dist", "deployments.json")),
    JSON.stringify(output, null, 2)
  );
}

export default main;
