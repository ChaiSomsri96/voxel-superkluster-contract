const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Giveaway with the account:", deployer.address);

    const qstar = await hre.ethers.getContractFactory("NewStar");
    const address = '0x1961590C5458c85d35a7151f2FA368bDb030C957';
    
    const Qatar = await qstar.attach(address);
    
    await Qatar.connect(deployer).mintItems(1, 10);
    // await Qatar.connect(deployer).transferOwnership("0x588D83E1a2CE7C3D859e06AFc0e98e1D20CC6473");
}

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});