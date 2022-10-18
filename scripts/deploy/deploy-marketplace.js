const hre = require("hardhat");
async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying Marketplace with the account:", deployer.address);   

    let adminWallet = new ethers.Wallet("0xcd6d86b3c0d01a494cd7a96cac17b411569ca56becc4a2859d96f7b2b8abb665");

    const MARKETPLACE = await hre.ethers.getContractFactory("SKMarketPlace");

    // goerli 
    /*
    const marketplace = await MARKETPLACE.deploy(
        "0x69a0C61Df0ea2d481696D337A09A3e2421a06051",   // vxlToken
        adminWallet.address,  // signer   "0xD7A28a4A511592d29397819e9b816DEC55157Eca"
        "0xe14EF70397Cb95C46762B83a39894638B4d7CaD1",   // TeamWallet (Account2)
        "0x9EBFaA559d28cDB57bE1C42e06AC65e16BF72A19"  //_timeLockController (Account5)
    ); */
        

    const marketplace = await hre.upgrades.deployProxy(MARKETPLACE, [
        "0x69a0C61Df0ea2d481696D337A09A3e2421a06051",
        adminWallet.address,
        "0x500A1a96369F7D57Fed2117Ce046fBe8b373f017",
        "0x9802280F6999b7a496b8d7B5772A9683756Fc706"
    ]);


    await marketplace.deployed();

    // mainnet

    /* 
    const marketplace = await MARKETPLACE.deploy(
        "0x16CC8367055aE7e9157DBcB9d86Fd6CE82522b31", // vxlToken
        adminWallet.address, // signer   0xD7A28a4A511592d29397819e9b816DEC55157Eca
        "0x700365603b06069a38e39BB06d6F661764c28A89", // TeamWallet (Account2)
        "0xECe4D4681dce96471b1866dE4D06A4beaB789720" //_timeLockController (Account5)
    );

    console.log("marketplace address", marketplace.address);

    await marketplace.deployed(); */

    console.log("marketplace deployed to:", marketplace.address);
}

main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
});