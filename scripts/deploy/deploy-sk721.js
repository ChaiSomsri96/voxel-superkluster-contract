const hre = require("hardhat");
async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying Voxel token with the account:", deployer.address);

    const SK721 = await hre.ethers.getContractFactory("SK721Collection");

    // goerli
    const sk721 = await SK721.deploy(
        "SuperKluster721", "SK721", "0x04ee3A27D77AB9920e87dDc0A87e90144F6a278C"
    );

    /* mainnet
    const sk721 = await SK721.deploy(
        "SuperKluster721", "SK721", "0x0c51F87182C3ab3f02B6d848e46CBe64BE4c2edf"
    );

    console.log("sk721 deployed to1:", sk721.address); */

    await sk721.deployed();

    console.log("sk721 deployed to:", sk721.address);
}

main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});