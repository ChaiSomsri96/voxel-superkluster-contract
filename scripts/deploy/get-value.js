const hre = require("hardhat");
async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("check_address:", deployer.address);

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
    const address = '0x04ee3A27D77AB9920e87dDc0A87e90144F6a278C';
    const MP = await marketplace.attach(address);
    console.log("value====>", (await MP.connect(deployer).getClaimRoyalty()));
}



main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});