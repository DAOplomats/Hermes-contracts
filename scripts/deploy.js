// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const contract = await hre.ethers.deployContract(
    "HermesProxyFactory",
    [
      "0xd44390C5f4e3558Be11BbDEb9c3193b6f4DFf8c4",
      "0xd44390C5f4e3558Be11BbDEb9c3193b6f4DFf8c4",
      "0xd44390C5f4e3558Be11BbDEb9c3193b6f4DFf8c4",
      "0x0000000000000000000000000000000000000000000000000000000000000001",
    ],
    {
      gasLimit: 10000000,
    }
  );

  console.log("Contract address:", await contract.getAddress());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
