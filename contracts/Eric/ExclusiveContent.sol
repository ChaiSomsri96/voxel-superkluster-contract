//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract ExclusiveContent {
    // Struct for storing a piece of exclusive content
    struct Content {
        uint256 id;
        string name;
        string description;
        string url;
        address owner;
        bool isPublic;
        uint256 price;
        uint256 expirationTime;
        bool isSold;
        mapping (address => bool) authorizedBuyers;
        uint256 totalReviews;
        uint256 totalRating;
    }

    // Mapping to store the pieces of exclusive content
    mapping (uint256 => Content) public contents;

    // Array to store the IDs of the pieces of exclusive content
    uint256[] public contentIDs;

    // Mapping to store the buyers for each piece of exclusive content
    mapping (uint256 => address[]) public buyers;

    // Event to be triggered when a new piece of content is added
    event NewContent(uint256 id, string name, string description, string url, address owner);
    
    // Event to be triggered when a piece of content is purchased
    event ContentPurchased(uint256 id, address buyer);
    
    // Event to be triggered when a piece of content is sold
    event ContentSold(uint256 id, address seller);
    
    // Event to be triggered when the expiration time of a piece of content is renewed
    event ContentRenewed(uint256 id, uint256 newExpirationTime);
    
    // Event to be triggered when access to a piece of content is revoked
    event AccessRevoked(uint256 id, address buyer);
    
    // Event to be triggered when a user reviews the content
    event ContentReview(uint256 id, address reviewer, uint256 rating);
    
    // Event to be triggered when a user requests a refund
    event RefundRequested(uint256 id, address requester);

    // The address that will have control over the contract
    address public owner;

    // Function to update the visibility of a piece of exclusive content
    function updateVisibility(uint256 _id, bool _isPublic) public onlyOwner {
        contents[_id].isPublic = _isPublic;
    }

    // Function to add a new piece of exclusive content
    function addContent(string memory _name, string memory _description, string memory _url, uint256 _price, uint256 _expirationTime) public onlyOwner {
        uint256 newID = contentIDs.push(0) - 1;
        contents[newID] = Content(newID, _name, _description, _url, msg.sender, true, _price, _expirationTime, false, 0, 0);
        emit NewContent(newID, _name, _description, _url, msg.sender);
    }

    // Function to purchase a piece of exclusive content
    function purchaseContent(uint256 _id) public payable {
        require(contents[_id].isPublic == true, "The content is not available for purchase");
        require(contents[_id].price <= msg.value, "The provided value is less than the price of the content");
        require(contents[_id].isSold == false, "The content has already been sold");
        require(now <= contents[_id].expirationTime, "The content is no longer available for purchase");
        
        contents[_id].isSold = true;
        contents[_id].authorizedBuyers[msg.sender] = true;
        contents[_id].owner = msg.sender;
        buyers[_id].push(msg.sender);
        contents[_id].expirationTime = now + 30 days;
        
        emit ContentPurchased(_id, msg.sender);
        emit ContentSold(_id, contents[_id].owner);
    }

    // Function to renew the expiration time of a piece of exclusive content
    function renewExpirationTime(uint256 _id) public onlyOwner {
        contents[_id].expirationTime = now + 30 days;
        emit ContentRenewed(_id, contents[_id].expirationTime);
    }

    // Function to revoke access to a piece of exclusive content
    function revokeAccess(uint256 _id, address _buyer) public onlyOwner {
        require(contents[_id].authorizedBuyers[_buyer] == true, "The provided address is not an authorized buyer");
        contents[_id].authorizedBuyers[_buyer] = false;
        emit AccessRevoked(_id, _buyer);
    }
 
    // Function to review a piece of exclusive content
    function reviewContent(uint256 _id, uint256 _rating) public {
        require(contents[_id].authorizedBuyers[msg.sender] == true, "The caller must be an authorized buyer to leave a review");
        contents[_id].totalReviews++;
        contents[_id].totalRating += _rating;
        emit ContentReview(_id, msg.sender, _rating);
    }
 
    // Function to request a refund for a piece of exclusive content
    function requestRefund(uint256 _id) public {
        require(contents[_id].authorizedBuyers[msg.sender] == true, "The caller must be an authorized buyer to request a refund");
        require(now <= contents[_id].expirationTime, "The content must still be available for purchase to request a refund");
    
        emit RefundRequested(_id, msg.sender);
        msg.sender.transfer(contents[_id].price);
    }
 
    // Modifier to only allow the contract owner to call a function
    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }
}
// Function to perform an airdrop to a specific user
function airdrop(address _user) public
function airdrop(address[] memory _recipients) public {
require(msg.sender == owner, "Only the owner can initiate an airdrop");
for (uint256 i = 0; i < _recipients.length; i++) {
_recipients[i].transfer(airdropAmount);
 
function getContentCount() public view returns (uint256) {
	return contentIDs.length;
}
 
}
}