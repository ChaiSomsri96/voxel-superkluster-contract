const hre = require("hardhat");
async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying Voxel token with the account:", deployer.address);

    const SK1155NFT = await hre.ethers.getContractFactory("SK1155Collection");

    
    const sk1155nft = await SK1155NFT.deploy(
        "SuperKluster1155", "SK1155", "0x04ee3A27D77AB9920e87dDc0A87e90144F6a278C"
    );

    /* 
    const sk1155nft = await SK1155NFT.deploy(
        "SuperKluster1155", "SK1155", "0x0c51F87182C3ab3f02B6d848e46CBe64BE4c2edf"
    );

    console.log("sk1155nft deployed to1:", sk1155nft.address); */
        
    await sk1155nft.deployed();

    console.log("sk1155nft deployed to:", sk1155nft.address);
}

main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});