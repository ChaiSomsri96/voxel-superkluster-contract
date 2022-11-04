// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/interfaces/IERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ArtistRoyalties is IERC2981, IERC721Receiver, IERC1155Receiver {
    using SafeMath for uint256;
    using Address for address;

    // Variables
    address private _owner;
    address private _token;
    uint256 private _royaltyFee;

    mapping(address => bool) private _isMarketplaceOwner;
    mapping(address => bool) private _isArtist;
    mapping(address => bool) private _isBuyer;

    struct RoyaltyDistribution {
        address artist;
        uint256 percentage;
    }
    mapping(uint256 => bool) private _royaltiesPaid;
    mapping(uint256 => RoyaltyDistribution[]) private _royaltyDistributions;

    // Events
    event RoyaltySet(address indexed artist, uint256 royaltyFee);
    event RoyaltyPaid(address indexed artist, address indexed buyer, uint256 value);
    event AccessControlGranted(address indexed account, string role);
    event AccessControlRevoked(address indexed account, string role);

    // Constructor
    constructor(address token) {
        _owner = msg.sender;
        _token = token;
        _royaltyFee = 0;
    }

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == _owner, "ArtistRoyalties: caller is not the owner");
        _;
    }

    modifier onlyMarketplaceOwner() {
        require(_isMarketplaceOwner[msg.sender], "ArtistRoyalties: caller is not a marketplace owner");
        _;
    }

    modifier onlyArtist() {
        require(_isArtist[msg.sender], "ArtistRoyalties: caller is not an artist");
        _;
    }

    modifier onlyBuyer() {
        require(_isBuyer[msg.sender], "ArtistRoyalties: caller is not a buyer");
        _;
    }

    // Functions
    function setRoyalty(uint256 royaltyFee) external onlyOwner {
        require(royaltyFee <= 100, "ArtistRoyalties: royaltyFee should be less than or equal to 100");
        _royaltyFee = royaltyFee;
        emit RoyaltySet(msg.sender, royaltyFee);
    }

    function royaltyInfo(address account, uint256 tokenId, uint256 value) external view override returns (address receiver, uint256 royaltyAmount) {
        require(IERC165(_token).supportsInterface(type(IERC2981).interfaceId), "ArtistRoyalties: ERC2981 not supported by token");
        require(IERC721(_token).ownerOf(tokenId) != address(0) || IERC1155(_token).balanceOf(account, tokenId) > 0, "ArtistRoyalties: invalid token");
        royaltyAmount = value.mul(_royaltyFee).div(100);
        receiver = IERC721(_token).ownerOf(tokenId);
        if (receiver == address(0)) {
    	    receiver = account;
	    }
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
        require(msg.sender == _token, "ArtistRoyalties: invalid token");
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external override returns(bytes4) {
        require(msg.sender == _token, "ArtistRoyalties: invalid token");
        return this.onERC1155Received.selector;
    }

    function payRoyalty(uint256 tokenId, uint256 value) external payable onlyBuyer {
        require(!_royaltiesPaid[tokenId], "ArtistRoyalties: royalties for this NFT have already been paid");
        (address receiver, uint256 royaltyAmount) = royaltyInfo(msg.sender, tokenId, value);
        _royaltiesPaid[tokenId] = true;
        _royaltyDistributions[tokenId].push(RoyaltyDistribution(receiver, royaltyAmount));
        payable(receiver).transfer(royaltyAmount);
        emit RoyaltyPaid(receiver, msg.sender, royaltyAmount);
    }

    function grantAccessControl(address account, string memory role) external onlyOwner {
        require(bytes(role).length > 0, "ArtistRoyalties: invalid role");

        if (keccak256(bytes(role)) == keccak256("marketplace owner")) {
            _isMarketplaceOwner[account] = true;
        } else if (keccak256(bytes(role)) == keccak256("artist")) {
            _isArtist[account] = true;
        } else if (keccak256(bytes(role)) == keccak256("buyer")) {
            _isBuyer[account] = true;
        } else {
            revert("ArtistRoyalties: invalid role");
        }

        emit AccessControlGranted(account, role);
    }

    function revokeAccessControl(address account, string memory role) external onlyOwner {
        require(bytes(role).length > 0, "ArtistRoyalties: invalid role");
        if (keccak256(bytes(role)) == keccak256("marketplace owner")) {
            _isMarketplaceOwner[account] = false;
        } else if (keccak256(bytes(role)) == keccak256("artist")) {
            _isArtist[account] = false;
        } else if (keccak256(bytes(role)) == keccak256("buyer")) {
            _isBuyer[account] = false;
        } else {
            revert("ArtistRoyalties: invalid role");
        }

        emit AccessControlRevoked(account, role);
    }

    // Additional functions with added features and securities

    // Role-based access control
    modifier onlyRole(string memory role) {
        require(bytes(role).length > 0, "ArtistRoyalties: invalid role");
        if (keccak256(bytes(role)) == keccak256("marketplace owner")) {
            require(_isMarketplaceOwner[msg.sender], "ArtistRoyalties: caller is not a marketplace owner");
        } else if (keccak256(bytes(role)) == keccak256("artist")) {
            require(_isArtist[msg.sender], "ArtistRoyalties: caller is not an artist");
        } else if (keccak256(bytes(role)) == keccak256("buyer")) {
            require(_isBuyer[msg.sender], "ArtistRoyalties: caller is not a buyer");
        } else {
            revert("ArtistRoyalties: invalid role");
        }
        _;
    }

    // Escrow functionality
    mapping(uint256 => bool) private _escrowedTokens;
    mapping(uint256 => uint256) private _escrowedRoyalties;

    function payRoyaltyWithEscrow(uint256 tokenId, uint256 value) external payable onlyBuyer {
        require(!_royaltiesPaid[tokenId], "ArtistRoyalties: royalties for this NFT have already been paid");
        (address receiver, uint256 royaltyAmount) = royaltyInfo(msg.sender, tokenId, value);
        _royaltiesPaid[tokenId] = true;
        _royaltyDistributions[tokenId].push(RoyaltyDistribution(receiver, royaltyAmount));
        _escrowedTokens[tokenId] = true;
        _escrowedRoyalties[tokenId] = royaltyAmount;
        emit RoyaltyEscrowed(receiver, msg.sender, tokenId, royaltyAmount);
    }

    function releaseEscrow(uint256 tokenId) external onlyRole("marketplace owner") {
        require(_escrowedTokens[tokenId], "ArtistRoyalties: token is not in escrow");
        require(_royaltiesPaid[tokenId], "ArtistRoyalties: royalties have not been paid yet");
        address receiver = _royaltyDistributions[tokenId][_royaltyDistributions[tokenId].length - 1].receiver;
        uint256 royaltyAmount = _escrowedRoyalties[tokenId];
        _escrowedTokens[tokenId] = false;
        _escrowedRoyalties[tokenId] = 0;
        payable(receiver).transfer(royaltyAmount);
        emit RoyaltyReleased(receiver, tokenId, royaltyAmount);
    }

    // Batch royalty payment
    function payRoyaltiesBatch(uint256[] memory tokenIds, uint256[] memory values) external payable onlyBuyer {
        require(tokenIds.length == values.length, "ArtistRoyalties: tokenIds and values length mismatch");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            payRoyalty(tokenIds[i], values[i]);
        }
    }

    // Batch escrow release
    function releaseEscrowBatch(uint256[] memory tokenIds) external onlyRole("marketplace owner") {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            releaseEscrow(tokenIds[i]);
        }
    }

    // Withdraw contract balance
    function withdrawBalance() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
        emit BalanceWithdrawn(msg.sender, balance);
    }
}

