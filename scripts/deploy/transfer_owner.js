const hre = require("hardhat");
async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Test with this account:", deployer.address);

    const reveal = await hre.ethers.getContractFactory("RevealNFT");
    const address = '0x32f13a0b27FBD4c742A7Ec01D175E7281821Fd66';
    const REVEAL = await reveal.attach(address);

    await REVEAL.connect(deployer).transferOwnership("0xe9fDf1cA6B8bDbe2f30eFc59c4590C84576381cA");
}



main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});