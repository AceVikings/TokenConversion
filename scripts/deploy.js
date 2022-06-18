// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { parseEther } = require("ethers/lib/utils");
const { ethers } = require("hardhat");
const hre = require("hardhat");

async function main() {
  // We get the contract to deploy
  console.log("\x1b[1m", "Deploying xGrav token");
  const XGrav = await hre.ethers.getContractFactory("Token1");
  const xgrav = await XGrav.deploy();
  console.log("\x1b[36m%s\x1b[0m", "xGrav deployed at:", xgrav.address);
  console.log("Minting 1000 tokens to owner address");
  await xgrav.mint(parseEther("1000"));
  console.log("Tokens minted");
  await hre.run("verify:verify", {
    address: xgrav.address,
    contract: "contracts/Mocks/Token1.sol:Token1",
    network: "harmonytestnet",
  });
  console.log("\n");
  console.log("\x1b[1m", "Deploying Grav contract");
  const Grav = await hre.ethers.getContractFactory("Token2");
  const grav = await Grav.deploy();
  console.log("\x1b[36m%s\x1b[0m", "Grav contract deployed at:", grav.address);
  console.log("Minting 1000 tokens to owner address");
  await grav.mint(parseEther("1000"));
  console.log("Tokens minted");
  await hre.run("verify:verify", {
    address: grav.address,
    contract: "contracts/Mocks/Token2.sol:Token2",
    network: "harmonytestnet",
  });
  console.log("\n");
  console.log("\x1b[1m", "Deploying Puff token");
  const NFT = await hre.ethers.getContractFactory("NFT");
  const nft = await NFT.deploy();
  console.log("\x1b[36m%s\x1b[0m", "Puff deployed at:", nft.address);
  console.log("Minting 100 tokens to owner address");
  await nft.mint(100);
  console.log("Tokens minted");
  await hre.run("verify:verify", {
    address: nft.address,
    contract: "contracts/Mocks/NFT.sol:NFT",
    network: "harmonytestnet",
  });
  console.log("\n");
  console.log("\x1b[1m", "Deploying Voyager contract");
  const Greeter = await hre.ethers.getContractFactory("Voyager1");
  const greeter = await Greeter.deploy(
    nft.address,
    xgrav.address,
    grav.address
  );
  await greeter.deployed();
  console.log("\x1b[36m%s\x1b[0m", "Voyager deployed to:", greeter.address);
  await hre.run("verify:verify", {
    address: greeter.address,
    constructorArguments: [nft.address, xgrav.address, grav.address],
    contract: "contracts/Voyager1.sol:Voyager1",
    network: "harmonytestnet",
  });
  console.log(
    "\x1b[1m",
    "Transferring 1000 Grav from user wallet to Voyager contract"
  );
  await grav.transfer(greeter.address, parseEther("1000"));
  console.log("Voyager1 set and ready to use");

  console.log("Summary");
  console.log("xGrav Address: ", xgrav.address);
  console.log("Grav Address", grav.address);
  console.log("NFT Address", nft.address);
  console.log("Voyager address", greeter.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
