const hre = require("hardhat");
async function main() {
    
        const [deployer] = await hre.ethers.getSigners();
        console.log("Deploying Reveal NFT with the account:", deployer.address);
        const REVEAL = await hre.ethers.getContractFactory("RevealNFT");

        console.log("REVEAL1:    ");

        const reveal = await REVEAL.deploy(
            "RevealNFT", "RNFT", ""
        );

        console.log("REVEAL2:    ");

        await reveal.deployed();
        console.log("reveal deployed to:", reveal.address);
    
}

main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});