const hre = require("hardhat");
async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying Voxel token with the account:", deployer.address);

    /*
    const marketplace = await hre.ethers.getContractFactory("SKMarketPlace");
    const address = '0x505cFc8A9d04aD2dCf7B398b78e6732448D86E07';
    const MP = await marketplace.attach(address);
    await MP.connect(deployer).addSKCollection("0x03475003834f406cf2573b30844b9385818CdECF"); */

    /* const marketplace = await hre.ethers.getContractFactory("SKMarketPlace");
    const address = '0x62231c17869264b5803243E5759A6eC7DE2B4389';
    const MP = await marketplace.attach(address);

    await MP.connect(deployer).setMarketAddressforNFTCollection("0xf5753aA0757088CF243Ca798299DCf43C4aA584b", "0x505cFc8A9d04aD2dCf7B398b78e6732448D86E07"); */


    const marketplace = await hre.ethers.getContractFactory("SKMarketPlace");
    const address = '0x0c51F87182C3ab3f02B6d848e46CBe64BE4c2edf';
    const MP = await marketplace.attach(address);
    await MP.connect(deployer).addSKCollection("0xeec38ADD9CABEF2f02A2aDd180ff634755332054");
}



main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});