// Interface for royalty recipient
interface IRoyaltyRecipient {
    function royaltyInfo(address buyer, uint256 tokenId, uint256 value) external returns(address receiver, uint256 royaltyAmount);
}

// Struct to store royalty distribution information
struct RoyaltyDistribution {
    address receiver;
    uint256 amount;
}

// Events
event RoyaltyPaid(address indexed receiver, address indexed buyer, uint256 amount);
event RoyaltyEscrowed(address indexed receiver, address indexed buyer, uint256 tokenId, uint256 amount);
event RoyaltyReleased(address indexed receiver, uint256 tokenId, uint256 amount);
event AccessControlGranted(address indexed account, string role);
event AccessControlRevoked(address indexed account, string role);
event BalanceWithdrawn(address indexed account, uint256 amount);

// Main contract that inherits from AccessControl and ERC-1155
contract ArtistRoyalties is AccessControl, ERC1155 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdTracker;

    // Royalty information for each token
    mapping(uint256 => uint256) private _royaltyPercentages;
    mapping(uint256 => mapping(address => bool)) private _royaltiesPaid;
    mapping(uint256 => mapping(address => uint256)) private _escrowedRoyalties;
    mapping(uint256 => mapping(uint256 => RoyaltyDistribution)) private _royaltyDistributions;
    mapping(uint256 => bool) private _escrowedTokens;
    
    // Constructor to set name, symbol and URI of the token
    constructor(string memory name, string memory symbol, string memory uri) ERC1155(uri) {
        _name = name;
        _symbol = symbol;
    }

    // Function to create a new token
    function createToken(uint256 royaltyPercentage) external onlyOwner returns (uint256) {
        _tokenIdTracker.increment();
        uint256 newTokenId = _tokenIdTracker.current();
        _royaltyPercentages[newTokenId] = royaltyPercentage;
        _escrowedTokens[newTokenId] = false;
        return newTokenId;
    }

    // Function to set royalty information for an existing token
    function setRoyaltyPercentage(uint256 tokenId, uint256 royaltyPercentage) external onlyOwner {
        require(_exists(tokenId), "ArtistRoyalties: token does not exist");
        _royaltyPercentages[tokenId] = royaltyPercentage;
    }

    // Function to get royalty information for a token
    function royaltyInfo(uint256 tokenId, uint256 value) external view returns (address, uint256) {
        require(_exists(tokenId), "ArtistRoyalties: token does not exist");
        uint256 royaltyPercentage = _royaltyPercentages[tokenId];
        uint256 royaltyAmount = (value * royaltyPercentage) / 10000;
        address receiver = _msgSender();
        return (receiver, royaltyAmount);
    }

    // Function to pay royalty for a token
    function payRoyalty(uint256 tokenId, uint256 value) public payable {
        require(_exists(tokenId), "ArtistRoyalties: token does not exist");
        require(msg.value == ((value * _royaltyPercentages[tokenId]) / 10000), "ArtistRoyalties: insufficient funds for royalty payment");
        require(!_royaltiesPaid[tokenId][_msgSender()], "ArtistRoyalties: royalty has already been paid for this token by this buyer");
        _royaltiesPaid[tokenId][_msgSender()] = true;
        address receiver;
        uint256 royaltyAmount;
        (receiver, royaltyAmount) = IRoyaltyRecipient(address(this)).royaltyInfo(_msgSender(), tokenId, value);
        _escrowedRoyalties[tokenId] += royaltyAmount;
        if (!_escrowedTokens[tokenId]) {
            _escrowedTokens[tokenId] = true;
        }
        RoyaltyDistribution memory distribution = RoyaltyDistribution(receiver, royaltyAmount);
        _royaltyDistributions[tokenId][_royaltyDistributions[tokenId].length] = distribution;
        emit RoyaltyEscrowed(receiver, msg.sender, tokenId, royaltyAmount);
    }

    //Function to release escrowed royalties for a token
    function releaseRoyalties(uint256 tokenId) public onlyOwner {
        require(_escrowedTokens[tokenId], "ArtistRoyalties: no royalties to release for this token");
        uint256 totalRoyaltyAmount = _escrowedRoyalties[tokenId];
        delete _escrowedRoyalties[tokenId];
        delete _escrowedTokens[tokenId];

        for (uint256 i = 0; i < _royaltyDistributions[tokenId].length; i++) {
            RoyaltyDistribution memory distribution = _royaltyDistributions[tokenId][i];
            distribution.receiver.transfer((distribution.amount * address(this).balance) / totalRoyaltyAmount);
            emit RoyaltyPaid(distribution.receiver, address(0), distribution.amount);
        }

        delete _royaltyDistributions[tokenId];
        emit RoyaltyReleased(owner(), tokenId, totalRoyaltyAmount);
    }

    // Function to withdraw contract balance
    function withdrawBalance() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "ArtistRoyalties: no balance to withdraw");
        (bool success, ) = owner().call{value: balance}("");
        require(success, "ArtistRoyalties: failed to withdraw balance");
        emit BalanceWithdrawn(owner(), balance);
    }
}