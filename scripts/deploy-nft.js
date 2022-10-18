const hre = require("hardhat");
async function main() {

    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // We get the contract to deploy
    const Qatar_stars = await hre.ethers.getContractFactory("NewStar");
    const qatar_stars = await Qatar_stars.deploy("NewStar NFT", "New_Stars", "https://voxelxrinkeby.mypinata.cloud/ipfs/QmaHivCXXRoKRjtsXZFZjqrkWzBRfioxB1VTQ1CarYunML/");
    
    await qatar_stars.deployed();

    console.log("Qatar_stars deployed to:", qatar_stars.address);
}
  
main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});