import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // REPLACE THIS with your actual ERC-3475 contract address
  // Or, if you deployed it in the same project, use: (await deployments.get("BondContract")).address
  const BOND_CONTRACT_ADDRESS = "0x5d3DD9f67618b1500f3a03D66921A67dAe09C298";

  console.log(`Deploying Frappucino with Bond Contract: ${BOND_CONTRACT_ADDRESS}...`);

  const frappucino = await deploy("Frappucino", {
    from: deployer,
    args: [BOND_CONTRACT_ADDRESS], // Passes the bond address to the constructor
    log: true,
    waitConfirmations: 1, // Useful for explorer indexing on devnets
  });

  console.log("✅ Frappucino deployed to:", frappucino.address);
};

export default func;
func.tags = ["Frappucino"];
