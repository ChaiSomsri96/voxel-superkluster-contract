const hre = require("hardhat");
async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying Voxel token with the account:", deployer.address);

    const marketplace = await hre.ethers.getContractFactory("SKMarketPlace");
    const address = '0x04ee3a27d77ab9920e87ddc0a87e90144f6a278c';
    const MP = await marketplace.attach(address);
    await MP.connect(deployer).setServiceFee(100);
}



main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});