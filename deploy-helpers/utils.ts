import { DeploymentsExtension } from "hardhat-deploy/types";

export const createExecuteWithLog =
  (execute: DeploymentsExtension["execute"]) =>
  async (...args: Parameters<DeploymentsExtension["execute"]>) => {
    const [contractName, , methodName] = args;

    console.log(`executing "${contractName}.${methodName}"`);

    const receipt = await execute.apply(execute, args);

    console.log(
      `tx "${contractName}.${methodName}": ${receipt.transactionHash}`
    );

    return receipt;
  };
