//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/token/ERC721/ERC721Full.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/contracts/exchange/AtomicSwap.sol";

contract VoxelToken is ERC721Full {
    using SafeMath for uint256;
    address public voxelMarketplace;
    address public voxelX;
    address public voxelXFeeCollector;
    mapping(address => uint256) public artistRoyalties;

    constructor() public {
	    voxelMarketplace = msg.sender;
    }

    /**
     * @dev Allows the artist to set their own royalty percentage for secondary sales
     * @param _artist The address of the artist
     * @param _royaltyPercentage The percentage of the sale price to be paid as a royalty
     */
    function setArtistRoyalty(address _artist, uint256 _royaltyPercentage) public {
        require(msg.sender == voxelMarketplace, "Only the Voxel marketplace can set artist royalties.");
        artistRoyalties[_artist] = _royaltyPercentage;
    }

    /**
     * @dev Buys an NFT and pays the fee and artist royalty
     * @param _nftId The ID of the NFT to be bought
     * @param _price The price of the NFT
     */
    function buyNFT(uint256 _nftId, uint256 _price) public {
        require(msg.sender == ownerOf(_nftId), "The msg.sender is not the owner of the NFT.");

        // Create an atomic swap for the NFT
        AtomicSwap.create(address(this), _price, voxelX, msg.sender);

        // Wait for the swap to be completed
        AtomicSwap.assert({ from: msg.sender });

        // Calculate the fee and artist royalty
        uint256 fee = _price.mul(15).div(1000); // 1.5% fee
        address artist = ownerOf(_nftId);
        uint256 artistRoyalty = _price.mul(artistRoyalties[artist]).div(100); // artist's defined royalty percentage
        
        // Pay the fee and artist royalty
        voxelXFeeCollector.transfer(fee);
        artist.transfer(artistRoyalty);

        // Send the remaining ether to the NFT owner
        address nftOwner = ownerOf(_nftId);
        nftOwner.transfer(_price.sub(fee).sub(artistRoyalty));

        // Transfer the NFT to the buyer
        super._transfer(msg.sender, _nftId);
    }

    /**
     * @dev Sells an NFT and pays the fee and artist royalty
     * @param _nftId The ID of the NFT to be sold
     * @param _price The price of the NFT
     */
    function sellNFT(uint256 _nftId, uint256 _price) public {
        require(msg.sender == ownerOf(_nftid), "The msg.sender is not the owner of the NFT.");

        // Calculate the fee and artist royalty
        uint256 fee = _price.mul(15).div(1000); // 1.5% fee
        address artist = ownerOf(_nftId);
        uint256 artistRoyalty = _price.mul(artistRoyalties[artist]).div(100); // artist's defined royalty percentage

        // Pay the fee and artist royalty
        voxelXFeeCollector.transfer(fee);
        artist.transfer(artistRoyalty);

        // Send the remaining ether to the NFT buyer
        msg.sender.transfer(_price.sub(fee).sub(artistRoyalty));

        // Transfer the NFT to the buyer
        super._transfer(msg.sender, _nftId);
    }

    /**
     * @dev Trades two NFTs and pays the fee and artist royalties
     * @param _nftId1 The ID of the first NFT to be traded
     * @param _nftId2 The ID of the second NFT to be traded
     * @param _price1 The price of the first NFT
     * @param _price2 The price of the second NFT
     */
    function tradeNFTs(uint256 _nftId1, uint256 _nftId2, uint256 _price1, uint256 _price2) public {
        require(msg.sender == ownerOf(_nftId1), "The msg.sender is not the owner of the first NFT.");
        require(ownerOf(_nftId2) != address(0), "The second NFT does not exist.");

        // Calculate the fee and artist royalties
        uint256 fee1 = _price1.mul(15).div(1000); // 1.5% fee
        uint256 fee2 = _price2.mul(15).div(1000); // 1.5% fee

        address artist1 = ownerOf(_nftId1);
        address artist2 = ownerOf(_nftId2);

        uint256 artistRoyalty1 = _price1.mul(artistRoyalties[artist1]).div(100); // artist's defined royalty percentage
	    uint256 artistRoyalty2 = _price2.mul(artistRoyalties[artist2]).div(100); // artist's defined royalty percentage

        // Pay the fee and artist royalties
        voxelXFeeCollector.transfer(fee1.add(fee2));
        artist1.transfer(artistRoyalty1);
        artist2.transfer(artistRoyalty2);

        // Send the remaining ether to the NFT buyers
        address nftOwner2 = ownerOf(_nftId2);
        msg.sender.transfer(_price2.sub(fee2).sub(artistRoyalty2));
        nftOwner2.transfer(_price1.sub(fee1).sub(artist
    }
}

contract TokenSwap {
	mapping(address => mapping(address => uint256)) public allowance;
 
	// Fallback function that is called when someone tries to send ether to this contract
	function() external payable {
    	// Do nothing
	}
 
	// Function to approve an address to spend a certain amount of a token
	function approve(address tokenAddress, address spender, uint256 amount) public returns (bool) {
    	ERC20 token = ERC20(tokenAddress);
        require(token.transferFrom(msg.sender, spender, amount));
        allowance[msg.sender][spender] = amount;
    	return true;
	}
 
	// Function to check if an address has enough approved balance of a certain token
	function checkAllowance(address tokenAddress, address owner, address spender, uint256 amount) public view returns (bool) {
    	ERC20 token = ERC20(tokenAddress);
    	return (token.allowance(owner, spender) >= amount && allowance[owner][spender] >= amount);
	}
 
	// Function to buy an NFT using a token
	function buyNFT(address tokenAddress, address nftAddress, uint256 tokenId) public returns (bool) {
    	ERC721 nft = ERC721(nftAddress);
        require(nft.ownerOf(tokenId) != address(0));
        require(checkAllowance(tokenAddress, msg.sender, address(this), nft.getPrice(tokenId)));
        require(nft.transferFrom(msg.sender, address(this), tokenId));
    	// Perform the token swap to voxel
    	address voxelAddress = 0x...;
    	ERC20 voxel = ERC20(voxelAddress);
        voxel.transfer(nft.getArtist(tokenId), nft.getPrice(tokenId));
    	return true;
	}
 
	// Function to sell an NFT for a token
	function sellNFT(address tokenAddress, address nftAddress, uint256 tokenId) public returns (bool) {
    	ERC721 nft = ERC721(nftAddress);
        require(nft.ownerOf(tokenId) == address(this));
    	// Perform the token swap to the specified token
    	ERC20 token = ERC20(tokenAddress);
        token.transfer(msg.sender, nft.getPrice(tokenId));
        require(nft.transferFrom(address(this), msg.sender, tokenId));
    	return true;
	}
}
