const { expect } = require("chai");
const { ethers } = require("hardhat");

let voxel, sk721nft, sk1155nft, marketplace;

describe("SuperKluster Marketplace Tests", function() {
  this.beforeEach(async function() {
    [account1, account2, account3, account4] = await ethers.getSigners();
    const VOXEL = await ethers.getContractFactory("Voxel");
    voxel = await VOXEL.deploy();
    await voxel.deployed();

    /* 
    [account1, account2, account3, account4] = await ethers.getSigners();
    const VOXEL = await ethers.getContractFactory("Voxel");
    voxel = await VOXEL.deploy();

    await voxel.deployed();

    console.log("VOXEL Token Address: ", voxel.address);

    const SK721NFT = await ethers.getContractFactory("SK721Collection");
    sk721nft = await SK721NFT.deploy("SuperKluster721", "SK721");
    await sk721nft.deployed();

    console.log("SK721NFT Address: ", sk721nft.address);

    const SK1155NFT = await ethers.getContractFactory("SK1155Collection");
    sk1155nft = await SK1155NFT.deploy("SuperKluster1155", "SK1155");
    await sk1155nft.deployed();

    console.log("SK1155NFT Address: ", sk1155nft.address);

    const MARKET_PLACE = await ethers.getContractFactory("SKMarketPlace");
    marketplace = await MARKET_PLACE.deploy(voxel.address, account1.address, account4.address);
    await marketplace.deployed();

    console.log("Marketplace Address: ", marketplace.address);
    console.log("Admin Signer Address: ", account1.address); */

    const SM = await ethers.getContractFactory("SKMarketPlace");
    const SMV2 = await ethers.getContractFactory("SKMarketPlaceV2");

    const sm = await upgrades.deployProxy(SM, [voxel.address, account1.address, account2.address, account4.address]);
    const sm_upgraded = await upgrades.upgradeProxy(sm.address, SMV2);

    await sm_upgraded.connect(account4).setCounter(5);

    const _count = await sm_upgraded.counter();
    console.log("count: ", _count);    
  })

  it("UseCase105 Test", async function() {
    /* 
    [ 
      account1, // admin key
      account2, // nft creator (seller)
      account3,  // nft buyer
      account4   // team wallet
    ] = await ethers.getSigners();

    // VXL transfer
    await voxel.connect(account1).transfer(account3.address, hre.ethers.utils.parseEther("20000000"));

    // add Item
    let addItem = {
      collection: sk721nft.address,
      tokenId: 1123,
      supply: 1,
      tokenURI: "https://base_uri/url/back.json",
      deadline: 1664582399,
      nonce: 0,
    };

    // add wallet to Trustable
    await sk721nft.connect(account1).addTrusted(marketplace.address);

    // add sk721nft to collection list
    await marketplace.connect(account1).addSKCollection(sk721nft.address);


    let addItemMessageHash = ethers.utils.solidityKeccak256(
        ["address", "address", "uint256", "uint256", "string", "uint256", "uint256"],
        [addItem.collection, account2.address, addItem.tokenId, addItem.supply, addItem.tokenURI, addItem.nonce, addItem.deadline]
    );

    let addItemSignature = await account1.signMessage(ethers.utils.arrayify(addItemMessageHash));
        
      await marketplace.connect(account2).addItem(
        addItem.collection,
        addItem.tokenId,
        addItem.supply,
        addItem.tokenURI,
        addItem.deadline,
        addItemSignature
      );

      console.log("collection balance => ", (await sk721nft.balanceOf(account2.address)));
      // buy
      console.log("buyer balance => ", (await voxel.balanceOf(account3.address)));  
      await voxel.connect(account3).approve(marketplace.address, hre.ethers.utils.parseEther("20000000"));
      await voxel.connect(account2).approve(marketplace.address, hre.ethers.utils.parseEther("20000000"));

      await sk721nft.connect(account2).setApprovalForAll(marketplace.address, true);
      await sk721nft.connect(account3).setApprovalForAll(marketplace.address, true);

      let buyItem = {
        collection: sk721nft.address,
        seller: account2.address,
        tokenId: 1123,
        quantity: 1,
        price: hre.ethers.utils.parseEther("5000"),
        deadline: 1664582399,
        nonce: 0
      };

      let buyItemMessageHash = ethers.utils.solidityKeccak256(
        ["address", "address", "address", "uint256", "uint256", "uint256", "uint256", "uint256"],
        [buyItem.collection, account3.address, account2.address, buyItem.tokenId, buyItem.quantity, buyItem.price, buyItem.nonce, buyItem.deadline]
      );

      let buyItemSignature = await account1.signMessage(ethers.utils.arrayify(buyItemMessageHash));

      await marketplace.connect(account3).buyItem(
        buyItem.collection,
        account2.address,
        buyItem.tokenId,
        buyItem.quantity,
        buyItem.price,
        buyItem.deadline,
        buyItemSignature
      );
      console.log("seller balance => ", (await voxel.balanceOf(account2.address)));
      console.log("buyer balance => ", (await voxel.balanceOf(account3.address)));

      
      let acceptItem = {
        collection: sk721nft.address,
        buyer: account2.address,
        tokenId: 1123,
        quantity: 1,
        price: hre.ethers.utils.parseEther("2000"),
        deadline: 1664582399,
        nonce: 1
      };

      let acceptItemMessageHash = ethers.utils.solidityKeccak256(
        ["address", "address", "address", "uint256", "uint256", "uint256", "uint256", "uint256"],
        [acceptItem.collection, account2.address, account3.address, acceptItem.tokenId, acceptItem.quantity, acceptItem.price, acceptItem.nonce, acceptItem.deadline]
      );

      let acceptItemSignature = await account1.signMessage(ethers.utils.arrayify(acceptItemMessageHash));

      await marketplace.connect(account3).acceptItem(
        acceptItem.collection,
        account2.address,
        acceptItem.tokenId,
        acceptItem.quantity,
        acceptItem.price,
        acceptItem.deadline,
        acceptItemSignature
      );

      console.log("seller balance => ", (await voxel.balanceOf(account3.address)));
      console.log("buyer balance => ", (await voxel.balanceOf(account2.address)));

      let metadataItem = {
        collection: sk721nft.address,
        tokenId: 1123,
        tokenURI: "https://base_uri/url/back_clone.json",
        deadline: 1664582399,
        nonce: 1,    
      };

      let metadataMessageHash = ethers.utils.solidityKeccak256(
        ["address", "address", "uint256", "string", "uint256", "uint256"],
        [metadataItem.collection, account2.address, metadataItem.tokenId, metadataItem.tokenURI, metadataItem.nonce, metadataItem.deadline]
      );
      
      let metadataSignature = await account1.signMessage(ethers.utils.arrayify(metadataMessageHash));
        
      await marketplace.connect(account2).updateItemMetaData(
        metadataItem.collection,
        metadataItem.tokenId,
        metadataItem.tokenURI,
        metadataItem.deadline,
        metadataSignature
      ); */
  })
});